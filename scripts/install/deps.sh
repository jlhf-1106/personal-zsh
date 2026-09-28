#!/bin/bash

check_brew() {
    if ! command -v brew &> /dev/null; then
        echo "🍺 Homebrew not found. Attempting to install..."
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
        if [ "$IS_MACOS" = true ]; then
            eval "$(/opt/homebrew/bin/brew shellenv)"
        else
            eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
        fi
    fi
}

install_brew_deps() {
    if [ -n "$BREW_DEPS" ]; then
        echo "🍺 Checking/Installing dependencies with Homebrew..."
        check_brew
        for dep in $BREW_DEPS; do
            if ! brew list $dep &>/dev/null; then
                echo "   📥 Installing $dep..."
                if brew install $dep; then
                    SUMMARY_SUCCESS+=("Brew: $dep")
                else
                    SUMMARY_FAILED+=("Brew: $dep (installation failed)")
                fi
            else
                log_info "$dep is already installed."
                SUMMARY_SUCCESS+=("Brew: $dep")
            fi
        done
    fi
}

install_omz() {
    if [ ! -d "$HOME/.oh-my-zsh" ]; then
        echo "📦 Installing Oh My Zsh..."
        if sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended; then
            SUMMARY_SUCCESS+=("Oh My Zsh")
        else
            SUMMARY_FAILED+=("Oh My Zsh (installation failed)")
        fi
    else
        log_info "Oh My Zsh is already installed."
        SUMMARY_SUCCESS+=("Oh My Zsh")
    fi
}

_clone_plugin() {
    local plugin="$1"
    local url="$2"
    local dest="$ZSH_CUSTOM/plugins/$plugin"
    if [ ! -d "$dest" ]; then
        if git clone "$url" "$dest"; then
            SUMMARY_SUCCESS+=("Zsh Plugin: $plugin")
        else
            SUMMARY_FAILED+=("Zsh Plugin: $plugin (git clone failed)")
        fi
    else
        log_info "$plugin already exists."
        SUMMARY_SUCCESS+=("Zsh Plugin: $plugin")
    fi
}

install_custom_plugins() {
    echo "🔌 Cloning custom plugins..."
    mkdir -p "$ZSH_CUSTOM/plugins"
    _clone_plugin "zsh-autosuggestions" "https://github.com/zsh-users/zsh-autosuggestions"
    _clone_plugin "zsh-syntax-highlighting" "https://github.com/zsh-users/zsh-syntax-highlighting.git"
}

install_sdkman() {
    if [ "$INSTALL_SDKMAN" = true ] && [ ! -d "$HOME/.sdkman" ]; then
        echo "📦 Installing SDKMAN!..."

        # SDKMAN requires Bash 4+. macOS ships with Bash 3.2,
        # so we use Homebrew's modern Bash when available.
        local bash_bin="bash"
        if [ "$IS_MACOS" = true ]; then
            local brew_bash
            brew_bash="$(brew --prefix)/bin/bash"
            if [ -x "$brew_bash" ]; then
                bash_bin="$brew_bash"
            else
                log_warn "Homebrew bash not found. Installing..."
                if brew install bash; then
                    bash_bin="$(brew --prefix)/bin/bash"
                else
                    SUMMARY_FAILED+=("SDKMAN! (requires Bash 4+, brew install bash failed)")
                    return
                fi
            fi
        fi

        if curl -s "https://get.sdkman.io" | "$bash_bin"; then
            if [[ "$OSTYPE" == "darwin"* ]]; then
                sed -i '' 's/sdkman_auto_env=false/sdkman_auto_env=true/g' "$HOME/.sdkman/etc/config" 2>/dev/null
                sed -i '' 's/sdkman_auto_answer=false/sdkman_auto_answer=true/g' "$HOME/.sdkman/etc/config" 2>/dev/null
            else
                sed -i 's/sdkman_auto_env=false/sdkman_auto_env=true/g' "$HOME/.sdkman/etc/config" 2>/dev/null
                sed -i 's/sdkman_auto_answer=false/sdkman_auto_answer=true/g' "$HOME/.sdkman/etc/config" 2>/dev/null
            fi
            SUMMARY_SUCCESS+=("SDKMAN!")
        else
            SUMMARY_FAILED+=("SDKMAN! (installation failed)")
            return
        fi
    elif [ "$INSTALL_SDKMAN" = true ]; then
        log_info "SDKMAN! is already installed."
        SUMMARY_SUCCESS+=("SDKMAN!")
    fi

    if [ "$INSTALL_SDKMAN" = true ]; then
        export SDKMAN_DIR="$HOME/.sdkman"
        if [ -s "$SDKMAN_DIR/bin/sdkman-init.sh" ]; then
            source "$SDKMAN_DIR/bin/sdkman-init.sh"

            # Enable non-interactive auto answer if config exists
            if [ -f "$SDKMAN_DIR/etc/config" ]; then
                if [[ "$OSTYPE" == "darwin"* ]]; then
                    sed -i '' 's/sdkman_auto_answer=false/sdkman_auto_answer=true/g' "$SDKMAN_DIR/etc/config" 2>/dev/null
                else
                    sed -i 's/sdkman_auto_answer=false/sdkman_auto_answer=true/g' "$SDKMAN_DIR/etc/config" 2>/dev/null
                fi
            fi

            # Check if Java 21 is installed
            if [ ! -d "$SDKMAN_DIR/candidates/java/21-tem" ] && ! ls -d "$SDKMAN_DIR/candidates/java/21"* &>/dev/null; then
                echo "📦 Installing Java 21 (Temurin) via SDKMAN!..."
                if sdk install java 21-tem; then
                    SUMMARY_SUCCESS+=("Java 21 (SDKMAN!)")
                else
                    SUMMARY_FAILED+=("Java 21 (SDKMAN! install failed)")
                fi
            else
                log_info "Java 21 is already available via SDKMAN!."
                SUMMARY_SUCCESS+=("Java 21 (SDKMAN!)")
            fi
        fi
    fi
}

install_fnm_node() {
    if [[ "$ENABLE_FNM" == "true" ]] && command -v fnm &> /dev/null; then
        eval "$(fnm env)"
        if ! command -v node &> /dev/null; then
            echo "📦 Installing Node.js LTS via fnm..."
            if fnm install --lts && fnm default lts-latest; then
                eval "$(fnm env)"
                SUMMARY_SUCCESS+=("Node.js LTS (fnm)")
            else
                SUMMARY_FAILED+=("Node.js LTS (fnm install failed)")
            fi
        else
            log_info "Node.js is already available via fnm."
            SUMMARY_SUCCESS+=("Node.js (fnm)")
        fi
    fi
}

install_bun() {
    if [[ "$ENABLE_BUN" == "true" ]] && ! command -v bun &> /dev/null; then
        echo "📦 Installing Bun..."
        if curl -fsSL https://bun.sh/install | bash; then
            SUMMARY_SUCCESS+=("Bun")
        else
            SUMMARY_FAILED+=("Bun (installation failed)")
        fi
    elif [[ "$ENABLE_BUN" == "true" ]]; then
        log_info "Bun is already installed."
        SUMMARY_SUCCESS+=("Bun")
    fi
}

install_angular() {
    if [ "$INSTALL_ANGULAR" = true ]; then
        if command -v ng &> /dev/null; then
            log_info "Angular CLI is already installed."
            SUMMARY_SUCCESS+=("Angular CLI")
            return
        fi

        echo "📦 Installing Angular CLI globally via pnpm..."
        if ! command -v pnpm &> /dev/null; then
            echo "   ❌ pnpm is not available yet, cannot install Angular CLI."
            SUMMARY_FAILED+=("Angular CLI (pnpm not found)")
            return
        fi

        # Ensure fnm and node are in PATH for pnpm
        if command -v fnm &> /dev/null; then
            eval "$(fnm env)"
        fi

        # Ensure pnpm global bin is in PATH
        export PNPM_HOME="$HOME/.local/share/pnpm"
        export PATH="$PNPM_HOME/bin:$PNPM_HOME:$PATH"

        if pnpm add -g @angular/cli; then
            SUMMARY_SUCCESS+=("Angular CLI")
        else
            SUMMARY_FAILED+=("Angular CLI (installation failed)")
        fi
    fi
}

install_git_lfs() {
    if [ "$ENABLE_GIT_LFS" = true ]; then
        if command -v git-lfs &> /dev/null; then
            echo "📦 Initializing Git LFS..."
            if git lfs install; then
                SUMMARY_SUCCESS+=("Git LFS (initialized)")
            else
                SUMMARY_FAILED+=("Git LFS (initialization failed)")
            fi
        else
            log_warn "git-lfs command not found, cannot initialize."
            SUMMARY_FAILED+=("Git LFS (not found)")
        fi
    fi
}

install_starship() {
    if command -v starship &> /dev/null; then
        log_info "Starship is already installed."
        SUMMARY_SUCCESS+=("Starship")
        return
    fi

    echo "🚀 Installing Starship prompt..."
    if command -v brew &> /dev/null; then
        if brew install starship; then
            SUMMARY_SUCCESS+=("Starship")
            return
        fi
    fi

    if curl -sS https://starship.rs/install.sh | sh -s -- -y; then
        SUMMARY_SUCCESS+=("Starship")
    else
        SUMMARY_FAILED+=("Starship (installation failed)")
    fi
}


