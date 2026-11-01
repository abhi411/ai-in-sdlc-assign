| File | Line | Finding | Confidence |
|---|---:|---|---:|
| `backend/src/InvoiceApp.Api/Controllers/InvoicesController.cs` | 47–48 | The action references `_repository.Delete`, `_logger`, and `CurrentUser`, none of which exist in the repository/controller shown here (`IInvoiceRepository` exposes `Remove`). This prevents the project from compiling. | 10/10 |
| `backend/src/InvoiceApp.Api/Controllers/InvoicesController.cs` | 44–49 | The delete action lacks `[RequireRole("Admin")]`. The middleware checks sign-in, but without a role restriction any signed-in user—including an Approver—can delete invoices. | 10/10 |

