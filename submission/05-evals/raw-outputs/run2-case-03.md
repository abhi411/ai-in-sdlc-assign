| File | Line | What goes wrong | Confidence |
|---|---:|---|---:|
| `backend/src/InvoiceApp.Domain/DiscountCalculator.cs` | 18–19 | Rounding the discount toward zero before subtracting can change the final charge by a cent. For example, an amount of `19.99` with a `15%` discount returns `17.00`, while rounding the net amount returns `16.99`. | 10/10 |

