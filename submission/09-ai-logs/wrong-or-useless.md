# Where the agent was wrong or useless

## Claude (planning stage): real errors from this session
| # | What it claimed | Why it was wrong | How detected | Action |
|---|---|---|---|---|
| 1 | Assumed .mcp.json would declare a Mermaid server (playbook step 11.2 told you to look there) | .mcp.json only configures Playwright; no Mermaid server exists in the repo | You pasted the file | Separate mermaid server added to .vscode/mcp.json |
| 2 | Playbook relied on the assignment text saying ops/README.md ends with an agent-setup section | The delivered ops/README.md has no such section | Reading the file in the zip | Risk audit flags the gap |
| 3 | Suggested the rule "controllers must not use the repository directly" as a good architecture test candidate | False today: InvoicesController injects IInvoiceRepository and calls it directly | Reading InvoicesController.cs | RUN.md warns against this rule |

## Copilot (repo work): what was wrong and what was corrected

The initial AI analysis had several important problems. The repo-backed corrections below capture the specific claim, why it was wrong, how it was noticed, and what was changed.

*   **Unverified "exactly once in effect" claim for Option 1:** The AI claimed "This is the cleanest “exactly once in effect” design when the provider supports idempotency keys." (`session-a-tradeoffs.md`, "Option 1: Idempotency key with a dedupe table"). This was wrong because the claim depended on unverified assumptions about PayEx's capabilities. The current repo still had no PayEx integration and `ops/README.md` explicitly described the planned nature of the deployment. The issue was caught by re-reading the code and the scenario evidence together and by refusing to treat a future design goal as current behavior.
*   **Recommendation based on unverified PayEx capabilities:** The AI said Option 1 was the only safe way to handle the 30-second timeout. That recommendation was wrong because the safe retry contract only exists if PayEx actually honors a stable idempotency key and offers reliable lookup after ambiguity. We corrected the decision by requiring explicit external evidence before accepting that premise.
*   **Misrepresentation of current audit record capabilities:** The AI described Option 1 as producing the strongest audit record for SOC 2 even though the current codebase only had an in-memory repository and no durable audit table. We corrected this by making the ADR explicit that the database and audit features are planned, not existing.
*   **Ignoring the provisioned but unused Azure Service Bus:** The AI's recommendation treated the Azure Service Bus as if it were irrelevant. That was wrong because the scenario material described it as provisioned but unused, and the final recommendation accounted for that infrastructure instead of bypassing it without a clear reason.
*   **Underestimated build effort for database and audit work:** The AI estimated a small schema and migration effort. That was wrong for a system that had no database and required durable audit retention, outbox logic, and migration testing. We corrected this in the ADR by emphasizing the need for a full durable transactional design and the cost implications.
*   **Failure to ground recommendations in current repo facts:** Several claims were written as if the future design existed already. We corrected this by filtering every recommendation through the actual code: current repo, current domain model, and current runtime assumptions. This was the central correction that prevented the later, more dangerous design drift.
