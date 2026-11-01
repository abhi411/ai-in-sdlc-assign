# Review scoring summary

## Per-run rates

| Run | Prompt | Caught | Missed | False alarm (without ambiguous) | False alarm (with ambiguous) | Notes |
|---|---|---:|---:|---:|---:|---|
| 1 | v1 | 7/9 (78%) | 1/9 (11%) | 1/3 (33%) | 1/4 (25%) | Stable v1 pattern: case 11 was missed and case 12 was a false alarm |
| 2 | v1 | 7/9 (78%) | 1/9 (11%) | 1/3 (33%) | 1/4 (25%) | Same as run 1 |
| 3 | v1 | 7/9 (78%) | 1/9 (11%) | 1/3 (33%) | 1/4 (25%) | Same as run 1 |
| 4 | v2 | 6/8 (75%) | 2/8 (25%) | 0/3 (0%) | 0/4 (0%) | v2 missed case 01 and case 11; no false alarms |
| 5 | v2 | 7/8 (88%) | 1/8 (13%) | 1/3 (33%) | 1/4 (25%) | One false alarm on case 06; otherwise stable |
| 6 | v2 | 7/8 (88%) | 1/8 (13%) | 1/3 (33%) | 1/4 (25%) | One false alarm on case 12 and one miss on case 11 |

## v1 versus v2 comparison

| Prompt | Aggregate caught | Aggregate missed | Aggregate false alarm (without ambiguous) | Aggregate false alarm (with ambiguous) | Cases whose verdict differed across the three runs |
|---|---|---|---|---|---:|
| v1 (runs 1-3) | 21/27 (78%) | 3/27 (11%) | 3/9 (33%) | 3/12 (25%) | 0 |
| v2 (runs 4-6) | 20/24 (83%) | 4/24 (17%) | 2/9 (22%) | 2/12 (17%) | 3 |

The v2 prompt did not show a strong systematic improvement or decline; it mainly produced more run-to-run variance. The differences are concentrated in case 01, case 06, and case 12, which is consistent with ordinary single-case noise rather than a durable prompt-wide effect.

## Confidence statement

With 12 cases, one case is worth about 8 percentage points. That means a one-case swing in a rate is not a meaningful signal by itself; it is normal noise unless the same verdict repeats across multiple runs. Here, the stable evidence is that the real defects in case 11 were missed in every pass, while the clean case 12 was a false alarm in the v1 runs and correctly clean in two of the three v2 runs. The prompt-to-prompt difference is therefore modest and noisy, not a clear win or loss: one or two case flips are within expected error bars unless multiple runs agree on the same direction.
