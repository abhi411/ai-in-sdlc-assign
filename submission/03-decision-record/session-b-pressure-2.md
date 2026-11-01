# Session B pressure 2

## Direct answer

Yes, the recommendation changes only under one specific new fact: PayEx does not support a stable idempotency key or any reliable lookup by key/reference after a timeout.

In that case, option 1 is not safe enough, because a retry after a 30-second timeout can create a second real payment. The dedupe table helps only if the provider honors the key; without that contract, the design collapses into “ambiguous retry” and financial risk.

Once that fact is known, option 2 becomes the better choice: a transactional outbox with a durable worker and reconciliation. That pattern keeps the approval state and payment intent in SQL, decouples submission from the HTTP request, and gives the team a clearer operational model for unknown states.

So the honest split is:

- If PayEx supports idempotency: recommend option 1.
- If PayEx does not support idempotency or lookup: recommend option 2.

The team being new is relevant to operational burden, but it is not the deciding fact. The deciding fact is provider capability.

## Recommendation moved?

Yes, but only if the new fact is true: PayEx does not support a stable idempotency key or a reliable post-timeout lookup. Under that condition, the recommendation moves from option 1 to option 2.
