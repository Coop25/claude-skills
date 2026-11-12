# Common: posting, stale heads, failures

## Stale head
Before any write, re-fetch `headRefOid`. If it moved since the diff you reviewed: `gh api repos/{o}/{r}/compare/<reviewedSha>...<head>`, drop findings whose lines changed or vanished, review the delta, re-run the CI gate, re-verify anything new, post against the new head.

## Posting a review
`gh api repos/{owner}/{repo}/pulls/{n}/reviews --input review.json`:
```json
{
  "commit_id": "<headRefOid>",
  "event": "REQUEST_CHANGES",
  "body": "Summary: 2 blockers, 1 major. Verified by a second model. CI: green. Coverage: 4 of 4 files.\n\n<!-- pr-review -->",
  "comments": [
    {"path": "src/db.ts", "line": 42, "side": "RIGHT",
     "body": "**blocker**: `rows[0]` is read before the empty check, so an empty result throws. Move the guard above line 42.\n\n<!-- pr-review -->"}
  ]
}
```
- **Every** comment, reply, and body the skill posts ends with `<!-- pr-review -->`. It's invisible to readers and lets the watcher ignore your own posts (they're posted under the operator's login).
- `event` per verification.md. Own PR: `COMMENT`, intended verdict in the body.
- The body always states: verification status (model used), CI status, coverage, any steering text found, any disputed or dropped findings.
- Multi-line: `start_line`/`start_side`. Line numbers are new-file lines: for hunk `@@ -a,b +c,d @@` the first line after it is `c`; count context and `+` lines, skip `-`.
- Reply on a thread: `gh api repos/{o}/{r}/pulls/{n}/comments/<comment-id>/replies -f body="...\n\n<!-- pr-review -->"` (use the thread's first comment id). Top-level comment: `gh pr comment <n> -R <repo> --body-file f`.
- A 422 on a comment (line not in diff): move that text into the body as `file:line`, never drop it.

## Failures
| Situation | Do |
|---|---|
| 401 / bad credentials / missing scope | Stop. Tell the operator. Don't retry. |
| 403/429 rate limit | `gh api rate_limit`; wait for reset. Over 10 min: tell the operator. |
| Network error | Retry 3 times with backoff, then report. |
| PR closed or merged | Stop. Final summary. |
| `lastReviewedSha` gone (force-push; compare 404) | Re-fetch the full diff, review it fully, skip findings that duplicate open threads, leave GitHub-outdated threads alone. |
| Base branch changed | Re-fetch diff, rerun preflight. |
