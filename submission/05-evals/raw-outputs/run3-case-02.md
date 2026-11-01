| File | Line | What goes wrong | Confidence |
|---|---:|---|---:|
| `backend/src/InvoiceApp.Api/Controllers/InvoicesController.cs` | 38 | `_queries` is not declared or injected in `InvoicesController` (nor provided by `ApiControllerBase`), so this reference prevents the project from compiling. | 10/10 |
| `backend/src/InvoiceApp.Api/Controllers/InvoicesController.cs` | 31, 35 | `customer` and `status` are interpolated directly into SQL. A caller can alter the query predicates, potentially exposing invoices beyond the intended search. Use parameterized queries. | 10/10 |

