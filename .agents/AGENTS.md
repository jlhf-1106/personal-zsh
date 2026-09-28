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

## Key Workflows

### Installation
- **Entry point**: `install.sh`.
- **Modular Logic**: The installer is organized into scripts in `scripts/install/`:
    - `common.sh`: Shared variables and logging.
    - `features.sh`: Interactive feature selection and preference loading.
    - `deps.sh`: Installation of Homebrew, OMZ, Starship, and custom plugins.
    - `config.sh`: Deployment of Starship configuration, modular configs, and fonts.
- **Preferences**: Persists preferences in `.zsh_plugins.env`.

### PATH Migration
- **Script**: `scripts/migrate_path.sh` — moves explicit, single-line `PATH` definitions from `~/.zshrc` to `~/.zshenv`.
- **Automatic Execution**: Sourced automatically on shell startup via `config/core/path_migrate.zsh`. If new `PATH` definitions are added to `~/.zshrc`, reloading `~/.zshrc` auto-migrates them quietly and re-sources `~/.zshenv`.
- **Rationale**: `.zshenv` is loaded in every zsh session (interactive, non-interactive, cron, launchd, GUI apps), making it the correct place for `PATH`.
- **Dry-run by default**: Running without flags shows detected lines without modifying anything. Use `--apply` to execute.
- **Stateful parser**: Tracks `if`/`for`/`while`/`case` block depth and `{ }` brace depth to skip lines inside conditionals and functions.
- **Portability**: Uses `awk` (not `sed -i`) for line deletion to work on both macOS (BSD) and Linux (GNU).
- **Test harness**: `tests/migrate_path.bats` validates the script via Bats (39 tests covering dry-run, apply, exclusion rules, backups, idempotency, and edge cases).

### Modular Configuration
- **Structure**: The `config/` directory is organized into subdirectories:
    - **`config/core/`**: Essential system configurations (always installed).
    - **`config/plugins/`**: Functional modules.
- **Selective Deployment**: `install.sh` copies files to `~/.zsh_config/` **selectively** based on the enabled features in `.zsh_plugins.env`.
- **Dynamic Plugins**: `zshrc.template` contains a `_DYNAMIC_PLUGINS_` placeholder that is replaced during installation with the list of Oh My Zsh plugins corresponding to the selected features.
- **Rule**: Never modify `~/.zshrc` directly; add/edit files in `config/`.
- **Rule**: Each tool or logical set **MUST** have its own `.zsh` file.

## Development Conventions

### Scripting
- Use Bash/Zsh compatible syntax.
- Use `[[ -s "file" ]]` for existence and size checks.

### Java (SDKMAN!)
- Use the `jv` helper function for version switching.
- Auto-installs Java 21 (`21-tem`) upon SDKMAN! installation.
- Use `.sdkmanrc` for project-specific versions.

### Theming & Prompt
- Prompt is managed via **Starship** using the **Gruvbox Rainbow** preset (`config/starship.toml`).
- OMZ themes are disabled (`ZSH_THEME=""` in `zshrc.template`).
- Syntax highlighting styles are defined in `config/plugins/zsh-plugins.zsh`.

## Tool-Specific Guidance

All agent configuration lives under `.agents/`. Shared skills are in `.agents/skills/`.

### Gemini
- **Tooling**: Prioritize the use of `grep_search` to find modular configurations in `config/` before suggesting changes.
- **Verification**: When testing shell script changes, use `run_shell_command` with `zsh -n <file>` to check for syntax errors.
- **Context**: Remember that `zshrc.template` is the source of truth for the linked `~/.zshrc`.

### Claude
- **Environment**: Be mindful of the modular nature of the config when providing code snippets.
- **Paths**: Always use absolute paths or relative paths based on the project root when suggesting commands.

## Agent Mandates

### Documentation Maintenance
- **Mandatory Update**: Every time an agent makes a functional or structural change to the project, they **MUST** immediately update:
    - `README.md`: To ensure user-facing documentation is current.
    - `.agents/AGENTS.md`: To ensure shared context for other agents remains accurate.
- **Consistency**: Ensure that technical details (aliases, paths, features) are synchronized across all documentation files.

## Maintenance
- **Reload**: `reload` alias.
- **Edit**: `zshconfig` alias.
