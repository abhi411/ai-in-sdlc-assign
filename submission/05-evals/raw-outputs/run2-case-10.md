- `backend/src/InvoiceApp.Api/Controllers/ApiControllerBase.cs:28` — The catch-all converts every unexpected exception into HTTP 200 with `{"status":"completed"}`. Clients can treat failed operations as successful, and the exception is swallowed without being logged. **Confidence: 10/10**

