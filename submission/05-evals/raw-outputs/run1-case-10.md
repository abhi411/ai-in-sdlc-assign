- **`backend/src/InvoiceApp.Api/Controllers/ApiControllerBase.cs:27`** — The new catch-all converts unexpected failures into HTTP 200 with `{ "status": "completed" }`. Callers may treat failed operations as successful, and the original exceptions are hidden. **Confidence: 10/10**

