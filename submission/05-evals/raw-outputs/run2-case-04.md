| File | Line | Finding | Confidence |
|---|---:|---|---:|
| `backend/src/InvoiceApp.Domain/ApprovalService.cs` | 11 | Renaming the public constructor parameter from `repository` to `invoices` breaks source callers that use the named argument `new ApprovalService(repository: repo)`. Positional callers are unaffected. | 8/10 |

