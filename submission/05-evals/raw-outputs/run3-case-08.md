| File | Line | Defect | Confidence |
|---|---:|---|---:|
| `backend/src/InvoiceApp.Api/InMemoryInvoiceRepository.cs` | 10 | Replacing `ConcurrentDictionary` with `Dictionary` removes thread safety. The repository is registered as a singleton, so concurrent requests can read and write it simultaneously, potentially causing exceptions or inconsistent state. | 10/10 |
| `backend/src/InvoiceApp.Api/InMemoryInvoiceRepository.cs` | 18–24 | The separate `ContainsKey` check and assignment are not atomic. Concurrent adds with the same ID can both pass the check, allowing one invoice to overwrite the other instead of reporting a duplicate. | 10/10 |

