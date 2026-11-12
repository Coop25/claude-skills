# Review Checklist (apply to changed hunks only)

1. **Correctness**: off-by-one, null/undefined, wrong operator, inverted condition, unhandled branch, wrong type or unit, time zones, integer overflow, float equality, mutation of shared state.
2. **Error handling**: swallowed errors, missing cleanup/rollback, partial failure leaving bad state, retries without idempotency, misleading messages.
3. **Concurrency**: races, check-then-act, missing locks/awaits, deadlock, non-atomic read-modify-write, unbounded parallelism.
4. **Security**: injection (SQL/shell/HTML/path), authn/authz gaps, secrets in code or logs, SSRF, unsafe deserialization, missing input validation at trust boundaries, weak crypto.
5. **Contracts and compatibility**: public API/schema/CLI changes, breaking callers of a changed symbol, migrations that lock or can't roll back, config/env changes without defaults.
6. **Tests** (major only on data-loss/security/money paths, otherwise minor): new behavior untested, tests that can't fail, assertions on mocks only, deleted or skipped tests, missing edge and failure cases.
7. **Performance**: N+1 queries, work in hot loops, unbounded memory/result sets, missing indexes for new queries.
8. **Resources**: leaked handles/connections/listeners, missing timeouts, unbounded caches.
9. **Maintainability**: dead code introduced, duplicated logic that already exists, misleading names, comments that contradict code, needless complexity.
10. **PR hygiene**: unrelated changes mixed in, debug leftovers, generated or lock files changed without reason, large PR that should be split.

Only report items you can tie to a specific changed line and a concrete failure scenario.
