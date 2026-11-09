#!/usr/bin/env bats

setup() {
    load 'helpers/load'
    export REPO_DIR="$BATS_TEST_DIRNAME/.."
    # Source the script under test
    source "$REPO_DIR/scripts/install/common.sh"
}

@test "log functions should output text" {
    run log_info "test info"
    assert_output --partial "test info"
    
    run log_warn "test warn"
    assert_output --partial "test warn"
    
    run log_err "test err"
    assert_output --partial "test err"
    
    run log_step "test step"
    assert_output --partial "test step"
}

@test "initial state is set correctly" {
    assert_equal "$SELECTED_OMZ_PLUGINS" "history git sudo"
    assert_equal "$INSTALL_SDKMAN" "false"
}
