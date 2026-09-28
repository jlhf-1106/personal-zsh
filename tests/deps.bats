#!/usr/bin/env bats

load 'helpers/load'
load 'helpers/mocks'

export REPO_DIR="$BATS_TEST_DIRNAME/.."
source "$REPO_DIR/scripts/install/common.sh"
source "$REPO_DIR/scripts/install/deps.sh"

setup() {
    setup_mocks
    
    # Global state reset
    SUMMARY_SUCCESS=()
    SUMMARY_FAILED=()
}

@test "install_omz should skip if already installed" {
    mkdir -p "$HOME/.oh-my-zsh"
    
    run install_omz
    assert_success
    assert_output --partial "Oh My Zsh is already installed"
}

@test "install_custom_plugins should clone plugins" {
    export ZSH_CUSTOM="$BATS_TMPDIR/zsh_custom"
    mkdir -p "$ZSH_CUSTOM/plugins"
    
    mock_command "git" "mock git clone"
    
    run install_custom_plugins
    assert_success
    assert_output --partial "Cloning custom plugins"
}

@test "install_brew_deps should install specified dependencies" {
    export BREW_DEPS="git fzf"
    
    # Mock brew to fail first then succeed
    mock_command "brew" "mock brew"
    
    run install_brew_deps
    assert_success
    assert_output --partial "Checking/Installing dependencies with Homebrew"
}

@test "install_git_lfs should skip if ENABLE_GIT_LFS is not true" {
    export ENABLE_GIT_LFS=false
    run install_git_lfs
    assert_success
    refute_output --partial "Initializing Git LFS"
}

@test "install_git_lfs should initialize if ENABLE_GIT_LFS is true and git-lfs command exists" {
    export ENABLE_GIT_LFS=true
    mock_command "git-lfs" "mock git-lfs"
    mock_command "git" "mock git"
    
    run install_git_lfs
    assert_success
    assert_output --partial "Initializing Git LFS"
}

@test "install_git_lfs should report failure if ENABLE_GIT_LFS is true but git-lfs command is missing" {
    export ENABLE_GIT_LFS=true
    
    command() {
        if [ "$1" = "-v" ] && [ "$2" = "git-lfs" ]; then
            return 1
        fi
        builtin command "$@"
    }
    
    run install_git_lfs
    assert_success
    assert_output --partial "git-lfs command not found"
}

@test "install_starship should skip if already installed" {
    mock_command "starship" "mock starship"

    run install_starship
    assert_success
    assert_output --partial "Starship is already installed"
}

@test "install_starship should install when missing" {
    mock_command "brew" "mock brew"

    command() {
        if [ "$1" = "-v" ] && [ "$2" = "starship" ]; then
            return 1
        fi
        builtin command "$@"
    }

    run install_starship
    assert_success
    assert_output --partial "Installing Starship prompt"
}


