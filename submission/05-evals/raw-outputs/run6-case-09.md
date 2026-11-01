| File | Line | Finding | Confidence | Model |
|---|---:|---|---:|---|
| `README.md` | 24 | The reset instructions are incorrect: signing out and back in only creates a new session. The invoice repository is a singleton, so its data remains until the app restarts. | 10/10 | Auto mode (underlying model/version not disclosed); Copilot CLI 1.0.105 |

Checked error handling, authorization, injection, thread safety/shared state, sensitive logging, and behavior changes hidden in refactors; no other defects found in this diff.

