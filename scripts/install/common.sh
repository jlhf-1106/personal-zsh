#!/bin/bash

# Shared environment variables for the installer
ZSH_CUSTOM="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"
CONFIG_DEST="$HOME/.zsh_config"
PLUGINS_CONF="${PLUGINS_CONF:-$REPO_DIR/.zsh_plugins.env}"

# Global state
SELECTED_OMZ_PLUGINS="history git"
SELECTED_CONFIG_FILES="00-os.zsh brew.zsh aliases.zsh exports.zsh history.zsh zsh-plugins.zsh git.zsh"
BREW_DEPS=""
INSTALL_SDKMAN=false
SUMMARY_SUCCESS=()
SUMMARY_FAILED=()

# OS Detection
source "$REPO_DIR/config/core/00-os.zsh"

# Include macOS-specific config when on macOS
if [ "$IS_MACOS" = true ]; then
    SELECTED_CONFIG_FILES="$SELECTED_CONFIG_FILES macos.zsh"
fi

log_info() { echo "   ✅ $1"; }
log_warn() { echo "   ⚠️  $1"; }
log_err() { echo "   ❌ $1"; }
log_step() { echo "🚀 $1"; }
