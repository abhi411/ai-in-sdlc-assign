| File | Line | Defect | Confidence |
|---|---:|---|---:|
| `backend/src/InvoiceApp.Domain/DiscountCalculator.cs` | 16–17 | Truncating the discount before subtracting can erase small discounts. For `amount = 1.00` and `discountPercent = 0.6`, the discount becomes `0.00` and the result is `1.00`; rounding the discounted amount as before yields `0.99`. | 9/10 |

