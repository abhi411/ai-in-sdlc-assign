| File | Line | What goes wrong | Confidence |
|---|---:|---|---:|
| `README.md` | 23 | Signing out and back in does not reset sample data: the invoice repository is a singleton that persists for the life of the process. The instruction may lead users to expect their changes to be cleared when they are not. | 10/10 |

