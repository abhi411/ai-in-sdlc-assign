- `backend/src/InvoiceApp.Api/Controllers/ApprovalsController.cs:44` — The method-level `[RequireRole("Approver")]` also blocks Admins, despite the controller allowing both Approver and Admin. Confidence: **9/10**.
- `backend/src/InvoiceApp.Api/Controllers/ApprovalsController.cs:49-51` — If any ID is missing or not pending, `Approve` throws without being handled. The request returns a server error, and any earlier invoices in the list may already have been approved. Confidence: **10/10**.
- `backend/src/InvoiceApp.Api/Controllers/ApprovalsController.cs:41,49` — `Ids` is nullable, but the code enumerates it without checking; a request with `"ids": null` causes a `NullReferenceException` and server error. Confidence: **10/10**.

