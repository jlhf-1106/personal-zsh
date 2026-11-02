#!/bin/bash

load_preferences() {
    if [ -f "$PLUGINS_CONF" ]; then
        echo "📄 Loading preferences from $PLUGINS_CONF"
        source "$PLUGINS_CONF"
    fi
}

confirm_feature() {
    local var_name="ENABLE_$1"
    local description="$2"
    
    if [[ "${!var_name}" == "true" ]]; then
        return 0
    elif [[ "${!var_name}" == "false" ]]; then
        return 1
    fi

    read -p "❓ Install $description? [Y/n]: " choice
    case "$choice" in 
      [nN][oO]|[nN])
        echo "$var_name=false" >> "$PLUGINS_CONF"
        export "$var_name=false"
        return 1
        ;;
      *)
        echo "$var_name=true" >> "$PLUGINS_CONF"
        export "$var_name=true"
        return 0
        ;;
    esac
}

select_features() {
    echo "🔍 Feature selection..."
    
    # Check for git (essential for cloning)
    if ! command -v git &> /dev/null; then
        echo "⚠️  Git not found. Adding to Homebrew dependencies..."
        BREW_DEPS="git"
    fi

    if [ "$IS_LINUX" = true ]; then
        BREW_DEPS="$BREW_DEPS unzip"
    fi

    # OMZ Plugins
    confirm_feature "AUTOSUGGEST" "Zsh Autosuggestions" && SELECTED_OMZ_PLUGINS="$SELECTED_OMZ_PLUGINS zsh-autosuggestions"
    confirm_feature "HIGHLIGHT" "Zsh Syntax Highlighting" && SELECTED_OMZ_PLUGINS="$SELECTED_OMZ_PLUGINS zsh-syntax-highlighting"

    # Tools
    confirm_feature "GH" "GitHub CLI (gh)" && { SELECTED_OMZ_PLUGINS="$SELECTED_OMZ_PLUGINS gh"; BREW_DEPS="$BREW_DEPS gh"; }
    confirm_feature "GIT_LFS" "Git LFS" && { SELECTED_CONFIG_FILES="$SELECTED_CONFIG_FILES git-lfs.zsh"; BREW_DEPS="$BREW_DEPS git-lfs"; }
    confirm_feature "FNM" "Node Manager (fnm)" && { SELECTED_OMZ_PLUGINS="$SELECTED_OMZ_PLUGINS fnm"; SELECTED_CONFIG_FILES="$SELECTED_CONFIG_FILES fnm.zsh"; BREW_DEPS="$BREW_DEPS fnm"; }
    confirm_feature "PNPM" "Package Manager (pnpm)" && { SELECTED_CONFIG_FILES="$SELECTED_CONFIG_FILES pnpm.zsh"; BREW_DEPS="$BREW_DEPS pnpm"; }
    confirm_feature "BUN" "Bun Runtime" && { SELECTED_CONFIG_FILES="$SELECTED_CONFIG_FILES bun.zsh"; }
    confirm_feature "DOCKER" "Docker" && { SELECTED_OMZ_PLUGINS="$SELECTED_OMZ_PLUGINS docker"; SELECTED_CONFIG_FILES="$SELECTED_CONFIG_FILES docker.zsh"; BREW_DEPS="$BREW_DEPS docker"; }
    if command -v docker &> /dev/null || [[ "$ENABLE_DOCKER" == "true" ]]; then
        confirm_feature "DOCKER_COMPOSE" "Docker Compose" && { SELECTED_OMZ_PLUGINS="$SELECTED_OMZ_PLUGINS docker-compose"; SELECTED_CONFIG_FILES="$SELECTED_CONFIG_FILES docker-compose.zsh"; BREW_DEPS="$BREW_DEPS docker-compose"; }
    fi
    confirm_feature "SDKMAN" "Java Manager (SDKMAN!)" && { SELECTED_OMZ_PLUGINS="$SELECTED_OMZ_PLUGINS sdk"; SELECTED_CONFIG_FILES="$SELECTED_CONFIG_FILES sdkman.zsh"; INSTALL_SDKMAN=true; }
    confirm_feature "MAVEN" "Maven (mvn)" && { SELECTED_OMZ_PLUGINS="$SELECTED_OMZ_PLUGINS mvn"; BREW_DEPS="$BREW_DEPS maven"; }
    confirm_feature "AWS" "AWS CLI" && { SELECTED_OMZ_PLUGINS="$SELECTED_OMZ_PLUGINS aws"; SELECTED_CONFIG_FILES="$SELECTED_CONFIG_FILES aws.zsh"; BREW_DEPS="$BREW_DEPS awscli"; }
    confirm_feature "AZURE" "Azure CLI" && { SELECTED_OMZ_PLUGINS="$SELECTED_OMZ_PLUGINS azure"; SELECTED_CONFIG_FILES="$SELECTED_CONFIG_FILES azure.zsh"; BREW_DEPS="$BREW_DEPS azure-cli"; }
    if confirm_feature "NG" "Angular CLI (ng)"; then
        # The OMZ ng plugin provides lazy completion (runs ng only on Tab).
        SELECTED_OMZ_PLUGINS="$SELECTED_OMZ_PLUGINS ng"
        INSTALL_ANGULAR=true
        
        if [[ "$ENABLE_PNPM" != "true" ]] && ! command -v pnpm &> /dev/null; then
            echo "⚠️  Warning: Angular CLI will be installed globally via pnpm (mandatory for security)."
            if [[ ! " $BREW_DEPS " =~ " pnpm " ]]; then
                BREW_DEPS="$BREW_DEPS pnpm"
            fi
        fi
    fi
    confirm_feature "GOLANG" "Go Language" && { SELECTED_OMZ_PLUGINS="$SELECTED_OMZ_PLUGINS golang"; BREW_DEPS="$BREW_DEPS go"; }
    confirm_feature "FZF" "Fzf (Fuzzy Finder)" && BREW_DEPS="$BREW_DEPS fzf"
    confirm_feature "EXTRACT" "Extract Utility" && SELECTED_OMZ_PLUGINS="$SELECTED_OMZ_PLUGINS extract"
    confirm_feature "WD" "Warp Directory (wd)" && { SELECTED_OMZ_PLUGINS="$SELECTED_OMZ_PLUGINS wd"; SELECTED_CONFIG_FILES="$SELECTED_CONFIG_FILES wd.zsh"; }
}
