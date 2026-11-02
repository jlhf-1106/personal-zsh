# Personal Zsh Configuration

This repository contains a portable, modular Zsh configuration based on **Oh My Zsh** and the fast, cross-shell **Starship** prompt with the **Gruvbox Rainbow** preset.

## Features
- **Granular Installation**: Choose exactly which tools and plugins to install (Git, Git LFS, GitHub CLI, Node, pnpm, Bun, Docker, AWS, Azure, Angular, Go, Maven, etc.) independently via an interactive menu.
- **Enhanced Terminal Experience**: Includes pre-configured support for **Zsh Autosuggestions**, **Syntax Highlighting**, and **Fzf** (Fuzzy Finder). Fzf key bindings (Ctrl-R history, Ctrl-T files, Alt-C dirs) load via `fzf --zsh` on macOS and Linux, with a fallback for older apt packages. Press **Esc Esc** to add or remove `sudo` at the start of the command (Oh My Zsh `sudo` plugin).
- **Homebrew Integration**: Automatically installs missing CLI tools using Homebrew for a seamless setup.
- **Modular Structure**: Configuration is split into specialized subdirectories. Only the configurations for selected features are deployed.
- **Dynamic Plugin Management**: Automatically generates the Oh My Zsh plugin list based on your preferences.
- **Starship Prompt**: Fast, asynchronous [Starship](https://starship.rs) prompt featuring the powerline-style **Gruvbox Rainbow** preset with contextual segments for OS, directory, Git status, language runtimes, containers, and timestamps.
- **Java Management**: Integrated [SDKMAN!](https://sdkman.io/) with automatic version switching.
- **Angular CLI**: Tab completion comes from the Oh My Zsh `ng` plugin, which only calls `ng` when you press Tab (no startup cost).
- **Utility Tools**: Includes handy utilities like **Extract** (the Oh My Zsh `extract` plugin: one command for `.zip`, `.tar.*`, `.xz`, `.zst`, `.7z`, `.rar`, `.deb` and more) and **Warp Directory (wd)** for quick navigation.

## Mandatory Dependencies

Some features pull in another tool automatically:

- **AWS CLI**: Also installs `fzf`, used by the `awsp` profile picker.
- **Angular CLI**: Installed globally with `pnpm`. If pnpm is not selected or installed, the installer adds it.
- **Docker**: When Docker is selected (or already installed), the installer also offers `Docker Compose`.

## Java & SDKMAN!

This configuration includes a dedicated module for managing Java versions via SDKMAN!.

### Features:
- **Auto-Install**: The `install.sh` script automatically installs SDKMAN! and Java 21 (Temurin) if not present.
- **Auto-Env**: Configured by default to switch Java versions automatically when entering a directory with a `.sdkmanrc` file.
- **Helper Function**: Use `jv` as a shortcut for Java version management.

### Usage:
- `jv`: Displays the current Java version.
- `jv <version>`: Switches to a specific Java version (e.g., `jv 17-tem`).
- `sdk env init`: Creates a `.sdkmanrc` file in the current directory to lock the Java version for a project.

## Installation

1. Clone this repository to your preferred location:
   ```bash
   git clone https://github.com/your-username/personal-zsh.git ~/personal-zsh
   ```

2. Run the installation script:
   ```bash
   cd ~/personal-zsh
   # Grant execution permissions to the installer and its modules
   chmod +x install.sh scripts/install/*.sh
   ./install.sh
   ```
   Your existing `~/.zshrc` (a regular file or a symlink) is moved to `~/.zsh_config/backups/` before the new one is written. Re-running the installer never deletes earlier backups. If Oh My Zsh fails to install, your current `~/.zshrc` is kept as is.

   *Note: The installer manages `~/.zshrc` only. If you set `ZDOTDIR` to another folder, it stops and asks you to unset it.*

   *Note: The script may prompt for your password to install Homebrew or system dependencies via `sudo`.*

   **macOS users**: The installer automatically handles these macOS-specific requirements:
   - Installs **Homebrew** (if missing) and **Homebrew's Bash 4+** (needed by SDKMAN!, since macOS ships with Bash 3.2).
   - Installs **Node.js LTS** via fnm (if fnm is selected and no Node version is active).
   - Deploys **macOS-specific configurations** (Finder integration, Quick Look, etc.).

3. Restart your terminal or run:
   ```bash
   source ~/.zshrc
   ```

## Configuration Preferences

Your selected features are stored in `.zsh_plugins.env`, created on the first run. It is git-ignored, so each machine keeps its own answers and a fresh clone always asks. You can manually edit this file to enable or disable features and then re-run `./install.sh`.

Example `.zsh_plugins.env`:
```bash
ENABLE_GH=true
ENABLE_GIT_LFS=true
ENABLE_FNM=true
ENABLE_PNPM=true
ENABLE_NG=true
ENABLE_DOCKER=true
ENABLE_DOCKER_COMPOSE=true
ENABLE_AUTOSUGGEST=true
ENABLE_HIGHLIGHT=true
...
```

## Sensitive Data & API Keys

To keep your secrets safe and avoid committing them to a repository, this project uses a local file: `~/.zshrc.local`.

- **Security**: This file is created with restricted permissions (`chmod 600`) so only you can read it.
- **Persistence**: It is NOT tracked by Git and is NOT overwritten when you re-run the `install.sh` script.
- **Usage**: Use it to export sensitive environment variables, such as API keys or personal tokens.

### How to use it:

1. Open the file:
   ```bash
   nvim ~/.zshrc.local
   ```
2. Add your exports:
   ```zsh
   export OPENAI_API_KEY="your-secret-key"
   export GITHUB_TOKEN="your-personal-token"
   ```
3. Reload your terminal:
   ```bash
   source ~/.zshrc
   ```

## Testing

This project uses [Bats (Bash Automated Testing System)](https://github.com/bats-core/bats-core) for unit and integration testing of the shell scripts.

### Running Tests Locally

Tests are managed via `pnpm`. To run the full test suite:

1. Install testing dependencies:
   ```bash
   pnpm install
   ```
2. Execute the tests:
   ```bash
   pnpm test
   ```

### Testing Strategy

- **Mocking**: System-altering commands like `brew`, `git`, `curl`, and `unzip` are mocked during testing to prevent actual modifications to your local environment.
- **Dry Run**: The main `install.sh` supports a `--dry-run` flag which allows the script to be safely executed within tests to verify the entry-point logic and modular loading.
- **Isolation**: Tests utilize `$BATS_TMPDIR` to create temporary home directories and configuration files, ensuring that your actual system configuration remains untouched.

### Continuous Integration

A GitHub Actions pipeline runs on every push to `main` and on every pull request (including stacked PRs that target another PR branch). Each run:

1. Checks syntax with `zsh -n` (all `config/**/*.zsh` and `zshrc.template`) and `bash -n` (installer scripts).
2. Installs Starship, then runs the **full** Bats suite with `pnpm test`. Tests that need a missing tool (Starship, Python 3.11+ `tomllib`) are reported as **skipped**, never as passed. It takes seconds, so there is no per-file filtering.

The pipeline tests across:
- **Ubuntu** (Latest)
- **macOS** (Latest)
- **Windows** (via **WSL** Ubuntu-22.04)

CI uses Node.js 22 (required by the `@caveman-ai/cli` devDependency).

## Structure
- `zshrc.template`: The main entry point copied to `~/.zshrc`.
- `install.sh`: Main entry point for the installation process.
- `scripts/install/`: Modular installation scripts (features, dependencies, configuration).
- `scripts/migrate_path.sh`: Utility to move PATH definitions from `~/.zshrc` to `~/.zshenv`.
- `config/`: 
    - `core/`: Base system configurations (OS detection, history, aliases).
    - `plugins/`: Tool-specific and functional configurations (Brew, Docker, SDKMAN, etc.).
    - `starship.toml`: Starship configuration using the Gruvbox Rainbow preset.
- `AGENTS.md`, `CLAUDE.md`, `.agents/`, `.claude/`, `.gemini/`: AI coding agent configuration (see below).

## AI Agents

The repository is set up to work with the most popular AI coding agents using a single source of truth:

- **`AGENTS.md`** (root): shared project instructions. Read natively by Codex, Google Antigravity, Cursor, GitHub Copilot, Windsurf, Zed, Jules, Amp, Aider and others.
- **`CLAUDE.md`**: imports `AGENTS.md` for Claude Code (`@AGENTS.md`).
- **`.gemini/settings.json`**: tells Gemini CLI to load `AGENTS.md` as its context file.
- **`.agents/skills/`**: shared [Agent Skills](https://agentskills.io) (`SKILL.md`), discovered by Antigravity, Codex, Gemini CLI, Cursor and Copilot. `.claude/skills` is a symlink to it for Claude Code.

Installed skills: `caveman` and [`ponytail`](https://github.com/DietrichGebert/ponytail) (`/ponytail`, `/ponytail-review`, `/ponytail-audit`, `/ponytail-debt`, `/ponytail-gain`, `/ponytail-help`). Third-party skills are installed with `npx skills add <owner/repo> --skill '*' --agent antigravity` (tracked in `skills-lock.json`).

Development tooling for working on this repo with agents (not deployed by `install.sh`):

- **[Caveman CLI](https://www.npmjs.com/package/@caveman-ai/cli)** (`@caveman-ai/cli`, devDependency): after `pnpm install`, run `pnpm caveman claude` (or `codex`, `gemini`, …) to run an agent through its local context-compression proxy; `pnpm caveman stats` shows token usage. Requires Node.js 22.13+; the first run (or `pnpm caveman setup --install`) downloads its companion binaries into `~/.caveman/bin`.
- **Ponytail** and **caveman** skills: see the installed skills above.

To add instructions, edit `AGENTS.md`; to add a skill, create `.agents/skills/<name>/SKILL.md`. Personal agent settings (`.claude/settings.local.json`, `CLAUDE.local.md`, `.gemini/.env`) are git-ignored.

## Utilities

### PATH Migration (`scripts/migrate_path.sh`)

Moves explicit, single-line `PATH` definitions from `~/.zshrc` to `~/.zshenv`, where they belong (`.zshenv` is loaded in **every** zsh session, including non-interactive ones like cron, launchd, and GUI apps).

```bash
# Preview what would be moved (safe, no changes)
./scripts/migrate_path.sh

# Actually move the lines and create backups
./scripts/migrate_path.sh --apply
```

The script is never run automatically. Review the dry run before applying, because `.zshenv` runs before everything else:
- A moved line that uses a variable set earlier in `~/.zshrc` (for example `export PATH="$BUN_INSTALL/bin:$PATH"`) sees that variable empty. Move the variable too, by hand.
- On macOS, `/etc/zprofile` (`path_helper`) and `brew shellenv` run later and put their folders first, so a moved line meant to override system tools loses its priority.

The script:
- **Dry-runs by default** — shows detected lines without touching any file.
- **Creates timestamped backups** in `~/.zsh_config/backups/` before modifying anything.
- **Appends a comment note** at the end of `~/.zshrc` pointing to the backup location.
- **Skips lines inside conditionals**, functions, multiline arrays, and comments.
- **Appends `typeset -U path`** to the migrated block for automatic deduplication.
- **Works on both macOS and Linux** (uses `awk`, not `sed -i`).
- **Keeps a symlinked `~/.zshrc` a symlink** (writes through the link, e.g. into your dotfiles repo).

## Nerd Font Symbols

This configuration relies on **Nerd Font Symbols** to display icons for the OS, Git, and other tools.

### Installation
The `install.sh` script automatically installs the necessary fonts:
- **macOS**: Installed to `~/Library/Fonts`.
- **Linux**: Installed to `~/.local/share/fonts`.

> **Note for Linux**: We have disabled the automatic `fontconfig` rule because it can make some fonts appear thicker or in bold. We recommend manual configuration in your terminal settings (see below).

### Terminal Configuration

If icons (like the Apple or Linux logo) do not appear correctly, you may need to manually configure your terminal to use **Symbols Nerd Font Mono** as a fallback.

#### VS Code
Add the following to your `settings.json`:
```json
"terminal.integrated.fontFamily": "'Symbols Nerd Font Mono', 'Your favorite monospace font'",
```

#### Ghostty
Ghostty usually detects the symbols font automatically. If it doesn't, add it to your configuration (`~/.config/ghostty/config`):
```text
font-family = "Your Main Font"
font-family = "Symbols Nerd Font Mono"
```

#### iTerm2 (macOS)
1. Open **Settings** > **Profiles** > **Text**.
2. Check **Use a different font for non-ASCII text**.
3. Select **Symbols Nerd Font Mono**.

#### Other Terminals (Alacritty, Kitty)
Most modern terminals will pick up the font automatically if it's installed in the system. If you see boxes, ensure the font is correctly named `Symbols Nerd Font Mono` in your configuration file.
