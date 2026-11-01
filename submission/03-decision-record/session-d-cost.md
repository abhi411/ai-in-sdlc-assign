# Cost estimate for the chosen exactly-once PayEx design

This note estimates the build effort, monthly run cost, and operational cost for Option A: idempotency key + dedupe table.

All figures below are ESTIMATES. I am intentionally not quoting live Azure prices; those must be checked in the Azure pricing calculator for the target subscription, region, and SKU.

## Assumptions and scope

- The app is an ASP.NET Core 8 API running in Azure App Service.
- Azure SQL is newly provisioned for the payment workflow; the repo today has only in-memory state.
- The retry path runs in the existing platform, either the API itself or a small background worker; no Azure Service Bus is used in this design.
- Volume is roughly 40,000 invoices per month, with about 60% of approvals in the last three working days and a peak near 80 approvals/minute.
- PayEx has a 30-second timeout, and timeout does not reliably mean the payment failed.
- Approval actions must be auditable for seven years.
- Azure SQL provides the single source of truth for "already started" via the UNIQUE constraint on the dedupe key.
- The design is deliberately limited to this payment path; it does not include a broader event-driven architecture.
- The six engineers include two engineers new to the codebase, so there is a mentorship and review overhead.
- The design assumes PayEx honors the idempotency key; this is not confirmed by evidence and is the largest uncertainty in the estimate.
- The App Service and tenancy already exist unless stated otherwise.

## 1) Build effort: engineer-days by task

I used a standard engineering day as one engineer spending one working day on implementation, testing, and normal review. I then applied an uplift for the two newer engineers: roughly 20% to 30% extra time on implementation-heavy tasks, with more uplift on payment-risk work that needs pairing and careful review.

| Task | Low estimate (engineer-days) | High estimate (engineer-days) | Notes |
|---|---:|---:|---|
| Schema and migrations | 1.5 | 3.5 | New tables for approval state, payment dedupe, audit history, retention cleanup, and migration strategy |
| SQL repository and data access layer | 2.0 | 5.0 | Repository methods for conditional update, dedupe insert, lookup, and SQL error handling |
| Conditional-update approval logic | 2.0 | 4.0 | Avoid double approval under concurrent clicks or duplicate requests |
| Dedupe table logic and replay handling | 1.5 | 3.0 | Unique key insert, stored result handling, status transitions, retry classification |
| PayEx client with pooled HttpClient | 2.0 | 4.0 | Request construction, timeout handling, retry policy, logging, and safe serialization |
| Retry job and dashboard integration | 2.0 | 4.0 | Pending/Unknown row scan, retry scheduling, safe replays, and reconciliation visibility |
| Audit table and seven-year retention | 2.0 | 5.0 | Audit write path, retention policy, archival strategy, and compliance review |
| Alerts and dashboard | 1.5 | 3.0 | SQL backlog alerts, pending/unknown queues, latency and timeout monitoring |
| Tests incl. concurrency tests | 3.0 | 6.0 | Contract tests, repository tests, concurrency tests, retry path tests, and end-to-end approval flows |
| Runbook and operational documentation | 1.0 | 3.0 | On-call playbooks, rollback, pay-out investigation, and incident communication |

Base build total (before onboarding uplift): ESTIMATE 18.5 to 40.5 engineer-days.

### Adjustment for two of six engineers being new to the codebase

I applied an ESTIMATED 20% to 30% uplift to the work that depends on payment flow, domain rules, and SQL behavior, plus time for pairing and review. For this team, that is roughly ESTIMATE 4 to 9 extra engineer-days.

Final total build effort: ESTIMATE 22 to 50 engineer-days.

This is a realistic range for a first delivery in a codebase with no database, no PayEx client, and no background job. If the team has strong data-access patterns already, the lower end is more likely; if audit and retry semantics need more governance work, the upper end is more likely.

## 2) Run cost: required new Azure resources and monthly estimate

### Assumed region

Region assumed for the estimate: East US 2.

This is a neutral estimate only; the actual choice should be based on Azure region alignment with the app and data residency requirements.

### New Azure resources likely required

1. Azure SQL Database
   - Purpose: approval status, dedupe table, audit table, and retention data
   - Likely SKU: a small single database in Azure SQL using a vCore-based or serverless General Purpose tier rather than a large dedicated compute footprint
   - Estimated scale at this volume: not large enough to justify a very large SQL tier, but enough to need a production-grade, backed database with monitoring and backups
   - ESTIMATE: $100 to $300 per month

2. Azure Monitor / Log Analytics / alerts
   - Purpose: alerting for timeout/unknown rows, SQL backlog, deadlocks, retries, and approval latency
   - Typical cost is small for a small application but not zero because of log retention and alert actions
   - ESTIMATE: $10 to $60 per month

3. Background retry worker (small Azure Function or small App Service worker)
   - Purpose: retry of Pending/Unknown dedupe rows
   - If the job uses consumption or a tiny dedicated worker, the cost stays low because the throughput is modest
   - ESTIMATE: $0 to $60 per month if consumption; $25 to $100 per month if a small dedicated App Service plan is used

4. Storage and security dependencies
   - Purpose: small auditing and operational storage, plus secret/identity support if needed
   - Usually small compared to SQL and monitoring
   - ESTIMATE: $5 to $20 per month

### Estimated total monthly run cost

Total new Azure spend for this design, at the stated volume: ESTIMATE $120 to $420 per month.

### Important interpretation

At this volume, the run cost is likely dominated by Azure SQL and observability, not by compute. The approval volume is moderate, and the design does not create a high-throughput event pipeline. The main cost center is storage, auditing, and keeping the database healthy enough for strict concurrency and retention requirements.

This estimate assumes the API continues running on an existing App Service plan and that the retry job is small. If the team creates a new dedicated App Service plan or a larger SQL tier than needed, the total can rise materially.

### Explicitly excluded from the new cost

- Azure Service Bus: not used in this design.
- Large dedicated worker fleets: not needed at this workload.
- Separate data warehouse for audit retention: not needed unless the company requires a different retention or analytics model.

## 3) Operational cost

### On-call burden

With 24x7 on-call and one-week rotations among six engineers, the rotation cadence is roughly one engineer per week, or one week in a six-week cycle for each engineer.

Operationally, the burden is not full-time, but it is not trivial when a PayEx issue or SQL backlog hits:

- ESTIMATE: about 1/6 of an engineer's time is consumed by rotation coverage over a cycle
- During active incidents, the on-call engineer may spend several hours coordinating, analyzing, and communicating

This is manageable at this scale, but it is not "free". The team should expect a small but recurring operational cost for payment and audit incidents.

### Alerts to maintain

The design needs a careful alert set, including:

- Payment dedupe rows stuck in Pending or Unknown beyond a threshold
- PayEx timeout rate or error-rate spikes
- API approval latency regression
- SQL deadlocks, lock waits, or connection saturation
- Retry job backlog or failed retries
- Audit-table write failures or retention errors

ESTIMATE: 5 to 8 actionable alerts, with tuning over the first 2 to 3 months.

### Runbooks to write

The team should maintain runbooks for:

- PayEx timeout handling and retry safety
- Dedupe row stuck in Pending/Unknown
- Manual reconciliation when PayEx returns an unknown outcome
- SQL lock or conditional-update failure investigation
- Audit retention and forensic lookup

ESTIMATE: 4 to 6 runbooks, with 1 to 2 engineer-days of effort per runbook during the initial setup, then shorter maintenance updates afterwards.

### Recurring reconciliation work

Because the design intentionally tolerates unknown outcomes and retried calls, there is recurring reconciliation overhead:

- Review pending/unknown rows daily or several times per week
- Reconcile PayEx reference and SQL dedupe state when timeouts occur
- Check retry backlog and dashboard health
- Archive or verify seven-year audit retention compliance

ESTIMATE: 0.5 to 2 hours per day of operational attention during the first few months, declining somewhat after the team settles into the pattern.

This is a meaningful but manageable cost. It is not huge at 40,000 invoices/month, but it is above the cost of a simple API flow because unknown payment states require active oversight.

## 4) Comparison with the main alternative: transactional outbox + worker

The main alternative is a transactional outbox pattern backed by a worker that submits payment to PayEx asynchronously.

### Build effort comparison

| Area | Option A: idempotency + dedupe | Transactional outbox + worker |
|---|---|---|
| Build effort | ESTIMATE 22 to 50 engineer-days | ESTIMATE 25 to 60 engineer-days |
| Why | Simpler state model, but requires SQL-level correctness and durable dedupe semantics | Needs outbox table, worker logic, queue semantics, poison-message handling, and message visibility management |

My estimate is that Option A is usually slightly cheaper to build for this specific system because it keeps the payment call in the approval path and avoids building an asynchronous messaging layer. However, the difference is not dramatic; the real difference is in operational complexity and risk.

### Run cost comparison

| Area | Option A | Transactional outbox + worker |
|---|---|---|
| Azure spend | ESTIMATE $120 to $420/month | ESTIMATE $250 to $800+/month |
| Why | Uses Azure SQL plus small monitoring; no queue infrastructure needed | Adds Service Bus or equivalent messaging, worker compute, and more operational monitoring |

This estimate assumes the Service Bus is provisioned and active in the alternative. If the team already runs Azure Service Bus centrally, the difference shrinks, but the queue still adds budget and operations.

### Operational comparison

| Area | Option A | Transactional outbox + worker |
|---|---|---|
| Operational complexity | Moderate | Moderate to high |
| Main burden | Retry backlog, unknown-state reconciliation, pay-out verification | Queue backlog, worker dead-letter handling, message redelivery, replay management |
| Audit burden | Directly tied to approval and dedupe tables | Also requires outbox and message logs to reconstruct state |

In practice, Option A is easier to reason about in a single-API approval flow, but it requires a disciplined retry and reconciliation process. The transactional outbox pattern has stronger asynchronous guarantees but usually brings more infrastructure and message-operational complexity.

## 5) Least certain items and the biggest cost driver

### Least certain items

These are the cost items with the biggest uncertainty:

- Whether PayEx truly honors the idempotency key for repeated requests
- Whether a payment can be reliably matched back to our own reference if the key is not honored
- The actual SQL sizing needed for audit data and dedupe history over seven years
- Whether the retry job runs in existing App Service or requires a separate worker resource
- Whether the on-call burden is absorbed by a central platform team or by the application team

### The single fact that changes the totals most

The single biggest fact is: whether PayEx honors the idempotency key and returns the original result for repeated submissions.

If the answer is yes, then Option A stays close to the lower end of this estimate.

If the answer is no, or if the service does not reliably support key-based dedupe, then the team must add:

- more reconciliation work,
- more payment reference lookup logic,
- more alerting and manual investigations,
- possibly a stronger worker pattern or a compensating workflow,
- and likely higher operational cost and engineering time.

That uncertainty alone could easily move the total build effort upward by 20% to 60% and increase the recurring operational cost materially.

## Bottom line

- Build effort: ESTIMATE 22 to 50 engineer-days total, including the bias for two newer engineers
- Monthly run cost: ESTIMATE $120 to $420/month in Azure for the new elements of this design
- Operational burden: manageable at this workload, but not negligible because the system must reconcile timeouts and auditable approval state for seven years
- Compared to the transactional outbox + worker pattern: Option A is likely cheaper to build and cheaper to run, but it shifts more responsibility onto careful retry and reconciliation operations

The largest open risk is not SQL cost or App Service cost; it is the actual PayEx idempotency contract.
