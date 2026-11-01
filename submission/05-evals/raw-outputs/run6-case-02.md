## Security Findings

### Alert 1
**File:** `backend/src/InvoiceApp.Api/Controllers/InvoicesController.cs:31, 35`  
**Category:** StringInjection  
**Severity: HIGH | Confidence: 9/10**  
**Problem:** The `customer` and `status` query parameters are interpolated directly into SQL. A caller with a valid session can craft either value to change the query; the resulting rows are returned by `Ok(...)`.  
**Evidence:** The SQL is constructed with both values inside quoted SQL expressions and passed to `_queries.Run(sql)` without parameterization.  
**Suggested fix:** Use parameterized queries for both values.  
**Model name/version:** Unavailable; not exposed.Checked error handling, authorization, injection, thread safety/shared state, sensitive data in logs, and hidden behavior changes in refactors. The concrete finding is SQL injection:

| # | Severity | File | Lines | Vulnerability | Confidence |
|---|----------|------|-------|---------------|------------|
| 1 | 🟠 HIGH | `backend/src/InvoiceApp.Api/Controllers/InvoicesController.cs` | 31, 35 | `customer` and `status` are interpolated directly into SQL, allowing a signed-in caller to alter the query. Use parameterized queries. Model/version: not exposed. | 9/10 |

1. Fix the highest-severity issue.
2. Fix all reported issues.
3. Commit a summary of findings.

