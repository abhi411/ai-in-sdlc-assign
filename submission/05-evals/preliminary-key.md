# Preliminary reading of the 10 cases (Claude, NOT ground truth)


| Case | My reading | Reason |
|---|---|---|
| 01 | Defect | BulkApprove loops over request.Ids with no null check (Ids is nullable) and no atomicity: a failure midway leaves earlier invoices approved and returns an exception |
| 02 | Defect | SQL built by string interpolation from user input (injection) |
| 03 | Defect | Rounding changed from AwayFromZero to ToZero and rounded twice; silent change to money amounts inside a "tidy" change |
| 04 | Clean | Pure rename of _repository to _invoices |
| 05 | Defect | New Delete action has no [RequireRole("Admin")] while the neighbouring Update does; AGENTS.md says destructive actions are Admin only |
| 06 | Probably clean | Adds three reasonable tests; the Pending(...) helper is not in the diff but may already exist |
| 07 | Defect | Logs the whole invoice and session object, which can carry sensitive data (session may include token or role details) |
| 08 | Defect | ConcurrentDictionary replaced by Dictionary: not thread-safe under concurrent requests |
| 09 | Ambiguous | Config change is harmless but the new README text claims signing out resets data, which is false in this code |
| 10 | Defect | catch (Exception) returns 200 "completed", hiding real failures |

So roughly 8 defective, 3 clean (04, 06), 1 ambiguous (09). With only 3 clean cases the false alarm rate is very coarse: one false alarm moves it by 50 percentage points. Your added clean case helps.
