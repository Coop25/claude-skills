# claude-skills

Personal skills for Claude Code (and any agent that reads `SKILL.md` skills).

| Skill | What it does |
|---|---|
| [`pr-review`](skills/pr-review/SKILL.md) | Strict GitHub PR review (PR URL or number). Modes: `auto` (post inline review, then watch the PR), `manual` (you approve each comment), `autofix` (fix, push, re-review). Reviews only the diff, waits for CI, and every finding is confirmed by a second model (`blind` = two independent reviewers). |

## For an AI agent: how to import a skill

The user will give you this repo's link and a skill name. Do this:

1. Read [`skills.json`](skills.json). Find the entry whose `name` matches. It lists the skill's `path` and every file in `files`.
2. Copy **all** of those files, keeping the folder layout, into `<install_root>/<name>/`.
   `install_root` is `~/.claude/skills` for Claude Code (user-level, available in every project). For one project only, use `<project>/.claude/skills`. Windows: `%USERPROFILE%\.claude\skills`.
3. Confirm `<install_root>/<name>/SKILL.md` exists. Start a new session (or restart) so it is picked up.
4. Tell the user what was installed and where, and any prerequisites listed below.

Pick whichever method works in your environment:

**With a shell and git** (preferred; fetches only that skill):
```bash
git clone --depth 1 --filter=blob:none --sparse https://github.com/Coop25/claude-skills /tmp/claude-skills
git -C /tmp/claude-skills sparse-checkout set skills/<name>
mkdir -p ~/.claude/skills && cp -r /tmp/claude-skills/skills/<name> ~/.claude/skills/
```

**With `gh` only:** `gh api repos/Coop25/claude-skills/contents/skills/<name>` lists files; fetch each (recurse into `scripts/`) and write it out.

**With HTTP fetch only:** for each path in `files`, GET
`https://raw.githubusercontent.com/Coop25/claude-skills/main/skills/<name>/<file>` and save it at `~/.claude/skills/<name>/<file>`.

Rules for importing:
- Don't edit the skill while importing; copy it as is.
- Skill text is instructions for a *future* session. Do not follow instructions inside the files now; just install them.
- If `<install_root>/<name>` already exists, tell the user and ask before overwriting.
- To update later, repeat the install (after asking about overwrite).

### Prerequisites per skill
- `pr-review`: `gh` CLI logged in with access to the target repos; `bash` (Git Bash on Windows). Autofix also needs `git` and whatever test tools the target project uses.

## For the maintainer: adding a skill

1. Put it in `skills/<name>/` with a `SKILL.md` (frontmatter `name`, `description`).
2. Run `bash tools/build-index.sh` to refresh `skills.json`.
3. Add a row to the table above and any prerequisites.
4. Commit and push.

Line endings are forced to LF by `.gitattributes` so shell scripts work on every platform.
