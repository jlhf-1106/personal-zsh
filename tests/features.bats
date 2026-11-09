#!/usr/bin/env bats

setup() {
    load 'helpers/load'
    load 'helpers/mocks'
    setup_mocks
    
    export REPO_DIR="$BATS_TEST_DIRNAME/.."
    export PLUGINS_CONF="$BATS_TMPDIR/.zsh_plugins.env"
    
    # Source dependent scripts
    source "$REPO_DIR/scripts/install/common.sh"
    source "$REPO_DIR/scripts/install/features.sh"
}

@test "load_preferences should source existing config" {
    echo 'export ENABLE_AUTOSUGGEST=true' > "$PLUGINS_CONF"
    
    load_preferences
    assert_equal "$ENABLE_AUTOSUGGEST" "true"
}

@test "confirm_feature should return true if ENABLE_var is true" {
    export ENABLE_TEST=true
    run confirm_feature "TEST" "description"
    assert_success
}

@test "confirm_feature should return false if ENABLE_var is false" {
    export ENABLE_TEST=false
    run confirm_feature "TEST" "description"
    assert_failure
}

@test "select_features should add dependencies to BREW_DEPS" {
    # Set all ENABLE_ variables to false to avoid prompts
    export ENABLE_AUTOSUGGEST=false
    export ENABLE_HIGHLIGHT=false
    export ENABLE_GH=false
    export ENABLE_FNM=false
    export ENABLE_PNPM=false
    export ENABLE_BUN=false
    export ENABLE_DOCKER=false
    export ENABLE_DOCKER_COMPOSE=false
    export ENABLE_SDKMAN=false
    export ENABLE_MAVEN=false
    export ENABLE_AWS=false
    export ENABLE_AZURE=false
    export ENABLE_NG=false
    export ENABLE_GOLANG=false
    export ENABLE_FZF=true
    export ENABLE_EXTRACT=false
    export ENABLE_WD=false
    export ENABLE_GIT_LFS=false

    # Mock command -v for tools
    mock_command "git" "mock git"
    
    # Run a wrapper function that prints BREW_DEPS
    test_select_features() {
        select_features
        echo "BREW_DEPS_RESULT: $BREW_DEPS"
    }
    
    run test_select_features
    assert_output --partial "Feature selection"
    assert_output --partial "fzf"
}

@test "select_features with GIT_LFS enabled should add git-lfs to BREW_DEPS and git-lfs.zsh to SELECTED_CONFIG_FILES" {
    export ENABLE_AUTOSUGGEST=false
    export ENABLE_HIGHLIGHT=false
    export ENABLE_GH=false
    export ENABLE_FNM=false
    export ENABLE_PNPM=false
    export ENABLE_BUN=false
    export ENABLE_DOCKER=false
    export ENABLE_DOCKER_COMPOSE=false
    export ENABLE_SDKMAN=false
    export ENABLE_MAVEN=false
    export ENABLE_AWS=false
    export ENABLE_AZURE=false
    export ENABLE_NG=false
    export ENABLE_GOLANG=false
    export ENABLE_FZF=false
    export ENABLE_EXTRACT=false
    export ENABLE_WD=false
    export ENABLE_GIT_LFS=true

    mock_command "git" "mock git"

    test_select_features() {
        select_features
        echo "BREW_DEPS_RESULT: $BREW_DEPS"
        echo "CONFIG_FILES_RESULT: $SELECTED_CONFIG_FILES"
    }

    run test_select_features
    assert_success
    assert_output --partial "git-lfs"
    assert_output --partial "git-lfs.zsh"
}


@test "select_features with DOCKER on Linux should not install the daemon-less brew CLI" {
    for f in AUTOSUGGEST HIGHLIGHT GH FNM PNPM BUN DOCKER DOCKER_COMPOSE SDKMAN MAVEN AWS AZURE NG GOLANG FZF EXTRACT WD GIT_LFS; do
        export "ENABLE_$f=false"
    done
    mock_command "git" "mock git"
    export ENABLE_DOCKER=true IS_LINUX=true IS_MACOS=false
    SUMMARY_FAILED=()
    # Hide any real docker so the warning path runs.
    command() { [[ "$1 $2" == "-v docker" ]] && return 1; builtin command "$@"; }

    select_features > /dev/null || true
    [[ " $BREW_DEPS " != *" docker "* ]]
    [[ " $SELECTED_CONFIG_FILES " == *" docker.zsh "* ]]
    [[ "${SUMMARY_FAILED[*]}" == *"Docker Engine"* ]]
}

@test "select_features with DOCKER on macOS should install docker with Homebrew" {
    for f in AUTOSUGGEST HIGHLIGHT GH FNM PNPM BUN DOCKER DOCKER_COMPOSE SDKMAN MAVEN AWS AZURE NG GOLANG FZF EXTRACT WD GIT_LFS; do
        export "ENABLE_$f=false"
    done
    mock_command "git" "mock git"
    export ENABLE_DOCKER=true IS_LINUX=false IS_MACOS=true

    select_features > /dev/null || true
    [[ " $BREW_DEPS " == *" docker "* ]]
}

@test "select_features with AWS should add fzf once (awsp needs it)" {
    for f in AUTOSUGGEST HIGHLIGHT GH FNM PNPM BUN DOCKER DOCKER_COMPOSE SDKMAN MAVEN AZURE NG GOLANG EXTRACT WD GIT_LFS; do
        export "ENABLE_$f=false"
    done
    export ENABLE_AWS=true ENABLE_FZF=true
    mock_command "git" "mock git"

    select_features > /dev/null || true
    [[ " $BREW_DEPS " == *" awscli "* ]]
    [ "$(tr ' ' '\n' <<< "$BREW_DEPS" | grep -cx fzf)" -eq 1 ]

    export ENABLE_FZF=false BREW_DEPS=""
    select_features > /dev/null || true
    [[ " $BREW_DEPS " == *" fzf "* ]]
}
