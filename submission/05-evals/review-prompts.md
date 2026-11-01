# Prompts

## v1 (baseline, verbatim from ops/evals/README.md)
Review this diff for defects. For each finding give the file, the line, what goes wrong, and how confident you are. If you find nothing, say so explicitly rather than listing general observations.

## v2 (the ONE changed variable: prompt only; model and everything else stay identical)
Review this diff for defects. Before listing findings, check it against these categories: error handling and swallowed exceptions, authorization and role checks, injection, thread safety and shared state, sensitive data in logs, and behaviour changes hidden inside refactors. For each finding give the file, the line, what goes wrong, and how confident you are. If you find nothing, say so explicitly rather than listing general observations.