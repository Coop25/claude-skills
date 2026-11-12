#!/usr/bin/env bash
# Watch a PR and print one "EVENT ..." line per change. Silent otherwise (no tokens while idle).
# usage: bash watch-pr.sh <owner/repo> <pr> [interval=60] [--state FILE] [--max SECONDS]
#   (default)    run until the PR closes; use under a Monitor in a main session.
#   --state F    keep head SHA and seen comment ids in F, so a restart loses no events.
#   --max S      one-shot: exit after S seconds, or right after the first batch of events.
#                Use this in a foreground Bash call (<= 540) where nothing can wake you (subagents),
#                and call it again with the same --state after handling each batch.
# Events:
#   EVENT head <sha>                                    new commits pushed
#   EVENT comment <id> <login> reply_to=<id|0> <kind>   new human comment (kind: review|issue)
#   EVENT state <CLOSED|MERGED>                         PR closed; exits 0
#   EVENT idle                                          --max elapsed with nothing new
#   EVENT error <msg>                                   gave up after repeated failures; exits 1
# Ignored: bots, and any comment containing the marker <!-- pr-review --> (our own posts).
set -u
repo="${1:?owner/repo}"; n="${2:?pr number}"; shift 2
iv=60; state_file=""; max=0
[ $# -gt 0 ] && case "$1" in --*) ;; *) iv="$1"; shift;; esac
while [ $# -gt 0 ]; do
  case "$1" in
    --state) state_file="${2:?file}"; shift 2;;
    --max) max="${2:?seconds}"; shift 2;;
    *) echo "EVENT error unknown arg $1"; exit 1;;
  esac
done
marker='<!-- pr-review -->'

snap_comments() {
  gh api "repos/$repo/pulls/$n/comments?per_page=100" --jq \
    ".[] | select(.user.type != \"Bot\") | select((.body|contains(\"$marker\"))|not) | \"review \(.id) \(.user.login) \(.in_reply_to_id // 0)\"" || return 1
  gh api "repos/$repo/issues/$n/comments?per_page=100" --jq \
    ".[] | select(.user.type != \"Bot\") | select((.body|contains(\"$marker\"))|not) | \"issue \(.id) \(.user.login) 0\"" || return 1
}
save_state() {
  [ -n "$state_file" ] && { printf '%s\n' "$head" > "$state_file"; printf '%s\n' "$seen" >> "$state_file"; }
}

if [ -n "$state_file" ] && [ -s "$state_file" ]; then
  head=$(head -n1 "$state_file"); seen=$(tail -n +2 "$state_file")
else
  head=$(gh pr view "$n" -R "$repo" --json headRefOid --jq .headRefOid) || { echo "EVENT error cannot read PR"; exit 1; }
  seen=$(snap_comments) || { echo "EVENT error cannot read comments"; exit 1; }
  save_state
fi

fails=0; started=$SECONDS
while true; do
  sleep "$iv"
  info=$(gh pr view "$n" -R "$repo" --json headRefOid,state --jq '"\(.headRefOid) \(.state)"') \
    && cur=$(snap_comments) || {
      fails=$((fails+1))
      [ "$fails" -ge 5 ] && { echo "EVENT error 5 consecutive gh failures (auth, rate limit or network)"; exit 1; }
      sleep "$iv"; continue; }
  fails=0; emitted=0
  new_head=${info% *}; state=${info#* }
  if [ "$new_head" != "$head" ]; then echo "EVENT head $new_head"; head=$new_head; emitted=1; fi
  while IFS= read -r line; do
    [ -z "$line" ] && continue
    if ! printf '%s\n' "$seen" | grep -qxF "$line"; then
      kind=${line%% *}; rest=${line#* }; id=${rest%% *}; rest=${rest#* }; login=${rest%% *}; rep=${rest#* }
      echo "EVENT comment $id $login reply_to=$rep $kind"; emitted=1
    fi
  done <<< "$cur"
  seen=$cur; save_state
  if [ "$state" != "OPEN" ]; then echo "EVENT state $state"; exit 0; fi
  [ "$max" -gt 0 ] && [ "$emitted" = 1 ] && exit 0
  if [ "$max" -gt 0 ] && [ $((SECONDS-started)) -ge "$max" ]; then echo "EVENT idle"; exit 0; fi
done
