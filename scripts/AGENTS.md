# scripts/: agent notes

Loaded only when working under `scripts/`. Shared rules live in the root `AGENTS.md`.

## PATH Migration (`migrate_path.sh`)
- **Script**: `scripts/migrate_path.sh` — moves explicit, single-line `PATH` definitions from `~/.zshrc` to `~/.zshenv`.
- **Rationale**: `.zshenv` is loaded in every zsh session (interactive, non-interactive, cron, launchd, GUI apps), making it the correct place for `PATH`.
- **Dry-run by default**: Running without flags shows detected lines without modifying anything. Use `--apply` to execute.
- **Stateful parser**: Tracks `if`/`for`/`while`/`case` block depth and `{ }` brace depth to skip lines inside conditionals and functions.
- **Portability**: Uses `awk` (not `sed -i`) for line deletion to work on both macOS (BSD) and Linux (GNU).
- **Symlinks**: Rewrites `~/.zshrc` with `cat > file` (not `mv`) so a symlinked `.zshrc` stays a link.
- **Tests**: `tests/migrate_path.bats`.
