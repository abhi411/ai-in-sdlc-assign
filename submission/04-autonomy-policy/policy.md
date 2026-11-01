# Autonomy policy: first-response incident summaries

## Scope and default

This policy defines how much autonomy an engineer or agent may take during incident response. It is a ladder, not a one-time permission. The default for the two new engineers on day one is L1: draft-only support while they learn the repo, failure patterns, and evidence-handling standards.

The two new engineers are not expected to operate above L1 until they have passed the evidence gate in Section 5. Until then, all non-draft actions remain human-owned.

## Level ladder

### L1 — Draft triage only

For the first 30 minutes of an alert, the engineer may:
- read exported alert, log, metric, and config evidence;
- build a timeline of observed events;
- rank likely causes using only cited evidence;
- draft a short status note for human review;
- label claims as hypotheses, not confirmed facts;
- cite file and line evidence for every factual statement.

The engineer may not:
- access live systems;
- restart services;
- change config, rules, or code;
- roll back or replay a release;
- contact customers or send stakeholder messages;
- decide finance or customer recovery actions.

The output is always DRAFT and must be reviewed by a named human before it is shared externally.

### L2 — Assisted diagnosis

The engineer may investigate with human supervision and may propose a bounded set of next steps, but may not execute them without a human approval.

Allowed with human supervision:
- trace a suspected call path across repo code and evidence files;
- compare incident evidence to known patterns in the repo or runbooks;
- propose a likely fix direction and a test strategy;
- draft a restart or rollback plan for human sign-off.

Not allowed without a human operator:
- live system changes;
- production restores or redeploys;
- customer or vendor communications;
- any action with financial exposure or data loss risk.

### L3 — Bounded execution

The engineer may execute pre-approved operational steps under human oversight.

Allowed when explicitly approved:
- restart a single service or worker;
- clear a queue or retry a limited batch under a runbook;
- apply a documented config change in a test or non-production environment;
- run a narrow regression test or smoke check tied to the issue.

Not allowed without a human decision-maker:
- broad production changes;
- release rollback outside the approved runbook;
- rule changes affecting customer-facing behavior;
- actions that require security, legal, or finance approval.

### L4 — Independent incident ownership

The engineer may own a first-response path and execute the runbook without waiting for step-by-step approval, subject to the safety controls below.

Allowed:
- triage, diagnosis, and execution within approved playbooks;
- service restarts, rollbacks, and config changes when the runbook explicitly covers them;
- status updates to stakeholders as authorized by the incident lead.

Not allowed:
- changing the incident scope or declaring customer recovery without approval;
- bypassing a required security or finance gate;
- making unsupported claims without evidence.

## Evidence required to move up a level

A promotion is not automatic. Promotion to the next level requires evidence that the engineer can do the job under the current policy.

### Evidence gate from L1 to L2

The engineer must show all of the following on a real or simulated incident:
- at least 2 incident summaries with cited file and line evidence;
- a correct timeline of events without unsupported facts;
- a ranked list of hypotheses tied to observed evidence;
- a clear statement of what is unknown and what needs human confirmation;
- a review approval from a senior engineer or incident lead.

### Evidence gate from L2 to L3

The engineer must show:
- one successful runbook-assisted action under supervision;
- a brief post-action write-up showing what changed, why it was safe, and what evidence confirmed the result;
- a clean pass on a narrow validation check tied to the issue;
- no undocumented safety exceptions;
- human sign-off on the record.

### Evidence gate from L3 to L4

The engineer must show:
- two independently managed incident summaries or small incident responses with no material corrective feedback;
- successful execution of at least one full runbook without supervision;
- accurate evidence-based status updates to stakeholders;
- ability to stop and escalate when evidence is weak or contradictory;
- approval from the incident lead or engineering manager.

## Day-one assignment for the two new engineers

The two new engineers begin at L1 for their first rotation or first 30 days, whichever is longer, unless a manager explicitly promotes them earlier with documented evidence.

This means they are expected to:
- read exported evidence only;
- draft an incident summary that cites file and line evidence;
- surface likely causes and unknowns without guessing;
- escalate to a named human before any live system action.

During this period, their work is judged on quality of evidence and decision discipline, not on speed.

## Grounding evidence examples

The policy is grounded in the repo’s incident evidence:
- INC-2041 shows a release-to-symptom match and PayEx socket/timeouts after release 2.14.0.
- INC-2047 shows event-type drift from InvoiceApproved to invoice.approved while the worker subscription still filters on the old name.
- These examples are used to train the standard for evidence-based conclusions and to prove the difference between a hypothesis and an established fact.

## Safety controls

- Exported evidence only for L1 and L2 work; no live network tools or browser actions unless explicitly approved.
- Output is DRAFT unless a human explicitly approves it for external sharing.
- Uncited claims are discarded.
- A named human approves any move above L1.
- A named human approves any action with a customer, financial, or security consequence.
- If the evidence is weak, contradictory, or missing, the agent must pause and escalate rather than infer.
