Checked error handling, authorization, injection, thread safety/shared state, sensitive logging, and refactor behavior. The first five categories do not apply to this arithmetic-only change; the rounding change introduces a behavior regression.

| # | File | Line | What goes wrong | Confidence | Model / version |
|---|------|------|-----------------|------------|-----------------|
| 1 | `backend/src/InvoiceApp.Domain/DiscountCalculator.cs` | 15–16 | Rounding the discount toward zero before subtracting can under-apply it. For example, 10% off 10.09 produces 9.09 instead of 9.08 with the previous rounding behavior. | 8/10 | Auto (dynamic); model version unavailable, CLI 1.0.105 |

The workspace’s current `DiscountCalculator.cs` does not match the supplied diff, so verify that this is the intended file revision.

