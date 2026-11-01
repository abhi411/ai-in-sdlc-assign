- `backend/src/InvoiceApp.Api/Controllers/InvoicesController.cs:47-48` — The controller’s repository interface has no `Delete` method, and the controller/base class defines neither `_logger` nor `CurrentUser`. These references prevent the project from compiling. **Confidence: 10/10**
- `backend/src/InvoiceApp.Api/Controllers/InvoicesController.cs:44-45` — The delete action has no `[RequireRole("Admin")]` restriction, so any signed-in user allowed to reach the controller can delete invoices. Destructive actions should be Admin-only. **Confidence: 9/10**

