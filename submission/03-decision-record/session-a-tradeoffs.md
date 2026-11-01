# Session A: Payment submission trade-offs

## Decision context

We need to ensure that once an invoice is approved, the payment attempt reaches PayEx exactly once in effect, even though the API has a 30-second timeout and a timeout does not reliably mean the submission failed.

This service is an ASP.NET Core 8 app on Azure App Service, with Azure SQL in the target architecture but not yet implemented, and Azure Service Bus provisioned but not yet used. Peak rate is about 80 approvals/minute, with a material concentration in the last three working days of the month. SOC 2 Type II is in six months, and approval actions must be auditable for seven years.

## Working assumptions about PayEx

I am assuming the following, because without them the design space changes materially:

- PayEx accepts a per-merchant idempotency key for a payment request.
- Reusing the same idempotency key for the same logical invoice/payment is safe and returns the same result as the original call, even after a timeout or retry.
- PayEx provides either:
  - a lookup by idempotency key, or
  - a lookup by payment reference, after the initial call succeeds.
- A timeout is ambiguous; a successful payment may have been accepted before the client timed out.
- A payment reference from PayEx is durable and can be used to reconcile outcomes later.

If this is false, option 1 is not viable as designed. In that case, we would fall back to option 2 plus a reconciliation process, and we would explicitly treat exact-once as “no duplicate in our state machine plus a later reconciliation story,” not as a strict API guarantee.

## Option 1: Idempotency key with a dedupe table

### Mechanism

Create a durable payment-request record in SQL before calling PayEx:

- invoice_id
- payment_request_id
- idempotency_key (UUID or deterministic hash based on invoice + approval event)
- status: pending, submitted, succeeded, failed, unknown
- attempt_count
- payex_reference
- created_at, last_updated_at
- correlation data for audit

Then:

1. Start a SQL transaction.
2. Insert or lock a row in a `PaymentSubmission` table keyed by `invoice_id` and/or `approval_id`.
3. Ensure exactly one submission record can move from `pending` to `submitted` for the same invoice.
4. Call PayEx with the same idempotency key.
5. On success, store `payex_reference` and mark success.
6. On timeout or network failure, do not blindly retry on a new key; instead, query PayEx by the same idempotency key or by reference if known.
7. If the call is still ambiguous, keep the row in `unknown` and reconcile via a retry-safe lookup job.

This is the cleanest “exactly once in effect” design when the provider supports idempotency keys.

### How it handles the 30s timeout

This option handles the timeout best because the key is stable across retries. The first retry after a timeout uses the same idempotency key, and PayEx should return the same final result instead of creating a second payment.

If we do not know whether the original call succeeded, the flow is:

- do not create a second logical submission, and
- ask PayEx: “what happened for this idempotency key?”
- if the provider cannot answer that, then we need a human- or service-driven reconciliation path.

This is the key difference between “safe retry” and “blind retry.”

### Duplicate-payment risk

Low, if PayEx honors idempotency semantics. With a durable dedupe table and a fixed key, duplicate clicks or retries cannot create a second actual payment.

Risk remains if:

- PayEx ignores the key,
- key is regenerated per request, or
- the provider cannot surface prior results by key.

### Missed-payment risk

Low-to-medium if we have a lookup path. We can safely retry with the same key and reconcile to `unknown` if the response is ambiguous.

The actual risk sits in the provider contract rather than our code. If PayEx cannot be queried after a timeout, we may “miss” a successful payment because the original request was lost to the network yet succeeded server-side.

### Double-click or retry by approver

Good fit. The dedupe row prevents duplicate submission rows for the same invoice approval. The UI can also disable the approve button while the submission is pending.

The real protection is the invariant: one logical payment submission per invoice approval event; retrying later is a read of the existing state, not a new submission.

### Worker crash mid-call

This option is resilient because the payment record and dedupe state are already in SQL before the external call. If the app crashes after the SQL commit but before the response is processed, the state is still durable and the retry worker can continue from `pending`/`unknown`.

### SQL failover

Reasonably strong if the dedupe table is in a durable SQL environment with failover and transaction consistency. Use a single logical row and a transaction boundary that commits before the external call, so the same payment intent survives failover.

The caution is this: we must not let the app generate a second idempotency key after failover when the original request may already have been accepted. This is why a stable key should be derived deterministically from the invoice approval event, not from ephemeral app state.

### Audit / SOC 2 fit

Strongest fit. We can keep a tamper-resistant audit record with:

- invoice id, approver id, timestamp
- approval decision and payment key
- provider request and response payloads
- matching reference and reconciliation state
- any retry or timeout events

This gives a clear, immutable trail for the seven-year retention requirement and is easy to defend in an audit.

### Operational burden

Low to medium. Mostly application code and a small database table, plus a periodic reconciliation job. There is some operational discipline around queueing and retry policy, but it is not a large unmanaged workflow.

### Build complexity for this team

Moderate, but manageable for six engineers, especially with two newer engineers. This is a familiar pattern in high-integrity payment flows, and it is the most straightforward to reason about.

## Option 2: Transactional outbox with a worker

### Mechanism

This is the classic “write the business fact first, then publish an event to a durable outbox, and let a background worker call PayEx.”

Flow:

1. Commit the approval and payment intent in SQL in a single transaction.
2. Append the payment event to an outbox table in the same transaction.
3. A worker reads the outbox and calls PayEx.
4. The worker stores the result or any subsequent reconciliation outcome.

This is very strong for event-driven systems and has very good operational safety when the outbox is durable and the worker is idempotent.

### How it handles the 30s timeout

The worker owns the call to PayEx, not the web controller. If the worker times out, the payment intent is still in SQL and can be retried by the same worker or a retry path.

This is safer than a direct synchronous call from the approval request because the caller does not hold the external dependency. However, the timeout problem is still there: the worker does not know whether PayEx accepted the payment if the call to PayEx timed out.

This is solved only if PayEx supports idempotency keys or a lookup by reference; otherwise the worker must treat the event as `unknown` and reconcile later.

### Duplicate-payment risk

Medium. If the outbox table is processed exactly once by one worker, the risk is low. But duplicate risk appears if:

- the worker retries the same outbox row without a dedupe key,
- multiple workers are allowed to process the same outbox row,
- PayEx does not support idempotency keys, or
- the worker cannot distinguish “accepted but timed out” from “not accepted.”

### Missed-payment risk

Medium. The outbox is durable, so we do not lose the intent. However, if the worker crashes after calling PayEx and before recording the result, we can get a gap unless we have a durable status record and a reconciliation job. This is not “fire and forget”; it requires a follow-up settlement or lookup routine.

### Double-click or retry by approver

Good if the approval workflow is written to a single state transition in SQL. Double-clicks create the same approval state; the outbox row is still only one logical event. The worker does the actual payment. This is good for user ergonomics.

### Worker crash mid-call

This is the main design point of the transactional outbox: the worker can crash after the external call starts but before the state is updated. This is why the worker must be idempotent and must use a payment idempotency key or a stable provider reference. Without that, crash recovery becomes ambiguous.

### SQL failover

Good. Since the payment intent and outbox record are both in SQL, the durable state survives failover. The worker can pick up the outbox rows after failover with no lost work.

This is often the most “database-first” and operationally reliable pattern for Azure SQL + App Service + Service Bus background processing.

### Audit / SOC 2 fit

Strong. The audit trail is nicely represented as a durable event stream: approved, outbox-created, worker-submitted, succeeded/failed/unknown, reconciliation. This is easy to reason about and explain in controls.

The audit quality is particularly good if every outbox event includes the exact payload sent to PayEx, provider response, processing status, and reconciliation result.

### Operational burden

Medium to high. This requires a worker service, health checks, dead-letter handling, idempotency logic, message sequencing, and a reconciliation process. With six engineers and a 24x7 rotation, this is manageable but not trivial.

### Build complexity for this team

Medium to high. The pattern is well-understood, but it adds moving parts: outbox processing, poison queues, retry policy, scaling and worker monitoring, and more operational attention than the simpler idempotent-table approach.

## Option 3: Optimistic submission with nightly reconciliation

### Mechanism

The app makes a best-effort payment submission when an invoice is approved, but it does not block the approval flow on definitive success. Every night or on a fixed schedule, a reconciliation job compares:

- invoices approved but not paid,
- payments that PayEx accepted,
- payment references that appear in our system,
- any provider side records that can be matched by invoice or date window.

Then it marks missing outcomes or initiates a manual investigation.

### How it handles the 30s timeout

This is where it is weakest. A timeout is simply “status unknown,” and the system may decide to resubmit or leave it unresolved depending on the rule. Without a provider idempotency contract, this makes the ambiguous timeout extremely difficult to resolve correctly.

The result is the classic “maybe paid, maybe not paid” state that is unacceptable for payment processing.

### Duplicate-payment risk

High unless PayEx offers very strict idempotency semantics and the reconciliation layer is carefully designed. In a best-effort process, retries or duplicate clicks become a real risk.

### Missed-payment risk

High. Nightly reconciliation is intentionally delayed, which means a successful payment can remain undetected for many hours or even a day. This is not acceptable for an approval flow that must be in sync with financial settlement and audit evidence.

### Double-click or retry by approver

Poor unless the UI and who is calling are tightly controlled. The user can press approve twice, and the system may create multiple submissions because the provider response is delayed and there is no durable dedupe barrier.

### Worker crash mid-call

Not a big problem in the sense that there is no worker, but it creates a bigger problem in the sense that the system has no strong durable record of “payment is in flight.” Without a queue or a transactional record, a crash can leave the system with an approved invoice but no trustworthy payment evidence.

### SQL failover

This option is simple but brittle. The optimistic call is not backed by a durable workflow boundary until a later reconciliation pass, so failover causes difficult state recovery. If the app restarts after a timeout, the payment may have succeeded with no durable remembrance in our own database.

### Audit / SOC 2 fit

Weak. The audit documentation is likely to be a nightly reconciliation report plus logs, not a transactional record of the original approval and payment intent. This is hard to defend under SOC 2 because the evidence trail is not strong enough when the payment state is ambiguous.

### Operational burden

Low upfront, but high cumulative risk: reconciliation jobs, exceptions, manual investigation, and possible financial follow-up become a recurring operational cost. This may look cheap at sprint speed, but it is expensive in production.

### Build complexity for this team

Low. The simplest to build initially, but it is the worst on correctness and auditability. For this team and this risk profile, low build complexity is not the right optimization target.

## Recommendation

Recommend option 1: idempotency key plus a durable dedupe table, with a small periodic reconciliation job as a safety net.

Why:

- It is the only option that directly addresses the 30-second ambiguous timeout with a repeatable, safe retry contract.
- It preserves a single logical payment intent per invoice approval and prevents duplicate processing from double-clicks, retry loops, and app restarts.
- It works naturally with Azure SQL, which is the expected durable system boundary.
- It produces the strongest audit record for SOC 2 and the seven-year retention requirement.
- It is the best fit for six engineers and a one-week on-call rotation, because the behavior is deterministic and easier to reason about than a worker-heavy event-driven design.

The core pattern should be:

1. Approve invoice in SQL.
2. Record a payment submission row with a stable idempotency key.
3. Only one row can be active for the same invoice approval.
4. Make the PayEx call with that key.
5. On timeout/unknown, re-query PayEx using the same key or reference.
6. If the key is unsupported, treat payment as `unknown` and escalate to a constrained reconciliation workflow.

### What changes if PayEx does not support idempotency keys or lookup by key/reference?

Then option 1 stops being safe in a strict interpretation of “exactly once in effect.” In that case, the recommended design changes to option 2, transactional outbox with a durable worker and explicit reconciliation. The outbox is still the safer operational pattern, but the system is only as good as PayEx’s external contract. Without provider support for safe retries, exact once is impossible to guarantee in the technical sense, only to approximate with durable state and reconciliation.

### Final decision

Use option 1 as the primary design, with an outbox-like worker only as a resilience layer if needed. Avoid option 3 except as a fallback monitor or manual reconciliation path. This provides the best balance of correctness, auditability, operational burden, and team capacity.
