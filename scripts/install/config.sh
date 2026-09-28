#!/bin/bash

setup_starship() {
    echo "🚀 Setting up Starship prompt configuration..."
    local STARSHIP_CONFIG_DIR="$HOME/.config"
    mkdir -p "$STARSHIP_CONFIG_DIR"
    if cp "$REPO_DIR/config/starship.toml" "$STARSHIP_CONFIG_DIR/starship.toml"; then
        SUMMARY_SUCCESS+=("Starship Config (Gruvbox Rainbow)")
    else
        SUMMARY_FAILED+=("Starship Config (copy failed)")
    fi

    # Clean up deprecated legacy theme file if it exists
    local OLD_THEME="$ZSH_CUSTOM/themes/leonardo.zsh-theme"
    if [ -f "$OLD_THEME" ]; then
        echo "   🧹 Removing legacy theme: $OLD_THEME"
        rm -f "$OLD_THEME"
    fi
}

copy_modular_configs() {
    echo "⚙️  Copying selected configurations..."
    rm -rf "$CONFIG_DEST"
    mkdir -p "$CONFIG_DEST/scripts"
    for file_name in $SELECTED_CONFIG_FILES; do
        if [ -f "$REPO_DIR/config/core/$file_name" ]; then
            cp "$REPO_DIR/config/core/$file_name" "$CONFIG_DEST/"
        elif [ -f "$REPO_DIR/config/plugins/$file_name" ]; then
            cp "$REPO_DIR/config/plugins/$file_name" "$CONFIG_DEST/"
        fi
    done

    if [ -f "$REPO_DIR/scripts/migrate_path.sh" ]; then
        cp "$REPO_DIR/scripts/migrate_path.sh" "$CONFIG_DEST/scripts/"
        chmod +x "$CONFIG_DEST/scripts/migrate_path.sh"
    fi
}

generate_zshrc() {
    echo "📝 Generating .zshrc..."
    local BACKUP_DIR="$CONFIG_DEST/backups"
    mkdir -p "$BACKUP_DIR"
    if [ -f "$HOME/.zshrc" ] && [ ! -L "$HOME/.zshrc" ]; then
        local TIMESTAMP=$(date +%Y%m%d_%H%M%S)
        mv "$HOME/.zshrc" "$BACKUP_DIR/.zshrc.bak.$TIMESTAMP"
    fi
    cp "$REPO_DIR/zshrc.template" "$HOME/.zshrc"

    local PLUGIN_LIST=$(echo $SELECTED_OMZ_PLUGINS | xargs)
    if [[ "$OSTYPE" == "darwin"* ]]; then
        sed -i '' "s/_DYNAMIC_PLUGINS_/$PLUGIN_LIST/g" "$HOME/.zshrc"
    else
        sed -i "s/_DYNAMIC_PLUGINS_/$PLUGIN_LIST/g" "$HOME/.zshrc"
    fi
}

setup_local_config() {
    echo "🔐 Setting up local configuration for secrets..."
    local LOCAL_ZSHRC="$HOME/.zshrc.local"
    if [ ! -f "$LOCAL_ZSHRC" ]; then
        cat << 'EOF' > "$LOCAL_ZSHRC"
# ~/.zshrc.local
# This file is for your private/local configuration.
# Use it to store API keys, tokens, and sensitive environment variables.
#
# IMPORTANT: This file is NOT tracked by git and is sourced at the end of ~/.zshrc.
# It will NOT be overwritten by the installer.

# Example:
# export OPENAI_API_KEY="sk-..."
# export GITHUB_TOKEN="ghp_..."
EOF
        chmod 600 "$LOCAL_ZSHRC"
        echo "   ✅ Created $LOCAL_ZSHRC with safe permissions (600)."
        echo "   💡 Use this file to store your API_KEYs and sensitive data safely."
    else
        echo "   ℹ️  $LOCAL_ZSHRC already exists. Keeping your existing secrets safe."
    fi
}

install_fonts() {
    local FONT_DIR
    if [ "$IS_MACOS" = true ]; then
        FONT_DIR="$HOME/Library/Fonts"
    else
        FONT_DIR="$HOME/.local/share/fonts"
    fi

    if [ -f "$FONT_DIR/SymbolsNerdFont-Regular.ttf" ]; then
        log_info "Nerd Fonts are already installed."
        SUMMARY_SUCCESS+=("Nerd Fonts")
        return
    fi

    echo "🔡 Installing fonts..."
    local FONT_ZIP="$REPO_DIR/icons-font/NerdFontsSymbolsOnly.zip"
    if [ -f "$FONT_ZIP" ]; then
        local TEMP_FONT_DIR=$(mktemp -d)
        if unzip -q "$FONT_ZIP" -d "$TEMP_FONT_DIR"; then
            mkdir -p "$FONT_DIR"
            cp "$TEMP_FONT_DIR"/*.ttf "$FONT_DIR/"
            if [ "$IS_MACOS" = false ]; then
                fc-cache -f "$FONT_DIR"
            fi
            SUMMARY_SUCCESS+=("Nerd Fonts")
        else
            SUMMARY_FAILED+=("Nerd Fonts (unzip failed)")
        fi
        rm -rf "$TEMP_FONT_DIR"
    else
        log_warn "Font archive not found at $FONT_ZIP"
        SUMMARY_FAILED+=("Nerd Fonts (archive not found)")
    fi
}

