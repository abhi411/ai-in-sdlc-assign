I’ll verify the sign-out/sign-in reset claim against the in-memory data lifecycle and inspect the configuration context for behavioral issues.

- **README.md:24** — “To reset the sample data without restarting, sign out and sign in again” is incorrect. Sign-out only removes the user session; the invoice repository is a singleton seeded at application startup, so the data remains unchanged. **Confidence: 10/10**.

