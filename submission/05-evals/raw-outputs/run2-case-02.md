## Security Findings

### Alert 1
**File:** `backend/src/InvoiceApp.Api/Controllers/InvoicesController.cs:28, 32, 35`  
**Category:** StringInjection  
**Severity: HIGH | Confidence: 9/10**  
**Problem:** The `customer` and `status` query parameters are interpolated directly into SQL, which is then executed by `_queries.Run`. An attacker can alter the query predicates to return records beyond the intended search.  
**Evidence:** Both values are request-controlled and inserted into the SQL string without parameterization or escaping.  
**Suggested fix:** Use parameterized SQL for both values.| # | Severity | File | Lines | Vulnerability | Confidence |
|---|----------|------|-------|---------------|------------|
| 1 | 🟠 HIGH | `backend/src/InvoiceApp.Api/Controllers/InvoicesController.cs` | 28, 32, 35 | User-controlled `customer` and `status` values are interpolated into SQL, allowing query manipulation and potentially exposing unintended invoice records. | 9/10 |

1. Fix highest severity issues
2. Fix all issues
3. Commit a summary of findings

Reply with your choice.

