# 3 a.m. failure analysis for the chosen exactly-once design

## Design being analyzed

Chosen design: option A, idempotency key + dedupe table.

The exact mechanism in this design is:

1. The API approves an invoice with a conditional update that only succeeds if the invoice is still `PendingApproval` and exactly one row is changed.
2. A deterministic idempotency key is derived from `invoiceId + ":" + approvalId`.
3. A row is inserted into `PaymentDedupe` with a UNIQUE key on that idempotency key, status `Pending`, and a timestamp.
4. If the insert violates the unique constraint, the payment was already started, so the system returns the stored result and does not call PayEx again.
5. If the insert succeeds, the service calls PayEx once with that same idempotency key using a pooled `HttpClient` and a 30s timeout.
6. On success, the PayEx reference is stored on the dedupe row and the status becomes `Sent`.
7. On timeout or unknown error, the row is marked `Unknown`. Retries reuse the same key, so PayEx is asked to treat repeats as the same payment.
8. Rows stuck in `Unknown` or `Pending` are retried by a retry job and reported on a dashboard.
9. Every approval and every state change is written to an audit table retained for seven years.
10. Azure Service Bus is not used in this design.

The design assumes:
- PayEx honours the idempotency key.
- If a timeout occurs, repeated calls with the same key return the original result, or otherwise PayEx can be queried by our own reference.
- The `UNIQUE` constraint in Azure SQL is the single source of truth for “already started”.
- The `HttpClient` call is in the approval flow or immediately after it, not via a queue.

This is a failure mode analysis for the last day of the month at 3:00 a.m., with the stated workload: ~40,000 invoices/month, ~60% in the last three working days, peak ~80 approvals/minute.

---

## 1) Timeline of the failure, step by step

### 03:00:00 - approval burst starts

The system is under peak load. At 80 approvals/minute:

- approvals per second = 80 / 60 = 1.33 approvals/s
- with a 30s PayEx timeout, the worst-case number of requests in flight at once is roughly 1.33 × 30 = 40 requests

So at any instant, roughly 40 approval requests are blocked waiting on PayEx, and the web server is occupying 40 request threads if the call is synchronous in the request path.

### 03:00:00 to 03:00:30 - first symptoms appear

The first symptom is latency, not a duplicate payment yet.

1. An approver clicks Approve.
2. The API writes the approval state change and the invoice state change in SQL.
3. The API inserts the row into `PaymentDedupe` with status `Pending`.
4. Then the API calls PayEx with the idempotency key.
5. PayEx is slow; the pooled `HttpClient` waits 30s for a response.
6. The request thread is still held while waiting.

The approver sees the screen “processing” or “waiting” and cannot tell whether the system is working, has sent the payment, or is waiting for PayEx.

### 03:00:30 - first explicit timeout window

The 30s client timeout expires.

At this point the design says the row is marked `Unknown` in the dedupe table and the code stops treating the call as a success. The retry job will later reuse the same idempotency key.

The first obvious symptom is now a set of rows in `PaymentDedupe` with status `Unknown` and `Pending`, plus a spike in approval wait times. If the app is instrumented for this, the dashboard shows rows waiting longer than 30s.

### 03:01:00 onward - duplicate-risk starts

The critical split is whether PayEx honours the idempotency key.

- If PayEx honours the key: the retry job reuses the same key, and the provider returns the original result instead of creating a second payment. This prevents duplicate payment, but it does not eliminate stuck or unpaid rows.
- If PayEx does not honour the key: every retry with the same key is treated as a fresh payment by PayEx, and a single invoice can be charged multiple times. This is the design’s catastrophic failure mode.

The design does not contain a separate reconciliation step before retrying, and the service is still in the same sync approval path. There is no Service Bus-based durable worker that would decouple the call from the web request. The retry job is therefore the only mechanism for resuming work after a timeout.

### 03:02 onward - audit trail and SQL symptoms

The audit table records the approval and the status change; it will show an approval recorded as successful in the invoice domain, then `Pending`, then `Unknown`, then possibly `Sent`, then later perhaps “replayed”. That audit trail is useful forensics, but it does not tell the on-call engineer whether PayEx actually paid the money.

At the same time, the SQL `PaymentDedupe` table starts to show:
- rows in `Pending` that were inserted but never reached PayEx due to a crash or deploy,
- rows in `Unknown` caused by timeouts or provider errors,
- unique key violations if a second approval thread attempts the same key while the first row is still present.

### 03:05 to 03:15 - if the retry job is not yet running, the number of stuck invoices keeps growing

If the design is behaving strictly as written, there is no queue drain unless the retry job runs. If the job is delayed or disabled, then the count of pending/unknown rows grows linearly with the approval rate.

At 80 approvals/minute, a sustained failure adds:

- 80 approvals/minute × 1 minute = 80 stuck or unknown rows per minute
- 80 approvals/minute × 10 minutes = 800 stuck or unknown rows after 10 minutes
- 80 approvals/minute × 60 minutes = 4,800 rows after 1 hour

This is not a “zero queue” design; it is a durable SQL backlog design with a retry worker.

### 03:15 onward - the failure becomes visible as a reconciliation problem

The first real operational signal is not “a payment failed” but rather “we have rows in SQL that are not `Sent` and do not have a PayEx reference”. The system cannot prove whether those rows were paid.

The next signal is the retry job starting to retry rows. However, because the same idempotency key is reused, a retry can also become a duplicate-payment event if PayEx ignores the key.

---

## 2) Which alerts fire, and which fail to fire

### Alerts that would fire under the design as specified

1. `PaymentDedupe` slow/unknown alert
   - Trigger: rows remain in `Pending` or `Unknown` longer than a threshold.
   - This is the principal alert in the design, because the retry dashboard and dedupe table are explicitly mentioned.

2. `Retry job` failure alert
   - Trigger: repeated retry failures or poison rows that never resolve.
   - This is also explicitly mentioned.

3. `PayEx timeout / error rate` alert
   - Trigger: the `HttpClient` sees timeouts or provider exceptions.
   - This is a normal provider-level alert.

4. `SQL throttling/failover` alert
   - Trigger: query timeouts, SQL throttling, deadlocks, failover events.
   - This can fire at the database layer and is explicitly relevant here because the dedupe insert is the critical lock.

### Alerts that would fail to fire, given only what the design above specifies

1. No alert for “approver sees an approval hanging for >30s”
   - The design does not say the UI emits an app-level latency warning or a thread exhaustion alert.
   - This is not necessarily a provider or DB alert; it is a user experience signal.

2. No alert for “a lack of PayEx reference on a successful approval”
   - The system may write the invoice as `Approved`, but if the dedupe row is `Unknown` or `Pending`, there is no separate alert saying “customer may be unpaid”.

3. No alert for “PayEx may have paid but our system timed out”
   - The design explicitly says a timeout does NOT reliably mean the submission failed.
   - Yet there is no built-in reconciliation alert that says “we timed out and must verify provider state before retrying”.

4. No alert for “web server request thread pool saturated”
   - The design has a synchronous PayEx call inside the request path, but no thread-pool saturation alert is specified.

5. No alert for “same invoice has multiple PayEx references”
   - A system that is relying on a key can still create multiple provider payments if the provider ignores the key. The dedupe table only helps if the key is honoured. The design does not state a reconciliation alert for “same invoice has multiple provider references”.

6. No alert for “duplicate PaymentDedupe row inserted due to retry collision”
   - The design has a `UNIQUE` constraint, but any unique-constraint violation is just a control-flow branch; it is not described as a monitored event.

So the main failure signal is not the duplicate payment itself; it is the backlog of `Pending` and `Unknown` rows. Duplicate payment is a hidden financial breach unless a separate settlement reconciliation is running outside this design.

---

## 3) What the on-call engineer sees and what they cannot see

### What the on-call engineer sees

At 3 a.m., the on-call engineer sees:

- elevated approval request latency, potentially 30s+ for many requests,
- a dashboard or query showing `PaymentDedupe` rows in `Unknown` or `Pending`,
- PayEx timeout/error logs,
- SQL latency and/or connection pressure,
- audit rows showing invoice state transitions and `Unknown` states,
- retry job logs showing rows constantly retried or stuck,
- possibly a thread pool saturation alarm if the infrastructure is instrumented outside the app design.

They also see the exact SQL table state:
- `Pending` rows: payment was started or maybe not started; a row exists but no PayEx reference is recorded yet,
- `Unknown` rows: timeout or provider error, not verified,
- `Sent` rows: a PayEx reference exists and the idempotency key was accepted as a successful payment.

### What the on-call engineer cannot see

This design intentionally leaves several facts invisible:

- whether PayEx really processed the payment after a timeout,
- whether the same idempotency key caused a duplicate payment on the provider side,
- whether a row in `Pending` was inserted but the PayEx call never reached the provider,
- whether the retry job is creating a second payment because the provider ignores the key,
- whether the timeout responded after the process ended and the row is simply stale,
- whether the same invoice has multiple PayEx references outside the dedupe table,
- whether a later `Unknown` row is a real second payment on the provider side or just a false retry.

The audit table helps with chronology but does not reveal whether the provider side was charged. That fact is outside the boundary of this design unless PayEx exposes lookup or reconciliation.

This is the key operational blind spot: the system can prove “we inserted a row” and “we attempted a call” but cannot prove “PayEx did or did not settle the funds” after a timeout unless the provider explicitly supports an authoritative lookup or idempotency guarantee.

---

## 4) Case-by-case failure analysis

### Case A: PayEx slowness or a 30 second timeout on every call

This is the simplest and most common failure path.

#### Failure sequence

1. Each approval stores the approval and inserts `PaymentDedupe`.
2. The API calls PayEx.
3. PayEx takes >30s for each request.
4. The calling request hangs until timeout; the thread is still occupied.
5. The row is marked `Unknown` on timeout.
6. The retry job reuses the same key and immediately retries the same payment.
7. If PayEx honours the key, the retry returns the same result and there is no duplicate payment. If PayEx ignores the key, each retry becomes a new payment.

#### Effect on the user

The approver screen stays in a pending/loading state while the request blocks. This is not a transient UI blip; it is a request thread occupied until the provider returns or times out.

The screen may appear stuck until the request completes or times out. The design does not mention a cancel path or a “check status” flow. Approvers cannot tell whether the system is actively retrying or simply waiting.

#### Thread exhaustion

Yes, approvers could exhaust the web server’s request threads.

At 80 approvals/minute and a 30-second timeout, the minimum queued/waiting count is roughly:

- 80 / 60 × 30 = 40 in-flight requests at a time

If the ASP.NET request thread pool is smaller than that sustained concurrent count, the server will begin queueing requests and then fail under load. The design has no separate worker queue or queue-bypass strategy. It is just a synchronous call into a slow external provider.

This design does not contain a means to release the web request thread early just because the provider is slow.

### Case B: PayEx honouring the idempotency key versus not honouring it

#### B1. PayEx honours the idempotency key

In this case:

- a retry with the same key returns the original result,
- the provider does not create a second charge,
- all rows can be resolved by the same dedupe key,
- the main failure is stuck rows, not duplicate payments.

However, the design still fails operationally because rows can remain in `Pending` or `Unknown` for long periods. The retry queue is still required. The app is still blocked on a synchronous provider call. The system can still have many unpaid invoices if the provider is temporarily unavailable and the retry job is slow.

#### B2. PayEx does not honour the idempotency key

This is the design-breaking condition.

A timeout does not mean “no payment was made”; the provider may have actually processed the payment but simply responded late. The next retry with the same key is then a second charge, not a harmless replay. The dedupe table is only a local guard. If the provider ignores the key, the local unique constraint is no protection against actual duplicate charging.

At 80 approvals/minute, if 40 simultaneous timeouts occur and each one is retried, the number of exposed duplicate-payment attempts is:

- 40 concurrent requests × 1 retry cycle = 40 candidate duplicate payment attempts immediately
- 80 approvals/minute × 60 minutes = 4,800 approvals per hour that could be subject to duplicate-payment risk if the timeout/retry pattern continues for an hour

This is the financial risk the design cannot eliminate without a provider contract that guarantees idempotent key behaviour.

### Case C: crash or deploy between the dedupe insert and the PayEx call (row stuck in Pending)

This is an operationally guaranteed failure mode in the design as written.

The ordering is:

1. Invoice conditionally updates to `Approved`.
2. `PaymentDedupe` row is inserted with status `Pending`.
3. The process crashes, the pod dies, the deploy restarts the app, or the host process is terminated before the call to PayEx.
4. The SQL row remains in `Pending` forever unless the retry job sees it.

The critical point is that the unique constraint adds a durable source of truth that is local to the database, but it does not require that the call to PayEx happened. The row can be inserted and then lost. This means:

- the invoice may be marked `Approved` in the invoice table,
- the dedupe row may linger in `Pending`,
- there may be no PayEx reference,
- the payment may be unpaid even though the business workflow shows approval.

This is a classic “approval succeeded but payment never started” case.

At 80 approvals/minute, a crash during the insert-to-call window can leave a backlog equal to the number of approvals processed in the crash window. Example:

- 10-minute app outage during a peak period
- 80 × 10 = 800 invoices can be approved but remain unpaid

The exact count is unknown without logs, but the upper bound is linear with the outage duration.

### Case D: SQL throttling or failover

#### Failure sequence

1. The app attempts the conditional update on the invoice.
2. The app attempts the insert into `PaymentDedupe`.
3. SQL is throttled, under failover, or the primary is unavailable.
4. The transaction cannot complete.
5. The approval flow fails before the PayEx call is made.
6. The UI shows an error or a timeout to the approver.

This creates a different failure mode than a PayEx timeout:
- approval may not be persisted,
- the invoice may remain in `PendingApproval`,
- no dedupe row exists, so there is no idempotency key to reuse,
- the user may retry and the system may reattempt a new payment later.

This design does not provide a durable outbox or a fully separate transaction boundary that can preserve a payment intent across SQL failover. The `UNIQUE` guarantee is only meaningful while SQL is healthy.

During failover, if the app continues to write but the database is inconsistent or the primary flips, the audit trail may be incomplete because every state change writes to the audit table. This creates a risk of “unknown state” even before the provider is involved.

### Case E: retry job running at the same time as a fresh approval

This is a concurrency hazard in the retry logic itself.

#### Sequence

1. A row is in `Pending` or `Unknown` and is selected by the retry job.
2. A fresh approval for the same invoice is also in flight.
3. The original row’s dedupe key is the same as the fresh key for the same invoice/approval pair, or a retry job tries to insert/upsert a row for a key that is already taken.
4. The `UNIQUE` constraint on `PaymentDedupe` is hit. The retry job sees the duplicate and returns the stored result rather than calling PayEx again.
5. Or the fresh approval race causes a second, logically distinct approval to reuse the same invoice but a different `approvalId`, which gives a different key. This is valid if it is a separate approval action; but it means the retry job can launch one payment while a fresh approval is also attempting to call PayEx.

This is a worst-case of “same invoice, different approval event” or “same approval, same key retried against a fresh row”. The design says the unique constraint is the single source of truth for “already started”, but it does not say the retry job and the normal approval flow use a single lock or queue. That means they can race.

The concrete risk is:
- retry job calls PayEx for a row still in `Pending` or `Unknown`,
- while the fresh approval path also attempts the same or a different payment,
- both calls may share the same invoice but not the same key,
- if the provider ignores the key, the retry worker can produce a duplicate payment while the normal flow is still in flight.

This is exactly why the design is unsafe if the provider does not honour the key.

### Case F: poison row that keeps failing

This is the row that never leaves `Unknown` or `Pending` because it is repeatedly retried and always fails.

A poison row can arise when:
- the provider keeps timing out for that key,
- the row is stuck in `Pending` because the app crashed before the call,
- the dedupe row’s status never transitions to `Sent`,
- a retry job continually replays the same key against a provider that ignores it and charges again.

The design says the retry job and dashboard are used to report these rows, but it does not specify a dead-letter or quarantine mechanism.

#### Lifecycle of a poison row

1. First timeout triggers `Unknown`.
2. Retry job runs again with same key.
3. PayEx returns timeout or fails again.
4. Row remains `Unknown`.
5. Retry continues indefinitely unless someone intervenes.
6. If the provider ignores the key, every replay can create a new payment attempt.

This is where “retry at same key forever” becomes a financial risk. A poison row is not just an engineering backlog; it is an unresolved money-handling state.

At 80 approvals/minute, a poison row can block the retry worker from draining backlog if the worker loops on the same failing key. It can also lead to a long tail of unresolved invoices that are approved in business logic but not settled.

---

## 5) How many invoices could be duplicated, stuck or left unpaid

The numbers below are direct arithmetic from the stated workload.

### Throughput and concurrency

- 80 approvals/minute
- 80 / 60 = 1.33 approvals/second
- 1.33 × 30 seconds = ~40 requests in flight at once

This means the web layer is expected to hold about 40 request threads for PayEx timeouts if all calls slow at the same time.

### Potential duplicates if PayEx ignores the idempotency key

If PayEx ignores the key and a timeout/retry loop is active:

- every retry can become a new charge
- the lower bound of duplicate-payment exposure in a single 30-second timeout burst is roughly 40 possible duplicate-payment attempts at one moment
- over one hour at steady 80/min, the exposure is 80 × 60 = 4,800 approval attempts that could be duplicated if the retry loop repeats for the full hour

This is the strongest numeric statement the design supports. The exact number is UNKNOWN without provider-side logs, but the upper bound is linear and large.

### Stuck rows

If rows stay in `Pending` or `Unknown`, the number stuck at any time is:

- approvals/minute × minutes of failure = stuck rows

Examples:
- 5 minutes of provider slowness: 80 × 5 = 400 rows stuck
- 15 minutes of provider slowness: 80 × 15 = 1,200 rows stuck
- 60 minutes of provider slowness: 80 × 60 = 4,800 rows stuck

This is exactly the backlog effect the design does not avoid by itself.

### Left unpaid

If the dedupe row remains in `Pending` or `Unknown` and no one resolves it, then the invoice is approved but potentially not paid.

- left unpaid = approved-but-not-paid rows waiting for a successful PayEx finalization
- at 80/minute, any sustained outage of N minutes leaves roughly 80 × N unpaid records before the retry job resolves them

Example:
- 10-minute outage => 800 invoices may be approved but left unpaid
- 30-minute outage => 2,400 invoices may be approved but left unpaid

This is not a theoretical concern; it follows directly from the synchronous approval path married to a retry-only recovery model.

---

## 6) How it is detected

The system detects the failure through the SQL and retry side of the design, not through the approval flow itself.

### Detection path

1. The retry job or dashboard starts showing rows in `Pending` or `Unknown`.
2. SQL queries reveal a rising count of dedupe rows without `Sent` status.
3. PayEx timeout logs increase.
4. The audit table shows many approvals that reached the invoice domain but never reached a `Sent` status.
5. Finance or reconciliation notices that provider settlements do not match invoice approvals.

### Failure modes that are difficult to detect

- A timeout that actually paid the invoice is invisible unless PayEx gives us lookup or a safe idempotent key contract.
- A duplicate payment after a retry is invisible unless a reconciliation process compares provider settlements to invoice approvals.
- A row stuck in `Pending` may look harmless until a customer complains or finance notices a missing payment.

The design depends on a dashboard and a retry job, but it does not specify an automated reconciliation check between PayEx and the invoice ledger. If such a check is absent, duplicate payment detection is slow and error-prone.

---

## 7) Exact recovery steps, including who may do what

The recovery is not generic; it is tightly constrained by this design.

### Step 1: Stop new damage

Who may do what:
- the 24x7 on-call engineer may stop or pause the retry job,
- the site owner or platform admin may scale down the app if needed,
- an approver may continue to approve only if the app is still serving requests, but they are not authorized to change payment state directly.

Why:
- the retry job may keep reusing the same idempotency key and create fresh PayEx charges if the provider ignores the key.
- stopping the retry job reduces the blast radius while investigation proceeds.

### Step 2: Identify the exact row set

Who may do what:
- the on-call engineer with DB access runs the SQL query against `PaymentDedupe` to list all rows in `Pending` and `Unknown`, and joins to invoice or approval tables to find the affected invoice IDs.
- an approver must not edit the table directly.
- a developer may read logs, but only an authorized engineer should query production SQL.

Purpose:
- determine which invoices are unpaid, which may be paid but unconfirmed, and which are already `Sent`.

### Step 3: Classify status by evidence

For each row, determine:

- `Sent`: PayEx reference exists; payment is likely complete.
- `Unknown`: timeout or provider error; requires provider-level lookup or reconciliation.
- `Pending`: likely inserted without moving to PayEx; may require replay or redrive.

This classification is not possible by the app alone at scale; it requires integrating SQL state with provider evidence.

### Step 4: Decide whether PayEx honours the key

This is the key branching point.

- If PayEx honours the key: the on-call engineer reuses the same key; no new charge should be created by retrying the same key.
- If PayEx does not honour the key: the on-call engineer must not blindly retry. They must ask PayEx support, or use a lookup by our own reference or invoice/approval metadata, to determine whether the payment was already made.

This branch is not optional. The design itself makes the answer decisive.

### Step 5: For `Pending` rows

Who may do what:
- the on-call engineer, not an approver, may manually mark the row as `Unknown` or trigger a replay if the provider was never reached,
- the app owner or DB admin may also assist if a controlled SQL update is required,
- no one outside operations should issue the payment call directly.

Purpose:
- determine whether the PayEx call actually happened.
- if it did not happen, re-run the call carefully using the original idempotency key.
- if it did happen but the response was lost, resolve the payment via PayEx lookup or support.

### Step 6: For `Unknown` rows

Unknown is the danger zone.

Who may do what:
- only the on-call engineer with access to either PayEx support or PayEx lookup tooling may determine whether the payment exists,
- database access is required to update the row only after the provider-side truth is known,
- developers can assist with analysis but should not directly change production rows or call PayEx in production.

Resolution options:
- if PayEx shows the payment was processed: set the dedupe row to `Sent` and store the reference, and mark the invoice as paid;
- if PayEx shows the payment was not processed: retry with the same key or follow the provider’s recovery path; if key is not honoured, do not retry blindly,
- if the payment cannot be resolved: escalate to PayEx support and keep the row quarantined as `Unknown`.

### Step 7: For a poison row

A poison row requires intervention.

Who may do what:
- the on-call engineer may quarantine it, stop it from being retried, and open a support incident,
- the app owner may decide whether to disable the retry job for a window,
- approvers cannot resolve it because they do not have the required provider or database access.

Exact action:
- stop retry loop for that specific key,
- query PayEx for that key or reference,
- if multiple duplicate payments exist, open a financial correction workflow,
- update the audit table and keep the toxic state visible for seven-year audit retention.

### Step 8: Re-enable the system

Once the backlog is resolved:
- re-enable the retry job,
- confirm no stale rows remain in `Pending` or `Unknown`,
- confirm no invoice is both approved and unpaid,
- confirm the dashboard is empty or within normal thresholds.

This should be done by the on-call engineer plus the app owner or service owner, not by an approver.

---

## 8) What happens to the approver’s screen while PayEx is slow

The approver experience is straightforward but bad:

- the screen stays in a “processing” or “waiting” state,
- there is no immediate confirmation that the approval was accepted,
- there is no separate UI to say “payment may still be pending” or “we are waiting on a downstream provider”,
- if the user clicks again, the app may dedupe it at the SQL layer, or the retry may hit the same idempotency key, depending on timing.

The design does not specify a UI cancel, retry, or status-checking path. That means the approver is effectively stuck until the request completes or times out. If the app is hit by 40 concurrent slow calls, the user can also experience queueing behind an unhealthy request thread pool.

---

## 9) Bottom line

This design is only safe if PayEx truly honours the idempotency key and allows a reliable lookup after timeout. If that is not true, the design fails in exactly the way that matters: a slow or timed-out payment call can become a duplicated charge or a permanently unpaid invoice, and the retry job turns a temporary timeout into a financial reconciliation problem.

The design gives good local atomicity in SQL for “already started”, but it does not give economic safety against a provider that ignores or cannot look up the idempotency key. The 30-second timeout therefore does not mean “retry safe”; it means “retry is operationally risky unless the provider contract proves otherwise”.

At 80 approvals/minute, the design can easily produce:

- ~40 in-flight requests during a 30-second timeout burst,
- 400 + stuck rows in 5 minutes,
- 4,800 + affected rows in 1 hour of sustained timeout behavior,
- duplicate-payment exposure if the key is not honoured,
- unpaid invoices if rows remain in `Pending` or `Unknown` and the retry worker is not resolving them.

The design’s claim of “exactly once” is only as strong as PayEx’s idempotency guarantee and the completeness of the provider-side lookup path. Without those, this design is not “exactly once” in production; it is a best-effort SQL dedupe with a fragile time-based retry loop.
