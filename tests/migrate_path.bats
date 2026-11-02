#!/usr/bin/env bats

# Tests for scripts/migrate_path.sh
#
# Every test runs in a sandboxed HOME ($BATS_TMPDIR/home) so the user's
# real ~/.zshrc and ~/.zshenv are never touched.

setup() {
    load 'helpers/load'

    MIGRATE="$BATS_TEST_DIRNAME/../scripts/migrate_path.sh"

    # Sandboxed HOME — each test gets a clean slate
    export HOME="$BATS_TMPDIR/home"
    rm -rf "$HOME"
    mkdir -p "$HOME"
}

teardown() {
    rm -rf "$BATS_TMPDIR/home"
}

# ── Helpers ────────────────────────────────────────────────────────
# Writes the reference .zshrc from the spec into the sandbox.
write_sample_zshrc() {
    cat > "$HOME/.zshrc" <<'EOF'
# example file
alias ll="ls -la"

export PATH="$PATH:/opt/homebrew/bin"

if [ -d "/opt/pyenv" ]; then
  path+=(/opt/pyenv/bin)
fi

path+=(/usr/local/go/bin)

path=(
  /some/multiline
  /other/multiline
  $path
)

# path+=(/commented/should/not/be/included)

PATH="/my/explicit/path:$PATH"

some_function() {
  path+=(/inside/a/function)
}

echo "end of file"
EOF
}

# ══════════════════════════════════════════════════════════════════
# --help
# ══════════════════════════════════════════════════════════════════

@test "--help should display usage information" {
    run "$MIGRATE" --help
    assert_success
    assert_output --partial "USAGE"
    assert_output --partial "--apply"
    assert_output --partial "WORKFLOW"
}

@test "-h should also display usage information" {
    run "$MIGRATE" -h
    assert_success
    assert_output --partial "USAGE"
}

@test "unknown flag should fail with guidance" {
    write_sample_zshrc
    run "$MIGRATE" --unknown-flag
    assert_failure
    assert_output --partial "Unknown option"
    assert_output --partial "--help"
}

# ══════════════════════════════════════════════════════════════════
# Missing .zshrc
# ══════════════════════════════════════════════════════════════════

@test "should exit with error when .zshrc does not exist" {
    run "$MIGRATE"
    assert_failure
    assert_output --partial "Could not find"
}

# ══════════════════════════════════════════════════════════════════
# Dry-run detection
# ══════════════════════════════════════════════════════════════════

@test "dry-run should detect export PATH line" {
    write_sample_zshrc
    run "$MIGRATE"
    assert_success
    assert_output --partial 'export PATH="$PATH:/opt/homebrew/bin"'
}

@test "dry-run should detect path+= line" {
    write_sample_zshrc
    run "$MIGRATE"
    assert_success
    assert_output --partial 'path+=(/usr/local/go/bin)'
}

@test "dry-run should detect bare PATH= line" {
    write_sample_zshrc
    run "$MIGRATE"
    assert_success
    assert_output --partial 'PATH="/my/explicit/path:$PATH"'
}

@test "dry-run should show DRY-RUN message" {
    write_sample_zshrc
    run "$MIGRATE"
    assert_success
    assert_output --partial "[DRY-RUN]"
}

@test "dry-run should not modify .zshrc" {
    write_sample_zshrc
    cp "$HOME/.zshrc" "$HOME/.zshrc.snapshot"

    run "$MIGRATE"
    assert_success

    # File content must be identical
    run diff "$HOME/.zshrc" "$HOME/.zshrc.snapshot"
    assert_success
}

@test "dry-run should not create .zshenv" {
    write_sample_zshrc
    run "$MIGRATE"
    assert_success
    assert_file_not_exists "$HOME/.zshenv"
}

# ══════════════════════════════════════════════════════════════════
# Exclusion rules — lines the parser must skip
# ══════════════════════════════════════════════════════════════════

@test "should NOT detect path+= inside an if block" {
    write_sample_zshrc
    run "$MIGRATE"
    assert_success
    refute_output --partial '/opt/pyenv/bin'
}

@test "should NOT detect path+= inside a function body" {
    write_sample_zshrc
    run "$MIGRATE"
    assert_success
    refute_output --partial '/inside/a/function'
}

@test "should NOT detect commented-out path+= line" {
    write_sample_zshrc
    run "$MIGRATE"
    assert_success
    refute_output --partial '/commented/should/not/be/included'
}

@test "should NOT detect multiline path=() array" {
    write_sample_zshrc
    run "$MIGRATE"
    assert_success
    refute_output --partial '/some/multiline'
}

@test "should skip path+= inside a for loop" {
    cat > "$HOME/.zshrc" <<'EOF'
for dir in /opt/tools/*; do
  path+=("$dir/bin")
done
EOF
    run "$MIGRATE"
    assert_success
    assert_output --partial "No explicit PATH definitions"
}

@test "should skip path+= inside a while loop" {
    cat > "$HOME/.zshrc" <<'EOF'
while read -r line; do
  path+=("$line")
done < /tmp/paths.txt
EOF
    run "$MIGRATE"
    assert_success
    assert_output --partial "No explicit PATH definitions"
}

@test "should skip PATH= inside a case block" {
    cat > "$HOME/.zshrc" <<'EOF'
case "$OSTYPE" in
  darwin*)
    PATH="/opt/mac/bin:$PATH"
    ;;
  linux*)
    PATH="/opt/linux/bin:$PATH"
    ;;
esac
EOF
    run "$MIGRATE"
    assert_success
    assert_output --partial "No explicit PATH definitions"
}

@test "should skip path+= inside nested if blocks" {
    cat > "$HOME/.zshrc" <<'EOF'
if [ -d "/opt" ]; then
  if [ -d "/opt/inner" ]; then
    path+=(/opt/inner/bin)
  fi
fi
EOF
    run "$MIGRATE"
    assert_success
    assert_output --partial "No explicit PATH definitions"
}

# ══════════════════════════════════════════════════════════════════
# Apply mode — full migration test
# ══════════════════════════════════════════════════════════════════

@test "apply should create .zshenv with migrated lines" {
    write_sample_zshrc
    run "$MIGRATE" --apply
    assert_success
    assert_file_exists "$HOME/.zshenv"

    # All three migrated lines must be present
    run grep -F 'export PATH="$PATH:/opt/homebrew/bin"' "$HOME/.zshenv"
    assert_success

    run grep -F 'path+=(/usr/local/go/bin)' "$HOME/.zshenv"
    assert_success

    run grep -F 'PATH="/my/explicit/path:$PATH"' "$HOME/.zshenv"
    assert_success
}

@test "apply should append typeset -U path" {
    write_sample_zshrc
    run "$MIGRATE" --apply
    assert_success

    run grep -F 'typeset -U path' "$HOME/.zshenv"
    assert_success
}

@test "apply should include migration header and footer" {
    write_sample_zshrc
    run "$MIGRATE" --apply
    assert_success

    run grep -F '# --- Automatically migrated from .zshrc on' "$HOME/.zshenv"
    assert_success

    run grep -F '# --- End of migration ---' "$HOME/.zshenv"
    assert_success
}

@test "apply should remove migrated lines from .zshrc" {
    write_sample_zshrc
    run "$MIGRATE" --apply
    assert_success

    run grep -F 'export PATH="$PATH:/opt/homebrew/bin"' "$HOME/.zshrc"
    assert_failure

    run grep -F 'PATH="/my/explicit/path:$PATH"' "$HOME/.zshrc"
    assert_failure

    # The root-level path+= line should be gone
    # but three remain: inside if + inside function + commented-out
    run grep -cF 'path+=(' "$HOME/.zshrc"
    assert_success
    assert_output "3"
}

@test "apply should preserve alias in .zshrc" {
    write_sample_zshrc
    run "$MIGRATE" --apply
    assert_success

    run grep -F 'alias ll="ls -la"' "$HOME/.zshrc"
    assert_success
}

@test "apply should preserve if block in .zshrc" {
    write_sample_zshrc
    run "$MIGRATE" --apply
    assert_success

    run grep -F 'path+=(/opt/pyenv/bin)' "$HOME/.zshrc"
    assert_success
}

@test "apply should preserve multiline array in .zshrc" {
    write_sample_zshrc
    run "$MIGRATE" --apply
    assert_success

    run grep -F '/some/multiline' "$HOME/.zshrc"
    assert_success
    run grep -F '/other/multiline' "$HOME/.zshrc"
    assert_success
}

@test "apply should preserve commented-out line in .zshrc" {
    write_sample_zshrc
    run "$MIGRATE" --apply
    assert_success

    run grep -F '# path+=(/commented/should/not/be/included)' "$HOME/.zshrc"
    assert_success
}

@test "apply should preserve function body in .zshrc" {
    write_sample_zshrc
    run "$MIGRATE" --apply
    assert_success

    run grep -F 'path+=(/inside/a/function)' "$HOME/.zshrc"
    assert_success
}

@test "apply should preserve trailing content in .zshrc" {
    write_sample_zshrc
    run "$MIGRATE" --apply
    assert_success

    run grep -F 'echo "end of file"' "$HOME/.zshrc"
    assert_success
}

# ══════════════════════════════════════════════════════════════════
# Backups
# ══════════════════════════════════════════════════════════════════

@test "apply should create a timestamped .zshrc backup in ~/.zsh_config/backups/" {
    write_sample_zshrc
    run "$MIGRATE" --apply
    assert_success

    # There should be at least one backup file in ~/.zsh_config/backups/
    local count
    count=$(ls "$HOME"/.zsh_config/backups/.zshrc.bak.* 2>/dev/null | wc -l | tr -d ' ')
    [ "$count" -ge 1 ]
}

@test "apply should append backup location note to .zshrc" {
    write_sample_zshrc
    run "$MIGRATE" --apply
    assert_success

    run grep -F '# Backups of previous configurations are stored in ~/.zsh_config/backups/' "$HOME/.zshrc"
    assert_success
}

@test "apply should handle missing .zshenv gracefully" {
    write_sample_zshrc
    # Ensure .zshenv does NOT exist
    rm -f "$HOME/.zshenv"

    run "$MIGRATE" --apply
    assert_success
    assert_file_exists "$HOME/.zshenv"
    assert_output --partial "created new"
}

@test "apply should backup existing .zshenv" {
    write_sample_zshrc
    echo "# pre-existing content" > "$HOME/.zshenv"

    run "$MIGRATE" --apply
    assert_success

    # Backup should exist in ~/.zsh_config/backups/
    local count
    count=$(ls "$HOME"/.zsh_config/backups/.zshenv.bak.* 2>/dev/null | wc -l | tr -d ' ')
    [ "$count" -ge 1 ]

    # Pre-existing content should still be in .zshenv (migrated lines appended)
    run grep -F '# pre-existing content' "$HOME/.zshenv"
    assert_success
}

# ══════════════════════════════════════════════════════════════════
# Idempotency
# ══════════════════════════════════════════════════════════════════

@test "second run after apply should find nothing to migrate" {
    write_sample_zshrc
    run "$MIGRATE" --apply
    assert_success

    run "$MIGRATE"
    assert_success
    assert_output --partial "No explicit PATH definitions"
}

# ══════════════════════════════════════════════════════════════════
# Edge cases
# ══════════════════════════════════════════════════════════════════

@test "should handle .zshrc with no PATH definitions" {
    cat > "$HOME/.zshrc" <<'EOF'
# Just aliases
alias ll="ls -la"
alias gs="git status"
echo "hello"
EOF
    run "$MIGRATE"
    assert_success
    assert_output --partial "No explicit PATH definitions"
}

@test "should detect single-line path=() assignment" {
    cat > "$HOME/.zshrc" <<'EOF'
path=(/usr/local/bin /usr/bin $path)
EOF
    run "$MIGRATE"
    assert_success
    assert_output --partial 'path=(/usr/local/bin /usr/bin $path)'
}

@test "should detect PATH with single quotes" {
    cat > "$HOME/.zshrc" <<'EOF'
PATH='/custom/bin:$PATH'
EOF
    run "$MIGRATE"
    assert_success
    assert_output --partial "PATH='/custom/bin:"
}

@test "should detect export PATH without quotes" {
    cat > "$HOME/.zshrc" <<'EOF'
export PATH=$PATH:/no/quotes/bin
EOF
    run "$MIGRATE"
    assert_success
    assert_output --partial 'export PATH=$PATH:/no/quotes/bin'
}

@test "should handle indented top-level PATH line" {
    cat > "$HOME/.zshrc" <<'EOF'
  export PATH="$PATH:/indented/bin"
EOF
    run "$MIGRATE"
    assert_success
    assert_output --partial '/indented/bin'
}

@test "apply should migrate and remove a single PATH line" {
    cat > "$HOME/.zshrc" <<'EOF'
alias gs="git status"
export PATH="$PATH:/only/one"
echo "end"
EOF
    run "$MIGRATE" --apply
    assert_success

    run grep -F '/only/one' "$HOME/.zshenv"
    assert_success

    run grep -F '/only/one' "$HOME/.zshrc"
    assert_failure

    run grep -F 'alias gs' "$HOME/.zshrc"
    assert_success

    run grep -F 'echo "end"' "$HOME/.zshrc"
    assert_success
}

@test "apply should correctly count migrated lines" {
    write_sample_zshrc
    run "$MIGRATE" --apply
    assert_success
    assert_output --partial "3 line(s) moved"
}

@test "apply should keep a symlinked .zshrc as a symlink" {
    mkdir -p "$HOME/dotfiles"
    printf 'alias ll="ls -la"\nexport PATH="$PATH:/opt/bin"\n' > "$HOME/dotfiles/zshrc"
    ln -s "$HOME/dotfiles/zshrc" "$HOME/.zshrc"

    run bash "$MIGRATE" --apply
    assert_success
    assert_link_exists "$HOME/.zshrc"
    refute grep -q '/opt/bin' "$HOME/dotfiles/zshrc"
}
