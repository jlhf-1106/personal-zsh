# CLAUDE.md

The shared, tool-agnostic agent instructions for this project live in `AGENTS.md`.
Claude Code does not read `AGENTS.md` natively, so it is imported here:

@AGENTS.md

## Claude Code specifics
- Shared skills are exposed through `.claude/skills` (a symlink to `.agents/skills/`).
- Put personal, machine-local settings in `.claude/settings.local.json` (git-ignored); do not commit them.
