# ADR-001: Exactly-once submission of approved invoices to PayEx

Status: Accepted. Date: 2026-11-01.

## 1. Context

This ADR addresses the critical requirement for exactly-once submission of approved invoices to an external payment provider, PayEx. The current system uses an in-memory repository with no database, no PayEx integration, and no retry mechanisms. Key constraints include:
-   **Volume:** Peak near 80 approvals/minute (average 1.33/s), with 60% of 40,000 monthly invoices approved in the last three days of the month.
-   **PayEx Contract:** PayEx has a 30-second timeout. Crucially, a timeout does *not* reliably mean the submission failed, creating an ambiguous state.
-   **Auditability:** Approval actions must be auditable for seven years (SOC 2 Type II requirement in six months).
-   **Existing Infrastructure:** Azure Service Bus is provisioned but currently unused.
-   **Lessons Learned:** Past incidents (INC-2041) highlight the need for a pooled `HttpClient` and explicit timeouts for external calls to prevent socket exhaustion.
-   **Team Context:** The team consists of six engineers, two of whom are new to the codebase.

## 2. Problem: Ensuring Exactly-Once Payment Submission

The core problem is guaranteeing that an invoice, once approved, results in exactly one payment attempt with PayEx, despite network ambiguities (30s timeout), system crashes, and concurrent user actions. Challenges include preventing duplicate payments, ensuring all approved invoices are eventually paid, and maintaining a robust, auditable trail.

## 3. Options (Human Decision)

We considered three primary options for handling PayEx submissions:

1.  **Idempotency Key + Dedupe Table:** A durable payment-request record is created in SQL with a unique idempotency key before calling PayEx. Retries use the same key, relying on PayEx to deduplicate.
    *   **What would change it:** *Confirmation* from PayEx that it reliably supports a stable idempotency key for deduplication and provides a lookup mechanism by this key or a payment reference after a timeout.

2.  **Transactional Outbox + Worker:** The approval, audit record, and a payment event are committed to an outbox table in a single SQL transaction. A background worker reads the outbox, calls PayEx, and records the outcome. This decouples the submission from the initial request.
    *   **What would change it:** *Elimination* of the 7-year audit requirement or a *significant reduction* in required operational resilience for payment processing.

3.  **Optimistic Submission + Nightly Reconciliation:** The app makes a best-effort payment submission, with a nightly job to reconcile discrepancies. This option is rejected due to high duplicate/missed payment risk and unacceptable delays in reconciliation for a financial process, especially at month-end volumes.

## 4. Initial Recommendation (Human Decision)

The initial recommendation was **Option 1 (Idempotency Key + Dedupe Table)**, primarily due to its perceived "exactly once in effect" guarantee and fit with Azure SQL. This was contingent on critical, unverified assumptions about PayEx supporting idempotency keys and lookup mechanisms.

## 5. Stress Test Outcomes (Human Decision)

Further analysis, including stress testing (`session-b-pressure-1.md`, `session-b-pressure-2.md`), was performed on the leading candidate, Option 1 (Idempotency Key + Dedupe Table). It confirmed that the recommendation *only moves* if the core assumption about PayEx's idempotency support is *false*. If PayEx does not support a stable idempotency key or reliable post-timeout lookup, then Option 1 is not safe, as retries after a 30-second timeout could create duplicate payments. The team's familiarity or inexperience does not override this fundamental dependency on PayEx's capabilities.

This is important: the stress-test evidence is proof about why Option 1 is unsafe under the current uncertainty, not a statement that Option 1 remained the chosen final design. The final decision is Option 2, for the reasons stated below.

## 6. Failure Analysis at 3 a.m. on Last Day of Month (Option 1 stress test)

A detailed failure analysis (`session-c-3am.md`) for the initially chosen Option 1 (Idempotency Key + Dedupe Table) under peak load (80 approvals/minute) highlighted why this pattern fails if the external contract is not proven. This is a stress test of the rejected design, not the final architecture choice:

*   **PayEx Slowness/Timeout:** Synchronous PayEx calls in the request path can hold web server threads for 30+ seconds, leading to approver-facing latency and potential thread exhaustion (estimated ~40 in-flight requests at once).
*   **Duplicate-Payment Risk (if PayEx ignores idempotency key):** This is the catastrophic failure mode. If PayEx does not honor the idempotency key, every retry after a timeout becomes a new charge. At 80 approvals/minute, this exposes ~40 concurrent duplicate payment attempts immediately, potentially leading to 4,800 affected approvals per hour.
*   **Stuck Rows (`Pending`/`Unknown`):** A crash or deploy between the dedupe insert and the PayEx call can leave rows permanently in `Pending`. Timeouts lead to `Unknown` status. Without a robust retry/reconciliation, these accrue (e.g., 400 stuck rows in 5 minutes, 4,800 in an hour), leading to unpaid invoices.
*   **SQL Throttling/Failover:** If SQL is unhealthy, conditional updates and dedupe inserts fail, blocking approvals entirely.
*   **Retry Job Concurrency Hazard:** A retry job racing with a fresh approval for the same invoice/key can cause issues, especially if PayEx ignores idempotency.
*   **Poison Rows:** Rows repeatedly failing (e.g., due to a persistent PayEx issue) can lead to infinite retries, consuming resources and potentially causing duplicate charges if PayEx ignores the key.

The analysis revealed that detection relies on SQL backlogs and retry job logs, but crucial financial risks like actual duplicate payments or successful payments after timeouts are *invisible* without explicit PayEx lookup or external reconciliation.

## 7. Race Evidence (Human Decision)

Concurrency testing (`race-evidence.md`) on the current `ApprovalService.Approve` showed that while the check (`EnsurePending`) and update (`_repository.Update`) are not atomic, a clean, repeatable double-approve race was *not reliably reproducible* in the specific test run (1 of 32 succeeded, 31 failed). This suggests the in-memory repository's locking might provide some incidental protection, but the non-atomic nature of the operation still presents a theoretical concurrency risk that needs to be addressed when moving to a durable store.
*   **What would change it:** A clear, repeatable reproduction of a double-approve success under load in the current in-memory implementation, or a formal proof of atomicity for the check-then-update sequence across a durable SQL transaction.

## 8. Cost Estimate (Human Decision, Option 1 comparison)

The cost analysis (`session-d-cost.md`) for Option 1 (Idempotency Key + Dedupe Table) provided the following estimates. This section is intentionally a comparison of the rejected Option 1, showing why the risky path is materially more expensive once operational and reconciliation cost are included.

*   **Build Effort:** ESTIMATE 22 to 50 engineer-days (including a 20-30% uplift for two new engineers). This covers schema, repository, approval logic, dedupe logic, PayEx client, retry job, audit, alerts, and tests.
*   **Monthly Run Cost:** ESTIMATE $120 to $420 per month (new Azure SQL, Azure Monitor, small background worker).
*   **Operational Cost:** Moderate, including 24x7 on-call burden (ESTIMATE 1/6 engineer's time), 5-8 alerts, 4-6 runbooks, and 0.5-2 hours/day of recurring reconciliation attention.
*   **Comparison to Option 2:** Option 1 is ESTIMATE slightly cheaper to build and run than Option 2 (Transactional Outbox + Worker) but shifts more responsibility onto careful retry and reconciliation operations.
*   **Largest Uncertainty:** The most significant cost driver and uncertainty remains whether PayEx truly honors the idempotency key. If not, build effort could increase by ESTIMATE 20-60%, and operational costs would rise materially.
*   **What would change it:** A definitive, verifiable contract from PayEx regarding idempotency and lookup, or a significant change in the business's risk tolerance for duplicate payments or missed payments.

## 9. Final Decision (Human Decision)

Given the unverified assumptions about PayEx's idempotency and lookup capabilities, and the significant financial and operational risks highlighted by the 3 a.m. failure analysis if those assumptions prove false, the final decision is to adopt **Option 2: Transactional Outbox + Worker.**

This decision is the correct one even though the stress-test evidence in Sections 6 and 8 was gathered against Option 1. Those sections are proving the failure mode of the rejected design; they are not evidence that Option 1 should remain the chosen design. The outcome of those analyses is precisely why Option 2 is selected.

This decision prioritizes correctness, auditability, and operational safety over the marginal estimated cost savings of Option 1 when PayEx's external contract is uncertain. The transactional outbox pattern provides:
-   **Durability:** Ensures no approved invoice is lost, even if PayEx is slow or the system crashes.
-   **Decoupling:** Frees the web request thread from the 30-second PayEx timeout, improving approver experience.
-   **Auditability:** Naturally supports the 7-year audit trail by logging every state change and event.
-   **Resilience:** Provides a clearer operational model for retries, poison messages, and reconciliation when dealing with ambiguous external provider states.
-   **Leveraging Existing Infrastructure:** This option can more readily leverage the already provisioned Azure Service Bus (though the initial worker can be simple).

The concurrent update race in `ApprovalService.Approve` must be fixed as part of this. The transactional outbox pattern addresses this by enclosing the invoice status update, audit log, and outbox insert within a single SQL transaction.

*   **What would change this decision:** Definitive, written confirmation from PayEx that it provides a robust, reliable idempotency key *and* a lookup API for payment status after ambiguous timeouts. Such evidence would make Option 1 viable and potentially preferable due to its simpler overall flow.

## 10. Consequences

*   **Positive:** No lost approvals; improved approver experience due to decoupled payment submission; robust audit trail for SOC 2; bounded blast radius for PayEx issues; clearer operational model for `UNKNOWN` states; leveraging provisioned Service Bus infrastructure.
*   **Negative:** Adds a new moving part (worker service) with associated operational overhead (health checks, monitoring); eventual (seconds) payment submission; on-call engineers must understand worker and queue semantics.

## 11. Where the agent was wrong or useless

The initial AI analysis contained several critical errors and oversights:

*   **Unverified "exactly once in effect" claim for Option 1:** The AI claimed "This is the cleanest “exactly once in effect” design when the provider supports idempotency keys." (`session-a-tradeoffs.md`, "Option 1: Idempotency key with a dedupe table"). This was wrong because the claim was based on crucial, *unverified assumptions* about PayEx's capabilities (e.g., support for idempotency keys, safe reuse of keys, lookup by key/reference) that were not present in the provided evidence. `ops/README.md` explicitly stated PayEx integration was not in the code yet. The agent failed to highlight this fundamental lack of evidence.
*   **Recommendation based on unverified PayEx capabilities:** The AI stated, "It is the only option that directly addresses the 30-second ambiguous timeout with a repeatable, safe retry contract." (part of "Recommendation" for Option 1 in `session-a-tradeoffs.md`). This was wrong as the "safe retry contract" was entirely dependent on the unverified PayEx capabilities mentioned above. The recommendation was therefore built on an unproven premise.
*   **Misrepresentation of current audit record capabilities:** The AI claimed Option 1 "produces the strongest audit record for SOC 2 and the seven-year retention requirement." (part of "Recommendation" for Option 1 in `session-a-tradeoffs.md`). This was wrong because the current `ApprovalService.cs` shows an in-memory update with no audit persistence. The database and audit features were *planned*, not *existing* or *implemented*. The agent treated a future design goal as a current capability.
*   **Ignoring the provisioned but unused Azure Service Bus:** The AI's recommendation for Option 1 explicitly stated "Azure Service Bus is not used in this design" (`session-a-tradeoffs.md`). This was wrong because `session-a-tradeoffs.md` and `ops/README.md` clearly stated that Azure Service Bus was "provisioned but not yet used." The agent recommended a design that actively bypassed existing, provisioned infrastructure without a compelling justification or comparative analysis for *not* using it.
*   **Underestimated build effort for new database setup:** The AI estimated "Schema and migrations: 1.5 - 3.5 engineer-days" for Option 1 (`session-d-cost.md`). This was wrong and a significant underestimation. Given the absence of a database (current in-memory repository), the task involves designing, implementing, and testing a *new* SQL schema for a production system with 7-year audit retention, along with migration scripts, all for a team with new members. A realistic estimate would be considerably higher for this critical foundation work.
*   **Failure to critically assess foundational assumptions:** Throughout its analysis, the agent consistently treated the *desirability* of PayEx having certain features (like idempotency) as *evidence* that PayEx actually possessed those features. This led to conclusions and recommendations that were not grounded in the provided factual context, particularly regarding external dependencies.