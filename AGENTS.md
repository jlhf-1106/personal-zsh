# Shared Agent Reference: personal-zsh

This file provides core context and guidelines for AI agents (Gemini, Claude, etc.) working on the `personal-zsh` project.

## Core Project Context
- **Purpose**: Portable, modular Zsh configuration for Linux, macOS, and WSL.
- **Base**: Oh My Zsh.
- **Prompt**: Fast, cross-shell [Starship](https://starship.rs) prompt using the **Gruvbox Rainbow** preset (`config/starship.toml` deployed to `~/.config/starship.toml`).
- **Package Managers & Tools**: 
    - **SDKMAN!** (`config/sdkman.zsh`): Java version management.
    - **FNM** (`config/fnm.zsh`): Fast Node Manager.
    - **Bun** (`config/bun.zsh`): JavaScript runtime and manager.
    - **Homebrew** (`config/brew.zsh`): Package manager for macOS and Linux.
    - **Git LFS** (`config/plugins/git-lfs.zsh`): Git Large File Storage configuration and aliases.
    - **Docker Compose** (`config/plugins/docker-compose.zsh`): `dc` alias; picks `docker-compose` or `docker compose` from `$commands` without running docker.

## Key Workflows

### Installation
- **Entry point**: `install.sh`.
- **Modular Logic**: The installer is organized into scripts in `scripts/install/`:
    - `common.sh`: Shared variables and logging.
    - `features.sh`: Interactive feature selection and preference loading. Use `add_brew_dep <formula>` when a feature needs a tool another feature may also add (e.g. AWS and FZF both need `fzf`).
    - `deps.sh`: Installation of Homebrew, OMZ, Starship, and custom plugins. OMZ is installed with `ZSH="$HOME/.oh-my-zsh" KEEP_ZSHRC=yes` so it never touches `.zshrc`.
- **Guards** (`install.sh`): exits if `ZDOTDIR` is set to anything but `$HOME`; skips `generate_zshrc` when `~/.oh-my-zsh/oh-my-zsh.sh` is missing.
    - `config.sh`: Deployment of Starship configuration, modular configs, and fonts. `generate_zshrc` always moves the old `~/.zshrc` (file or symlink) to `~/.zsh_config/backups/` first.
- **Preferences**: Persists preferences in `.zsh_plugins.env` (git-ignored, per machine; never commit it).

### PATH Migration
- **Script**: `scripts/migrate_path.sh` — moves explicit, single-line `PATH` definitions from `~/.zshrc` to `~/.zshenv`.
- **Manual only**: Run it by hand from the repo. It is not run at shell startup: moved lines lose variables defined earlier in `.zshrc` and lose PATH priority (macOS `path_helper` and `brew shellenv` run after `.zshenv`), so the user must review the dry run first.
- **Rationale**: `.zshenv` is loaded in every zsh session (interactive, non-interactive, cron, launchd, GUI apps), making it the correct place for `PATH`.
- **Dry-run by default**: Running without flags shows detected lines without modifying anything. Use `--apply` to execute.
- **Stateful parser**: Tracks `if`/`for`/`while`/`case` block depth and `{ }` brace depth to skip lines inside conditionals and functions.
- **Portability**: Uses `awk` (not `sed -i`) for line deletion to work on both macOS (BSD) and Linux (GNU).
- **Symlinks**: Rewrites `~/.zshrc` with `cat > file` (not `mv`) so a symlinked `.zshrc` stays a link.
- **Test harness**: `tests/migrate_path.bats` validates the script via Bats (41 tests covering dry-run, apply, exclusion rules, backups, idempotency, symlinked `.zshrc`, and edge cases).

### Modular Configuration
- **Structure**: The `config/` directory is organized into subdirectories:
    - **`config/core/`**: Essential system configurations (always installed).
    - **`config/plugins/`**: Functional modules.
- **Selective Deployment**: `install.sh` copies files to `~/.zsh_config/` **selectively** based on the enabled features in `.zsh_plugins.env`. A rerun replaces the `*.zsh` files but never deletes `~/.zsh_config/backups/`.
- **Docker**: on Linux the feature deploys the plugin/config but never brew-installs `docker` (CLI only, no daemon); a missing Docker Engine is flagged in the summary.
- **Dynamic Plugins**: `zshrc.template` contains a `_DYNAMIC_PLUGINS_` placeholder that is replaced during installation with the list of Oh My Zsh plugins corresponding to the selected features.
- **Rule**: Never modify `~/.zshrc` directly; add/edit files in `config/`.
- **Rule**: Each tool or logical set **MUST** have its own `.zsh` file, unless the OMZ plugin covers it completely (e.g. Azure, Angular, Extract use only their OMZ plugin).
- **Rule**: Do not add a `.zsh` file for something an enabled OMZ plugin already does (completion, aliases, functions). Never run slow commands (e.g. `ng completion script`, `docker ...`) at shell startup.

## Development Conventions

### Scripting
- Use Bash/Zsh compatible syntax.
- Use `[[ -s "file" ]]` for existence and size checks.
- For in-place edits in installer scripts use `sed_inplace <expr> <file>` (`common.sh`); never branch on OS for `sed -i`.

### Java (SDKMAN!)
- Use the `jv` helper function for version switching.
- Auto-installs Java 21 (`21-tem`) upon SDKMAN! installation.
- On macOS, `install_sdkman` calls `check_brew` first, then uses Homebrew's Bash 4+ for the SDKMAN! installer.
- Use `.sdkmanrc` for project-specific versions.

### Theming & Prompt
- Prompt is managed via **Starship** using the **Gruvbox Rainbow** preset (`config/starship.toml`).
- OMZ themes are disabled (`ZSH_THEME=""` in `zshrc.template`).
- Syntax highlighting styles and fzf init (`fzf --zsh`, apt-file fallback) are defined in `config/plugins/zsh-plugins.zsh`.
- Esc Esc (prepend/remove `sudo`) comes from the OMZ `sudo` plugin, always enabled in `common.sh`. Do not bind plain keys like space.

## Agent Guidelines (all tools)
- **Search first**: Look for the relevant modular file in `config/` before suggesting changes.
- **Source of truth**: `zshrc.template` is the source of truth for the linked `~/.zshrc`.
- **Verification**: Check shell syntax with `zsh -n <file>` (or `bash -n` for `.sh` scripts) and run the Bats suite with `pnpm test`. CI (`.github/workflows/test.yml`) runs the same syntax checks and the full suite on Ubuntu, macOS and WSL, Node 22, for every PR.
- **Snippets**: Be mindful of the modular nature of the config when providing code snippets.
- **Paths**: Use absolute paths or paths relative to the project root when suggesting commands.

## AI Agent Configuration

`AGENTS.md` (this file, at the repository root) is the **single source of truth** for agent instructions. Tool-specific files only point back to it; never duplicate content into them.

| Path | Purpose | Used by |
| --- | --- | --- |
| `AGENTS.md` | Shared project instructions | Codex, Antigravity, Cursor, GitHub Copilot, Windsurf, Zed, Jules, Amp, Aider, etc. |
| `CLAUDE.md` | Imports `AGENTS.md` via `@AGENTS.md` (+ Claude-only notes) | Claude Code |
| `.gemini/settings.json` | Sets `context.fileName` to `AGENTS.md` | Gemini CLI |
| `.agents/skills/<name>/SKILL.md` | Shared [Agent Skills](https://agentskills.io) | Antigravity, Codex, Gemini CLI, Cursor, Copilot |
| `.claude/skills` | Symlink to `../.agents/skills` | Claude Code |
| `.agents/rules/`, `.agents/workflows/` | Optional Antigravity-only rules/workflows (create only if needed) | Antigravity |
| `skills-lock.json` | Lockfile for skills installed with the `skills` CLI | `npx skills` |
| `package.json` → `@caveman-ai/cli` | Dev-only Caveman CLI: `pnpm caveman <agent>` wraps an agent with local context compression (Node 22.13+) | Claude Code, Codex, Gemini CLI, Aider, OpenCode, … |

- **Installed skills**: `caveman`, `ponytail` (+ `ponytail-audit`, `ponytail-debt`, `ponytail-gain`, `ponytail-help`, `ponytail-review`).
- **Installing third-party skills**: `npx skills add <owner/repo> --skill '*' --agent antigravity` writes to `.agents/skills/` and records the source in `skills-lock.json`; update with `npx skills update -p`.
- **Scope**: Ponytail, caveman and the Caveman CLI are tooling for *developing this repo*. They are not installer features: never add them to `install.sh`, `scripts/install/` or `config/`.
- **Adding a skill**: Create `.agents/skills/<name>/SKILL.md` (YAML frontmatter with `name` and `description`). It becomes available to every tool above automatically.
- **Do not add** a `GEMINI.md`: Antigravity reads both `GEMINI.md` and `AGENTS.md`, so it would load duplicated context.
- **Local settings** (`.claude/settings.local.json`, `CLAUDE.local.md`, `.gemini/.env`) are git-ignored.

## Agent Mandates

### Documentation Maintenance
- **Mandatory Update**: Every time an agent makes a functional or structural change to the project, they **MUST** immediately update:
    - `README.md`: To ensure user-facing documentation is current.
    - `AGENTS.md`: To ensure shared context for other agents remains accurate.
- **Consistency**: Ensure that technical details (aliases, paths, features) are synchronized across all documentation files.

## Maintenance
- **Reload**: `reload` alias.
- **Edit**: `zshconfig` alias.
