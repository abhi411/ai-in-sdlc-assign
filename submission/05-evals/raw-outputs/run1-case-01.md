| File | Line | What goes wrong | Confidence |
|---|---:|---|---:|
| `backend/src/InvoiceApp.Api/Controllers/ApprovalsController.cs` | 44 | `[RequireRole("Approver")]` blocks Admin users from this endpoint, despite the controller and approval policy allowing both Approver and Admin. | 9/10 |
| `backend/src/InvoiceApp.Api/Controllers/ApprovalsController.cs` | 49 | `Ids` is nullable, so a request with `Ids: null` (or omitted) throws during iteration and returns a server error instead of a client error. | 10/10 |
| `backend/src/InvoiceApp.Api/Controllers/ApprovalsController.cs` | 51 | `Approve` exceptions aren’t mapped through `Handle`; a missing or non-pending invoice causes an unhandled error. In a multi-ID request, earlier invoices may already be approved before the batch fails. | 9/10 |

