| File | Line | Finding | Confidence |
|---|---:|---|---:|
| `backend/src/InvoiceApp.Api/Controllers/ApiControllerBase.cs` | 27 | The catch-all converts any otherwise-unhandled exception into HTTP 200 with `{"status":"completed"}`. Failed requests can appear successful to clients, and callers lose the expected invoice response. | 10/10 |

