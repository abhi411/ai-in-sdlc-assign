# Baseline measurement plan (capture before the rotation starts)

Three metrics. Each has an exact source. Two are captured today (below); the third is a plan only.

## 1. Lead time for changes
- Definition: time from first commit of a change to that change running in production. Proxy until deploys are tracked: PR created to PR merged, plus CI duration.
- Source and commands (run on a real clone with history):
  - gh pr list --state merged --limit 200 --json number,createdAt,mergedAt,title > prs.json
  - python3 or jq: median and p90 of mergedAt minus createdAt
  - git log --since="90 days ago" --pretty=format:"%h|%aI|%s" for commit times
- Limit: the live repo is tiny (about 6 commits when I looked at the GitHub page), so a median from it is nearly meaningless; say so.
- SCENARIO BASELINE ONLY, CI component: pipeline wall-clock per run from ops/pipeline/run-timings.csv, n=20 runs, 2026-01-19 to 2026-02-02: median 31.3 minutes (1876 s), range 28.4 to 35.1 minutes. Static analysis alone is 26 percent of CI time. Source: 07-measurement/evidence/compute_ci_metrics.py, output in ci-metrics-output.txt. Caveat: ops/README says the figures in that folder are invented, so this is a scenario baseline, not a live production number and not the chosen repo baseline.

## 2. Change failure rate
- Definition: share of changes that cause a failure needing remediation. Proxy available today: share of CI pipeline runs that conclude failure.
- Source: gh run list --limit 200 --json databaseId,conclusion,createdAt,headBranch,event,name > runs.json; failures / total. Better later: incidents linked to a release (INC-2041 followed release 2.14.0) divided by releases.
- SCENARIO BASELINE ONLY: 2 failed of 20 runs = 10 percent (95 percent Wilson interval 3 to 30 percent). Both failures were pull-request runs on fix/ branches; recovery to a green run took 6.2 hours and 51.5 hours. Caveat: a CI failure is not a production failure, and 20 runs is a small sample; this is scenario evidence, not the live repo baseline.

## 3. Review turnaround (plan only, not captured)
- Definition: time from review request (or PR ready) to first review.
- Source: GitHub GraphQL: pullRequests { nodes { createdAt reviews(first:1){nodes{submittedAt}} } } or gh api repos/OWNER/REPO/pulls/N/reviews. Not capturable today: the pack contains no review data and the live repo has few or no reviewed PRs.

## Captured from the live repo
- Merged PRs captured from `gh pr list --state merged --limit 200`: 0 merged PRs, sample size n=0. Median lead time is `n/a` because there are no merged PRs to compute a lead-time distribution. This is too small for a meaningful production metric.
- CI runs captured from `gh run list --limit 200`: 1 total run, 0 failures, rate 0.0. Sample size n=1 is too small to support a meaningful change-failure-rate estimate; this is a signal only.
- Chosen pair to present: `0 merged PRs` and `1 CI run / 0 failures`. These are the only two live-repo numbers with direct evidence from the current repository, and they are the safest pair to report because they are explicit counts rather than inferred statistics from a tiny sample. The 31.3-minute CI median and the 10% failure-rate numbers are scenario-only values from `ops/pipeline/run-timings.csv` and are not the chosen baseline for the live repository.

## Re-measure
Weekly during the first rotation, then monthly; compare against these baselines, and always report the sample size next to each number. Do not hide small samples or convert a tiny live sample into a stable baseline.
