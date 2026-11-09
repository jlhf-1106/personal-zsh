#!/usr/bin/env bats

setup() {
    load 'helpers/load'
    load 'helpers/mocks'
    setup_mocks
    
    # Use a mock REPO_DIR so tests never touch real repo files
    export REPO_DIR="$BATS_TMPDIR/mock_repo"
    mkdir -p "$REPO_DIR/scripts/install"
    
    # Copy only the files needed by the scripts under test
    local REAL_REPO="$BATS_TEST_DIRNAME/.."
    cp "$REAL_REPO/scripts/install/common.sh" "$REPO_DIR/scripts/install/"
    cp "$REAL_REPO/scripts/install/config.sh" "$REPO_DIR/scripts/install/"
    mkdir -p "$REPO_DIR/config/core"
    cp "$REAL_REPO/config/core/00-os.zsh" "$REPO_DIR/config/core/"
    
    # Set up temp directories for isolation
    export HOME="$BATS_TMPDIR/home"
    mkdir -p "$HOME"
    export ZSH_CUSTOM="$HOME/.oh-my-zsh/custom"
    mkdir -p "$ZSH_CUSTOM/themes"
    export CONFIG_DEST="$HOME/.zsh_config"
    
    # Source dependent scripts
    source "$REPO_DIR/scripts/install/common.sh"
    source "$REPO_DIR/scripts/install/config.sh"
    
    # Mock fc-cache for install_fonts
    mock_command "fc-cache" "mock fc-cache"
    mock_command "unzip" "mock unzip"
}

teardown() {
    rm -rf "$BATS_TMPDIR/mock_repo" "$BATS_TMPDIR/home"
}

@test "setup_starship should copy starship.toml to ~/.config" {
    mkdir -p "$REPO_DIR/config"
    echo 'format = "$all"' > "$REPO_DIR/config/starship.toml"
    
    run setup_starship
    assert_success
    assert_file_exists "$HOME/.config/starship.toml"
}

@test "setup_starship should remove legacy leonardo.zsh-theme if present" {
    mkdir -p "$REPO_DIR/config"
    echo 'format = "$all"' > "$REPO_DIR/config/starship.toml"
    mkdir -p "$ZSH_CUSTOM/themes"
    touch "$ZSH_CUSTOM/themes/leonardo.zsh-theme"

    run setup_starship
    assert_success
    assert_file_not_exists "$ZSH_CUSTOM/themes/leonardo.zsh-theme"
}

@test "setup_local_config should create .zshrc.local" {
    run setup_local_config
    assert_success
    assert_file_exists "$HOME/.zshrc.local"
    assert_file_permission 600 "$HOME/.zshrc.local"
}

@test "generate_zshrc should create .zshrc from template" {
    echo "plugins=(_DYNAMIC_PLUGINS_)" > "$REPO_DIR/zshrc.template"
    
    run generate_zshrc
    assert_success
    assert_file_exists "$HOME/.zshrc"
    assert_file_contains "$HOME/.zshrc" "plugins=(history git sudo)"
}

@test "generate_zshrc should back up an existing .zshrc before replacing it" {
    echo "plugins=(_DYNAMIC_PLUGINS_)" > "$REPO_DIR/zshrc.template"
    echo "my old config" > "$HOME/.zshrc"

    run generate_zshrc
    assert_success
    run cat "$CONFIG_DEST"/backups/.zshrc.bak.*
    assert_output "my old config"
}

@test "generate_zshrc should move a symlinked .zshrc aside without touching its target" {
    echo "plugins=(_DYNAMIC_PLUGINS_)" > "$REPO_DIR/zshrc.template"
    mkdir -p "$HOME/dotfiles"
    echo "dotfiles config" > "$HOME/dotfiles/zshrc"
    ln -s "$HOME/dotfiles/zshrc" "$HOME/.zshrc"

    run generate_zshrc
    assert_success
    assert_file_contains "$HOME/dotfiles/zshrc" "dotfiles config"
    assert_link_exists "$CONFIG_DEST"/backups/.zshrc.bak.*
    assert_file_contains "$HOME/.zshrc" "plugins=(history git sudo)"
}

@test "copy_modular_configs should keep backups and drop deselected configs" {
    mkdir -p "$CONFIG_DEST/backups"
    echo "old backup" > "$CONFIG_DEST/backups/.zshrc.bak.1"
    echo "stale" > "$CONFIG_DEST/stale.zsh"

    run copy_modular_configs
    assert_success
    assert_file_exists "$CONFIG_DEST/backups/.zshrc.bak.1"
    assert_file_not_exists "$CONFIG_DEST/stale.zsh"
    assert_file_exists "$CONFIG_DEST/00-os.zsh"
}

@test "setup_starship should back up a customized starship.toml" {
    mkdir -p "$REPO_DIR/config" "$HOME/.config"
    echo 'format = "$all"' > "$REPO_DIR/config/starship.toml"
    echo 'my prompt' > "$HOME/.config/starship.toml"

    run setup_starship
    assert_success
    assert_file_contains "$HOME/.config/starship.toml" 'format = "\$all"'
    run cat "$CONFIG_DEST"/backups/starship.toml.bak.*
    assert_output "my prompt"
}

@test "setup_starship should not back up an identical starship.toml" {
    mkdir -p "$REPO_DIR/config" "$HOME/.config"
    echo 'format = "$all"' > "$REPO_DIR/config/starship.toml"
    cp "$REPO_DIR/config/starship.toml" "$HOME/.config/starship.toml"

    run setup_starship
    assert_success
    run ls "$CONFIG_DEST"/backups/starship.toml.bak.*
    assert_failure
}
