# Submission pack: status by deliverable

Prepared from the uploaded repo zip. Legend: DONE = complete from the repo evidence. DRAFT = content written, you must adopt or rewrite it. YOU = needs your machine or your voice.

| # | Hand-in item | Status | Where | What is still yours |
|---|---|---|---|---|
| 1 | Mermaid as-built container, sequence, target; citations; inferred items | DONE | 01-diagrams | Verified against the current repo and rendered successfully |
| 2 | Architecture test and command | DONE | 02-arch-test | Pass/fail proof and full-suite output are captured in the repo |
| 3 | Exactly-once decision record | DONE | 03-decision-record | ADR is written and includes the "Where the agent was wrong or useless" section |
| 4 | One-page autonomy policy, day-one level L1 | DONE | 04-autonomy-policy | One-page L1 policy is in place and grounded in the repo evidence |
| 5 | Two eval cases and results table | DONE | 05-evals | Added case-11 and case-12; the scoring table and prompt-version comparison are recorded |
| 6 | Risk audit with decision | DONE | 06-risk-audit | Verified against the checked-out repo and the Playwright tool help output |
| 7 | Measurement plan and two numbers | DONE | 07-measurement | Live repo capture and scenario caveats are recorded in the plan and evidence files |
| 8 | Demo video | YOU | 08-video/script.md | Record the demo video and add the final link |
| 9 | AI logs | DONE | 09-ai-logs | Real Copilot entries and the wrong-or-useless notes are included |

Findings worth saying in the video:
1. ops/README.md in this zip has no agent-setup section, although the assignment refers to one.
2. ApprovalService.Approve can double-approve under concurrency (inferred I4/I5): confirm with a parallel test.
3. The eval diffs do not match the repo code line for line; they are fixed exercises.
4. INC-2041 shows a per-call HttpClient causing socket exhaustion: relevant to how PayExClient must be built.
