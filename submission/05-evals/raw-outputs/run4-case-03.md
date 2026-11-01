| # | File | Line | Finding | Confidence | Model/version |
|---|------|------|---------|------------|---------------|
| 1 | `backend/src/InvoiceApp.Domain/DiscountCalculator.cs` | 15–16 | The new `ToZero` rounding truncates both the discount and the final amount, changing results from the previous nearest-cent, away-from-zero behavior. For `amount = 1` and `discountPercent = 1.6`, the result changes from `0.98` to `0.99`, reducing the discount by one cent. | 10/10 | Auto; underlying model/version not exposed (CLI 1.0.105) |

Checked error handling, authorization, injection, thread safety/shared state, and sensitive logging: no issues found in this diff. The finding is a behavior change in the rounding refactor.

