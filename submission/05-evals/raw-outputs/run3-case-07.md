| File | Line | Finding | Confidence |
|---|---:|---|---:|
| `backend/src/InvoiceApp.Api/Controllers/ApprovalsController.cs` | 34 | Destructuring the full invoice and user session into logs can expose customer names, invoice amounts, and usernames to anyone with log access, and retain them beyond the request. | 9/10 |

