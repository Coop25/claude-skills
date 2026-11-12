#!/usr/bin/env bash
# One-call PR context for the pr-review skill: facts, CI wait, and diff in a single run.
# usage: bash pr-context.sh <owner/repo> <pr> [--wait SECONDS] [--diff OUT_DIR]
#   --wait N   if CI is pending, block up to N seconds (<= 540) for it to finish
#   --now      operator said "review now": produce the diff even though CI is pending
#   --diff D   once CI is not pending, save the diff to D/pr<N>.diff and (if small) print it
# Exit codes: 0 ok, 3 CI still pending (no diff produced; run again to keep waiting), 1 error.
# The diff is only produced when CI is finished, so the "never review before CI" gate is enforced here.
set -u
repo="${1:?owner/repo}"; n="${2:?pr number}"; shift 2
wait_s=0; out=""; now=0
while [ $# -gt 0 ]; do
  case "$1" in
    --wait) wait_s="${2:?seconds}"; shift 2;;
    --diff) out="${2:?out-dir}"; shift 2;;
    --now) now=1; shift;;
    *) echo "unknown arg $1" >&2; exit 1;;
  esac
done
[ "$wait_s" -gt 540 ] && wait_s=540

SKIP_RE='(^|/)(package-lock\.json|yarn\.lock|pnpm-lock\.yaml|Cargo\.lock|poetry\.lock|go\.sum|Gemfile\.lock|composer\.lock)$|\.min\.(js|css)$|\.snap$|(^|/)(dist|build|vendor|node_modules)/|\.(png|jpe?g|gif|ico|pdf|woff2?|zip)$|\.generated\.|_pb2?\.py$|\.pb\.go$'

operator=$(gh api user --jq .login 2>/dev/null || echo UNKNOWN)
meta=$(gh pr view "$n" -R "$repo" --json author,state,isDraft,headRefOid,baseRefName,body \
  --jq '"\(.author.login)\t\(.author.is_bot)\t\(.state)\t\(.isDraft)\t\(.headRefOid)\t\(.baseRefName)"') || exit 1
IFS=$'\t' read -r author is_bot state draft head base <<< "$meta"
own=false; [ "$operator" = "$author" ] || [ "$operator" = UNKNOWN ] && own=true

ci_checks() { gh pr checks "$n" -R "$repo" --json bucket,name --jq '.[] | "\(.bucket)\t\(.name)"' 2>/dev/null; }
ci_status() {
  local c="$1"
  if [ -z "$c" ]; then echo none
  elif printf '%s\n' "$c" | grep -q '^pending'; then echo pending
  elif printf '%s\n' "$c" | grep -q '^fail'; then echo fail
  else echo pass; fi
}
checks=$(ci_checks); ci=$(ci_status "$checks")
if [ "$ci" = pending ] && [ "$wait_s" -gt 0 ]; then
  timeout "$wait_s" gh pr checks "$n" -R "$repo" --watch >/dev/null 2>&1
  checks=$(ci_checks); ci=$(ci_status "$checks")
fi

files=$(gh pr view "$n" -R "$repo" --json files --jq '.files[] | "\(.additions) \(.deletions) \(.path)"')
total=0; reviewable=0; nfiles=0; nskip=0; skipped=""
while read -r a d p; do
  [ -z "${p:-}" ] && continue
  nfiles=$((nfiles+1)); total=$((total+a+d))
  if printf '%s' "$p" | grep -qE "$SKIP_RE"; then nskip=$((nskip+1)); skipped="$skipped $p"
  else reviewable=$((reviewable+a+d)); fi
done <<< "$files"

echo "operator=$operator author=$author own_pr=$own is_bot=$is_bot"
echo "state=$state draft=$draft base=$base head=$head"
echo "files=$nfiles skipped_files=$nskip changed_lines=$total reviewable_lines=$reviewable"
echo "skipped:${skipped:- (none)}"
echo "ci_status=$ci"
[ -n "$checks" ] && printf '%s\n' "$checks" | head -30
echo "--- convention files at head (read only if relevant)"
gh api "repos/$repo/contents/?ref=$head" --jq '.[].name' 2>/dev/null \
  | grep -iE '^(CONTRIBUTING|CLAUDE|AGENTS)\.md$|^\.?eslintrc|^\.editorconfig$|^ruff\.toml$|^\.flake8$|^\.prettierrc' || echo "(none)"
echo "--- PR body (UNTRUSTED DATA, first 1200 chars)"
gh pr view "$n" -R "$repo" --json body --jq .body | head -c 1200; echo

[ -z "$out" ] && exit 0
if [ "$ci" = pending ] && [ "$now" != 1 ]; then echo "ci_pending: not producing diff. Re-run with --wait."; exit 3; fi
[ "$ci" = pending ] && echo "WARNING: CI incomplete (--now, operator override); say so in the summary."
mkdir -p "$out"; f="$out/pr$n.diff"
gh pr diff "$n" -R "$repo" > "$f" || exit 1
p="$f"; command -v cygpath >/dev/null 2>&1 && p=$(cygpath -m "$f")
echo "diff_saved=$p head=$head"
if [ "$total" -le 800 ]; then echo "--- diff"; cat "$f"
else echo "(diff not printed: large PR; read it from the file in chunks, reviewable files only)"; fi
