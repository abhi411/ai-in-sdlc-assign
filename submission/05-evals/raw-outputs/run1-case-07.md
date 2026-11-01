| # | Finding | File and line | What goes wrong | Confidence |
|---|---|---|---|---|
| 1 | Sensitive data in logs | `backend/src/InvoiceApp.Api/Controllers/ApprovalsController.cs:35–36` | Logging the full invoice can expose customer names, amounts, and decision notes in log storage; logging the session also records user identity and role. | 9/10 |
| 2 | Undefined members in this checkout | `backend/src/InvoiceApp.Api/Controllers/ApprovalsController.cs:34–36` | The current controller/base class has no `_logger` or `CurrentUser` member, and the controller does not inject a logger. Applied to this checkout, these references fail compilation. | 9/10 |

