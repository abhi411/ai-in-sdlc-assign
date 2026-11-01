# Inferred items (not directly proven by a single line of code)

| # | Claim in the diagrams | Why it is inferred | How to confirm |
|---|---|---|---|
| I1 | The Api and the Domain run in one OS process | Api references Domain as a project (E19); no second host exists | dotnet run, check one process |
| I2 | The browser reaches the API on the same origin (http://localhost:5000) | app.js calls relative URLs (/api...); launchSettings.json sets applicationUrl | Open DevTools Network tab |
| I3 | Middleware runs before the controller action and the role filter runs after routing | ASP.NET Core pipeline semantics plus registration order in Program.cs lines 19-22; not asserted in this repo | Add a temporary log line in each, or read the docs |
| I4 | The "same object reference" note: GetById returns the stored instance, so Approve mutates the stored object before Update | Read of InMemoryInvoiceRepository.GetById (FirstOrDefault returns the list element) and ApprovalService.Approve | Unit test that calls GetById twice and checks ReferenceEquals |
| I5 | Concurrent approvals of the same invoice can both pass EnsurePending | Follows from I4 plus Find and Update being separate locked calls; no test in the repo exercises it | Write a parallel test (see 03-decision-record) |
| I6 | The target-state elements (SqlInvoiceRepository, worker, PayExClient, reconciliation job, telemetry) | They are design proposals; ops/ describes a planned deployment, not code | They are drawn dashed and orange as "planned" |
| I7 | PayEx supports an idempotency key or lookup by our reference | NOT in the evidence packs; the assignment says only "returns a reference on success; times out at 30 s; timeout does not reliably mean failure" | Ask the facilitator; treat as UNKNOWN in the ADR |
