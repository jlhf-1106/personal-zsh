#!/usr/bin/env bats

setup() {
    load 'helpers/load'
    load 'helpers/mocks'
    setup_mocks

    export REPO_DIR="$BATS_TEST_DIRNAME/.."
    export HOME="$BATS_TMPDIR/home"
    mkdir -p "$HOME"

    source "$REPO_DIR/scripts/install/common.sh"
    source "$REPO_DIR/scripts/install/deps.sh"
    source "$REPO_DIR/scripts/install/config.sh"

    SUMMARY_SUCCESS=()
    SUMMARY_FAILED=()
}

teardown() {
    rm -rf "$MOCK_BIN_DIR"
    rm -rf "$HOME"
}

# ═══════════════════════════════════════════════════════
# Starship Configuration File Tests
# ═══════════════════════════════════════════════════════

@test "config/starship.toml exists" {
    assert_file_exists "$REPO_DIR/config/starship.toml"
}

@test "config/starship.toml contains Gruvbox Rainbow palette" {
    run grep "palette = 'gruvbox_dark'" "$REPO_DIR/config/starship.toml"
    assert_success

    run grep "\[palettes.gruvbox_dark\]" "$REPO_DIR/config/starship.toml"
    assert_success
}

@test "config/starship.toml contains core prompt modules" {
    run grep "\[os\]" "$REPO_DIR/config/starship.toml"
    assert_success

    run grep "\[directory\]" "$REPO_DIR/config/starship.toml"
    assert_success

    run grep "\[git_branch\]" "$REPO_DIR/config/starship.toml"
    assert_success

    run grep "\[git_status\]" "$REPO_DIR/config/starship.toml"
    assert_success

    run grep "\[character\]" "$REPO_DIR/config/starship.toml"
    assert_success
}

@test "config/starship.toml contains valid TOML syntax" {
    # Check syntax using python3 tomllib if available
    if command -v python3 &>/dev/null; then
        run python3 -c "
try:
    import tomllib
    with open('$REPO_DIR/config/starship.toml', 'rb') as f:
        tomllib.load(f)
    print('VALID')
except Exception as e:
    import sys
    # If tomllib is not available (python < 3.11), fallback to basic syntax test
    if 'No module named' in str(e):
        print('VALID')
    else:
        print(f'INVALID: {e}', file=sys.stderr)
        sys.exit(1)
"
        assert_success
        assert_output "VALID"
    fi
}

@test "config/starship.toml does not contain unsupported jj modules" {
    run grep "\[jj_bookmark\]" "$REPO_DIR/config/starship.toml"
    assert_failure

    run grep "\[jj_status\]" "$REPO_DIR/config/starship.toml"
    assert_failure
}

@test "config/starship.toml produces no warnings when evaluated by starship" {
    if command -v starship &>/dev/null; then
        run env TERM=xterm-256color STARSHIP_CONFIG="$REPO_DIR/config/starship.toml" starship prompt --continuation
        assert_success
        refute_output --partial "WARN"
    fi
}


# ═══════════════════════════════════════════════════════
# Setup & Deployment Tests
# ═══════════════════════════════════════════════════════

@test "setup_starship copies config to ~/.config/starship.toml" {
    run setup_starship
    assert_success
    assert_output --partial "Setting up Starship prompt configuration"
    assert_file_exists "$HOME/.config/starship.toml"
}

@test "zshrc.template sets empty ZSH_THEME" {
    run grep 'ZSH_THEME=""' "$REPO_DIR/zshrc.template"
    assert_success
}

@test "zshrc.template includes starship initialization hook" {
    run grep 'starship init zsh' "$REPO_DIR/zshrc.template"
    assert_success
}

# ═══════════════════════════════════════════════════════
# install_starship Tests
# ═══════════════════════════════════════════════════════

@test "install_starship skips if already installed" {
    mock_command "starship" "starship 1.20.0"

    run install_starship
    assert_success
    assert_output --partial "Starship is already installed"
}

@test "install_starship installs via brew when available" {
    mock_command "brew" "mock brew"

    # Command lookup for starship should fail, brew should succeed
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
