## Security Findings

### Alert 1
**File:** `/home/abc/projects/ai-in-sdlc-assignment/backend/src/InvoiceApp.Api/Controllers/InvoicesController.cs` — supplied `Search` method, SQL construction and `_queries.Run(sql)` statements (line numbers unavailable in the checkout)
**Category:** StringInjection  
**Severity: HIGH | Confidence: 9/10**  
**Problem:** `customer` and `status` come from query parameters and are interpolated directly into SQL. An attacker can alter the query conditions and potentially use SQL injection to access data beyond the intended search.  
**Evidence:** The supplied code builds `LIKE '%{customer}%'` and `Status = '{status}'`, then passes the resulting SQL to `_queries.Run(sql)` without parameterization.  
**Suggested fix:** Use parameterized SQL for both values.  
**Model name/version:** Unavailable.Category check: **SQL injection found.** No additional actionable findings were identified for error handling, authorization, thread safety/shared state, sensitive data in logs, or behavior changes hidden in refactors.

| # | Severity | File | Lines | Vulnerability | Confidence |
|---|----------|------|-------|---------------|------------|
| 1 | 🟠 HIGH | `backend/src/InvoiceApp.Api/Controllers/InvoicesController.cs` | 28, 32 | Query parameters `customer` and `status` are interpolated directly into SQL passed to `_queries.Run`, allowing SQL injection. Use parameterized queries. Model: Auto mode; concrete model/version unavailable. | 9/10 |

1. **Fix highest severity issues** — SQL injection is the only finding; reply with which issue to fix.
2. **Fix all issues** — implement a minimal fix for the reported vulnerability.
3. **Commit a summary of findings** — create `SECURITY-REVIEW.md` and commit it.

