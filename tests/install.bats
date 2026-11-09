#!/usr/bin/env bats

setup() {
    load 'helpers/load'
    load 'helpers/mocks'
    setup_mocks
    
    # Mock mandatory deps and user input for feature selection
    mock_system_commands
    
    export REPO_DIR="$BATS_TEST_DIRNAME/.."
    export PLUGINS_CONF="$BATS_TMPDIR/.zsh_plugins.env"
}

@test "install.sh with --dry-run should succeed and report dry run" {
    # We need to mock 'read' or provide input if select_features is called
    # But first let's see if we can just run it with --dry-run
    # select_features might prompt if variables are not set
    
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
    export ENABLE_GIT_LFS=false

    run ./install.sh --dry-run
    assert_success
    assert_output --partial "DRY RUN: Skipping installation and configuration phases."
}

@test "install.sh should refuse to run when ZDOTDIR points elsewhere" {
    ZDOTDIR="$BATS_TMPDIR/elsewhere" run ./install.sh --dry-run
    assert_failure
    assert_output --partial "ZDOTDIR is set to"
}
