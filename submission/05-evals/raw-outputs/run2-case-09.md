| File | Line | Finding | Confidence |
|---|---:|---|---:|
| `README.md` | 25 | Signing out and back in does not reset invoices: invoice data is held in the singleton in-memory repository, while logout only removes the user session. The reset instruction is misleading. | 10/10 |

