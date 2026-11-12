#!/usr/bin/env bash
# Regenerate skills.json from skills/*/SKILL.md. Run after adding or changing a skill:
#   bash tools/build-index.sh
set -eu
cd "$(dirname "$0")/.."

# Escape backslashes and double quotes for JSON strings.
esc() {
  local v="$1" bs='\' q='"'
  v="${v//$bs/$bs$bs}"
  v="${v//$q/$bs$q}"
  printf '%s' "$v"
}

out="skills.json"
printf '{\n  "repo": "Coop25/claude-skills",\n  "install_root": "~/.claude/skills",\n  "skills": [\n' > "$out"
first=1
for d in skills/*/; do
  name=$(basename "$d"); f="${d}SKILL.md"
  [ -f "$f" ] || continue
  desc=$(sed -n 's/^description: *//p' "$f" | head -1 | tr -d '\r')
  files=$(cd "$d" && find . -type f | sed 's|^\./||' | LC_ALL=C sort | awk '{printf "%s\"%s\"", (NR>1?", ":""), $0}')
  [ "$first" = 1 ] || printf ',\n' >> "$out"
  first=0
  printf '    {"name": "%s", "description": "%s", "path": "skills/%s", "files": [%s]}' \
    "$(esc "$name")" "$(esc "$desc")" "$name" "$files" >> "$out"
done
printf '\n  ]\n}\n' >> "$out"
echo "wrote $out"
