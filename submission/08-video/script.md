# Demo video script (target 9 minutes)

Note: the folder is `08-video` in your submission (not `09-video`). The AI logs are in `09-ai-logs`.

How to use: read the lines in quotes out loud. Things in [square brackets] are numbers or facts you must fill in or confirm
before recording. Speak slowly; about 1,000 spoken words, plus the time the commands take to run, gives roughly 8 to 9 minutes.

## What to have open (in order)

| Time | Show on screen |
|---|---|
| 0:00-0:40 | `AGENTS.md`, `ops/README.md` |
| 0:40-2:00 | `01-diagrams/as-built-container.svg`, `as-built-sequence.svg`, `corrections.md`, `inferred.md` |
| 2:00-3:30 | `01-diagrams/target.mmd`, `02-arch-test/RUN.md`, terminal: run the test |
| 3:30-5:00 | `03-decision-record/exactly-once-adr.md` (the "Where the agent was wrong or useless" section) |
| 5:00-6:00 | `04-autonomy-policy/policy.md`, `06-risk-audit/risk-audit.md` |
| 6:00-7:30 | `05-evals/results.md`, `results.csv` |
| 7:30-8:30 | `07-measurement/plan.md` and the two evidence outputs |
| 8:30-9:00 | `09-ai-logs/ai-log.md`, `wrong-or-useless.md` |

## What to say

**1. Intro (0:00)**

"This is my submission for the AI in SDLC workshop. The service is an invoice approval app. One thing to know first: the
`ops` folder describes the planned production setup, not the code as it is today. Today the app has no database and no
PayEx. It keeps invoices in memory. I kept that difference clear in everything I wrote."

**2. Diagrams (0:40)**

"Here are the as-built diagrams. Every box and arrow points to a file or a symbol in the code. The citation list shows where.
I also listed what the AI guessed instead of read. When I checked, some of its claims were wrong, and I fixed them. The list
of fixes is in `corrections.md`. Now the target diagram. It shows the future setup with a database, a background worker and
PayEx. Anything that does not exist yet is marked as planned."

**3. Architecture test (2:00)**

"I wrote one test for one rule: the Domain project must not depend on the web layer or on HTTP code. Domain is where the
business rules live, and I want it to stay free of web and storage code. I run it with this command."

Run: `dotnet test backend/InvoiceApp.sln --filter FullyQualifiedName~ArchitectureTests`

"It passes: one test passed, zero failed. Now I break the rule on purpose. I add an HttpClient field inside the Invoice
class and run the test again."

[Redo this first: put the field INSIDE the class, run the test, and make sure it fails as a TEST failure, not a compile
error. Then say:] "The test fails and names the bad dependency. So the test really catches the mistake. I remove the line,
and it passes again."

[If you do not redo it, say this instead:] "My first attempt only gave a compile error, so it did not prove that the test
catches the mistake. I want to be honest about that."

**4. Decision record (3:30)**

"The question is how to make sure an approved invoice reaches PayEx exactly once. PayEx can time out, and a timeout does not
mean the submission failed. I compared three options: an idempotency key with a dedupe table, a transactional outbox with a
worker, and sending right away with a nightly check. My final choice is the outbox with a worker. The approval, the audit
record and the payment event are saved in one database transaction, so they succeed or fail together. I chose it because we
do not know whether PayEx supports idempotency keys or lookups. The outbox does not depend on that."

"I also tested the AI's advice. I told it I preferred another option, and I asked how each option fails at 3 a.m. on the
last day of the month, and what each costs. [Say honestly that the 3 a.m. and cost checks were done on Option 1 first.]
The section 'Where the agent was wrong or useless' lists exactly where the AI was wrong, with examples."

"I also tried to reproduce a double-approve race with 32 parallel approvals. Only one succeeded, so I could not show it
failing. But the code checks the status and then updates it in separate steps. That is not safe with a real database, so
the decision record says to fix it as part of the move."

**5. Autonomy policy and risk audit (5:00)**

"The policy covers first-response incident summaries. On day one the team runs at level one, draft only. The AI can read
exported logs, build a timeline, rank likely causes and draft an update. It cannot touch live systems, restart anything or
change config. A named person approves anything above level one. I chose this level because two of the six engineers are new
to the code, and they may not catch a wrong summary."

"The risk audit checks the lethal trifecta: private data, untrusted content, and a way to send data out. My decision is to
remove the outside-communication leg for the incident workflow. The agent only gets exported, redacted evidence, with no
browser and no outbound network. I will revisit this if the agent ever needs live access."

**6. Evaluation (6:00)**

"The repo has ten fixed review cases. I added two of my own: one real defect and one clean change. [Say where they came
from: found by reading the code I was given.] I ran all twelve cases three times with the first prompt, then changed only
the prompt and ran three more times."

"Results: first prompt caught [X of 24] defects and had [Y of 9] false alarms on clean cases. Second prompt caught
[X of 24] and had [Y of 9] false alarms. [One sentence: better, worse or the same.] With only twelve cases and three runs,
a difference of one or two cases is not strong evidence, so I would not call this a real improvement yet."

**7. Measurement plan (7:30)**

"I would measure three things before the rotation: lead time for changes, change failure rate, and review turnaround. I
could get two of them today from the repo and its CI history. From the CI history file, twenty runs had a median time of
31.3 minutes and two failures, so a ten percent failure rate. But the `ops` folder says that data is made up, so it is only
a scenario baseline. The live repo has [0 merged PRs and 1 CI run], which is too small to measure anything. Review
turnaround cannot be captured yet, because there is no review data. I will re-measure weekly and always show the sample
size."

**8. AI logs and close (8:30)**

"The AI logs show what I asked the AI, what I accepted and what I rejected. The file `wrong-or-useless.md` lists the specific
mistakes I corrected. In short, I separated what exists from what is planned, I tested the AI's advice instead of trusting
it, and I used numbers I measured, with their limits stated. Thank you."

## Before you record

- Redo the sabotage test (section 3) and replace `fail.txt` with the real test failure.
- Fill in every [bracket] above; remove the line you do not use.
- Make sure `Invoice.cs` is back to normal after the sabotage (`git diff` should show nothing).
- Use a large terminal font. Keep the video between 8 and 10 minutes, saved as MP4, then paste the link into `VIDEO_LINK.md`.