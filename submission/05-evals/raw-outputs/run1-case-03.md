- **`backend/src/InvoiceApp.Domain/DiscountCalculator.cs:15`** — Rounding both the discount and the final amount `ToZero` can produce a different result from rounding the discounted amount to cents. For example, `amount = 1.01` and `discountPercent = 0.5` returns `1.01`, whereas the prior `AwayFromZero` rounding returns `1.00`; the discount is effectively lost. **Confidence: 10/10.**

