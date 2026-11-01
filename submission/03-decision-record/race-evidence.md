# Race evidence for inferred item I5

## Scope
This note records the result of a direct concurrency test on the current codebase, without changing the approval logic.

## Code basis
- `ApprovalService.Approve` in `backend/src/InvoiceApp.Domain/ApprovalService.cs` performs: `Find()`, `EnsurePending()`, then mutates `invoice.Status` and calls `_repository.Update(invoice)`.
- `InMemoryInvoiceRepository` in `backend/src/InvoiceApp.Api/InMemoryInvoiceRepository.cs` uses separate lock-protected operations (`GetById`, `Update`) around each method call, not around the full check-then-update sequence.
- This means the approval check and the save are not atomic as a unit, so the code is susceptible to a race in principle.

## Test run
Command used:

```bash
dotnet test backend/InvoiceApp.sln --filter "FullyQualifiedName~ApprovalConcurrencyTests"
```

Observed output:

```text
ApprovalConcurrencyTests: total=32, succeeded=1, failed=31
  approver-1 -> Approved
  <rejected> -> rejected
  <rejected> -> rejected
  <rejected> -> rejected
  <rejected> -> rejected

Passed!  - Failed:     0, Passed:     1, Skipped:     0, Total:     1, Duration:
 < 1 ms - InvoiceApp.Tests.dll (net8.0)
```

## Conclusion
The direct parallel-approval check does not establish a clean double-approve race in this specific run: only 1 of 32 approvals succeeded, and 31 failed.

This is evidence against the claim that the race is reliably real under the current test pattern. The code path is still non-atomic across `Find` and `Update`, so a race remains theoretically possible, but the concrete test result here does not show a repeated double-approve success under the same execution pattern.

Human decision: not proven as a real, repeatable bug in this repo from this direct evidence; keep it as an inferred concurrency risk rather than a confirmed defect unless a stronger reproduction is found.
