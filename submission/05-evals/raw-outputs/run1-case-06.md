| File | Line | What goes wrong | Confidence |
|---|---:|---|---:|
| `backend/tests/InvoiceApp.Tests/ApprovalServiceTests.cs` | 62, 72 | Both new tests call `repository.Add(Pending(...))`, but the test project has no `Pending` helper and `FakeInvoiceRepository` has no `Add` method. The tests will not compile. | 10/10 |

