# Where the plan (ops/) and the code disagree, and likely agent mistakes

| Source of confusion | What it says | What the code actually has |
|---|---|---|
| ops/README.md scenario note | database, message topic, PayEx integration | None exist in backend/ (see absence checks in citations.md) |
| ops/incidents/INC-2041/deploy-diff.patch | src/InvoiceApp.Api/Clients/PayExClient.cs, Contracts/DecisionResponse.cs, appsettings.Production.json | No Clients/ or Contracts/ folder in the repo |
| ops/incidents/INC-2047 | EventPublisher, notification worker, Service Bus topic invoice-events | No publisher or worker code; Service Bus is not referenced |
| ops/pipeline/ci-pipeline.yml | Integration tests, gitleaks, CodeQL, licence check, docker build, trivy, /health wait | .github/workflows/ci.yml only builds and runs dotnet test; no Dockerfile; no /health endpoint |
| ops/evals/cases/*.diff | CurrentUser.Name, DecisionResponse, _logger, _queries, ConcurrentDictionary repository, static DiscountCalculator.Apply | The repo uses HttpContext.GetSession().Username, returns Invoice directly, has no logger, a List-plus-lock repository and an instance DiscountCalculator. The eval diffs are fixed review exercises and do not match the repo line for line |
| ops/evals case 06 and 07 | author name "nitin" in tests | Irrelevant to behaviour; shows the diffs are synthetic |
| Eval case 09 text | "sign out and sign in again resets sample data" | False for the code: InMemoryInvoiceRepository is a singleton (Program.cs line 14), so signing out does not reset anything. Also the demo users live in appsettings.json, not "the in-memory store" |
| README.md | "Invoices move through Draft, Pending Approval, then Approved or Rejected" | Correct (InvoiceStatus.cs, ApprovalService.cs) |
| AGENTS.md | "Business rules go in the Domain project, never in controllers" | Mostly followed, but InvoicesController.Create validates input and Delete bypasses ApprovalService by calling the repository directly (InvoicesController.cs lines 50-58, 72-75) |

## Corrections made during verification
- Normalized the repo-relative file paths in the citation list to full paths under the working repo so the table reflects the current code layout exactly.
- Confirmed that every E1-E19 citation is backed by a live symbol in the current repo, and marked the full table as Verified with explicit notes instead of leaving all entries uncleared.
- Confirmed that the actual workflow file is `.github/workflows/ci.yml` and that the e2e test directories remain empty except for `.gitkeep`, so the CI and Playwright entries are accurate.
- Confirmed that `E7a` is driven by `DemoUsersOptions` plus the `Users` array in `backend/src/InvoiceApp.Api/appsettings.json`, not by a separate code-only configuration object.
- No diagram label in the as-built diagrams required a code change after re-reading the current implementation; the diagrams describe the current app accurately, while the target diagram remains intentionally future-state and planned.
