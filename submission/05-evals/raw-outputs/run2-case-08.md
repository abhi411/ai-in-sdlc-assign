| File | Line | What goes wrong | Confidence |
|---|---:|---|---:|
| `backend/src/InvoiceApp.Api/InMemoryInvoiceRepository.cs` | 9 | Replacing `ConcurrentDictionary` with an unsynchronized `Dictionary` makes concurrent repository access unsafe. The repository is registered as a singleton, so simultaneous API requests can race during reads and writes, causing exceptions or inconsistent state. | 10/10 |
| `backend/src/InvoiceApp.Api/InMemoryInvoiceRepository.cs` | 19 | `ContainsKey` followed by assignment is not atomic. Concurrent `Add` calls with the same ID can both pass the check, so one silently overwrites the other instead of throwing the duplicate-ID exception. | 10/10 |

