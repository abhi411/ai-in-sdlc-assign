| File | Line | Defect | Confidence |
|---|---:|---|---:|
| `backend/src/InvoiceApp.Api/Controllers/InvoicesController.cs` | 44 | The delete action lacks `[RequireRole("Admin")]`, so it does not enforce the project’s Admin-only rule for destructive actions. | 10/10 |
| `backend/src/InvoiceApp.Api/Controllers/InvoicesController.cs` | 47–48 | This won’t compile against the current code: `IInvoiceRepository` has `Remove(string)`, not `Delete(string)`, and the controller has no `_logger` or `CurrentUser` members. | 10/10 |
| `backend/src/InvoiceApp.Api/Controllers/InvoicesController.cs` | 47–49 | The action always returns `204`, including when the invoice does not exist. The current repository contract reports whether removal succeeded, and the existing endpoint returns `404` when it did not. | 9/10 |

