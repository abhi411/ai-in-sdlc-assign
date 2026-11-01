The checked-out `DiscountCalculator.cs` does not match the supplied diff, so this review is based on the diff text. Category check: no error-handling, authorization, injection, thread-safety, or sensitive-logging changes; the rounding refactor changes behavior.

| # | File and line | Finding | Confidence | Model / version |
|---|---|---|---|---|
| 1 | `backend/src/InvoiceApp.Domain/DiscountCalculator.cs:15` | Rounding the discount toward zero before subtracting can reduce the discount and make the customer pay more. For example, `$10.00` at `1.26%` yields `$9.88`, whereas the previous calculation yields `$9.87`. | 9/10 | Auto mode / CLI 1.0.105 |

