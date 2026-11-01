| File | Line | Finding | Confidence |
|---|---:|---|---:|
| `backend/tests/InvoiceApp.Tests/ApprovalServiceTests.cs` | 62, 72 | Both new tests call `Pending(...)`, but `ApprovalServiceTests` does not define that helper. The test project will fail to compile with an unresolved name. | 10/10 |

