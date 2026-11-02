#!/bin/bash

# Main entry point for the personal-zsh installer
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 0. Parse Arguments
DRY_RUN=false
for arg in "$@"; do
    case $arg in
        --dry-run)
        DRY_RUN=true
        shift
        ;;
    esac
done

# 1. Load Modules
source "$REPO_DIR/scripts/install/common.sh"
source "$REPO_DIR/scripts/install/features.sh"
source "$REPO_DIR/scripts/install/deps.sh"
source "$REPO_DIR/scripts/install/config.sh"

log_step "Starting Zsh configuration setup..."

# zsh reads $ZDOTDIR/.zshrc, but this installer only manages ~/.zshrc.
if [ -n "$ZDOTDIR" ] && [ "$ZDOTDIR" != "$HOME" ]; then
    log_err "ZDOTDIR is set to $ZDOTDIR. This installer only manages ~/.zshrc; unset ZDOTDIR and re-run."
    exit 1
fi

# 2. Preferences & Selection
load_preferences
select_features

# 3. Installation Phase
if [ "$DRY_RUN" = true ]; then
    log_step "DRY RUN: Skipping installation and configuration phases."
else
    install_brew_deps
    install_omz
    install_custom_plugins
    install_fnm_node
    install_sdkman
    install_bun
    install_angular
    install_git_lfs
    install_starship

    # 4. Configuration Phase
    setup_starship
    copy_modular_configs
    if [ -s "$HOME/.oh-my-zsh/oh-my-zsh.sh" ]; then
        generate_zshrc
    else
        log_err "Oh My Zsh is missing, keeping your current ~/.zshrc."
        SUMMARY_FAILED+=(".zshrc (not generated: Oh My Zsh missing)")
    fi
    setup_local_config
    install_fonts
fi

# 5. Summary
echo ""
log_step "Installation Summary:"
if [ ${#SUMMARY_SUCCESS[@]} -gt 0 ]; then
    echo "✅ Successfully Installed/Configured:"
    for item in "${SUMMARY_SUCCESS[@]}"; do
        echo "   - $item"
    done
fi

if [ ${#SUMMARY_FAILED[@]} -gt 0 ]; then
    echo "❌ Failed to Install/Configure:"
    for item in "${SUMMARY_FAILED[@]}"; do
        echo "   - $item"
    done
fi
echo ""

log_step "Setup complete! Preferences saved in $PLUGINS_CONF"
echo "🔄 Run 'source ~/.zshrc' to apply changes."
