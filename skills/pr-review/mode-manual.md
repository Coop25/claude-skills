# Manual mode

Preflight, review, verify. Then show: a numbered list (severity, `file:line`, comment text), the draft review body (verification, CI, coverage, steering text), disputed and dropped findings, and the proposed verdict.

1. Ask which comments to post (all / some / none / edit). Right after the yes, re-check `headRefOid` (it can be minutes later; common.md "Stale head"), then post the approved ones as one review.
2. Ask the verdict (`APPROVE` / `REQUEST_CHANGES` / `COMMENT`) as a **separate** question afterwards, never both in one answer. Skip it on an own PR (always `COMMENT`, intended verdict in the body). If the operator dropped the comment that defines the verdict, say so and offer `COMMENT`.
3. No watcher unless asked.
