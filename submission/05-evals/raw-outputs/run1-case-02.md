- **`backend/src/InvoiceApp.Api/Controllers/InvoicesController.cs:28, 32` — SQL injection.** `customer` and `status` are interpolated directly into SQL, so a crafted query parameter can alter the query. Use parameterized queries. **Confidence: 10/10**
- **`backend/src/InvoiceApp.Api/Controllers/InvoicesController.cs:35` — likely build failure.** `_queries` is not declared in the controller in the current checkout, so `_queries.Run(sql)` will not compile unless that member is added elsewhere. **Confidence: 9/10**

