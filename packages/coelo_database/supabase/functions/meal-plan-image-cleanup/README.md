# Meal-plan image cleanup worker

Removes private Supabase Storage objects only after a server-side cleanup claim.
The SQL lifecycle keeps a tombstone until Storage deletion is confirmed.

Required configuration:

- Edge secret `COELO_MEAL_PLAN_CLEANUP_SECRET`.
- Invoke with `POST` and `x-coelo-worker-secret`.
- Deploy with JWT verification enabled; the worker additionally validates its secret.

Consolidator `config.toml` block:

```toml
[functions.meal-plan-image-cleanup]
verify_jwt = true
```

The function uses `SUPABASE_SERVICE_ROLE_KEY` only in the hosted Edge runtime.
It must never be exposed to Flutter.
