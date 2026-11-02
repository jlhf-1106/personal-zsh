#!/usr/bin/env bash
#
# migrate_path.sh — Move explicit PATH definitions from ~/.zshrc to ~/.zshenv
#
# WHY: .zshenv is loaded in every zsh session (interactive, non-interactive,
#      scripts, cron, launchd, GUI apps). PATH is environment info that belongs
#      there, not in .zshrc which only runs for interactive shells.
#
# Usage:
#   ./migrate_path.sh            Dry-run (default): show what would be moved
#   ./migrate_path.sh --apply    Actually move the lines
#   ./migrate_path.sh --help     Show usage information
#
# DETECTS only simple, self-contained, single lines:
#   export PATH="$PATH:/something"
#   PATH="/something:$PATH"
#   path+=(/something)
#   path=(/something $path)    — only when parens open AND close on the same line
#
# DELIBERATELY IGNORES (left untouched in .zshrc):
#   - Lines inside if/elif/while/for/case blocks (conditionals)
#   - Lines inside function definitions (name() { ... })
#   - Multiline path=( ... ) arrays (opening paren without closing on same line)
#   - Commented-out lines (starting with #)
#
# These are intentionally skipped. Review and move them by hand if desired.
#
# PORTABILITY: Uses awk (not sed -i) for line deletion, since awk syntax is
#              identical on macOS (BSD) and Linux (GNU).

set -euo pipefail

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------
ZSHRC="$HOME/.zshrc"
ZSHENV="$HOME/.zshenv"
APPLY=false
QUIET=false

# ---------------------------------------------------------------------------
# Argument parsing
# ---------------------------------------------------------------------------
show_help() {
  cat <<'EOF'
migrate_path.sh — Move explicit PATH definitions from ~/.zshrc to ~/.zshenv

USAGE
  ./migrate_path.sh            Dry-run (default): show which lines would move
  ./migrate_path.sh --apply    Actually move lines and create backups
  ./migrate_path.sh --quiet    Suppress output when no lines are found to migrate
  ./migrate_path.sh --help     Show this message

WHAT IT DETECTS (single-line, top-level only)
  export PATH="..."
  PATH="..."
  path+=(...) — parens must open and close on the same line
  path=(...)  — parens must open and close on the same line

WHAT IT SKIPS (stays in .zshrc)
  • Lines inside if / elif / while / for / case blocks
  • Lines inside function bodies  name() { ... }
  • Multiline arrays              path=(\n  ... \n)
  • Commented-out lines           # path+=(...)

WORKFLOW
  1. Run without --apply to review the detected lines.
  2. Run with --apply to move them and create timestamped backups.
  3. Open a new terminal and run:  echo $path  (or echo $PATH | tr ':' '\n')
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --apply) APPLY=true ;;
    --quiet|-q) QUIET=true ;;
    --help|-h) show_help; exit 0 ;;
    *)
      echo "Unknown option: $1"
      echo "Run with --help for usage."
      exit 1
      ;;
  esac
  shift
done

# ---------------------------------------------------------------------------
# Pre-flight checks
# ---------------------------------------------------------------------------
if [[ ! -f "$ZSHRC" ]]; then
  echo "❌ Could not find $ZSHRC — nothing to do."
  exit 1
fi

# ---------------------------------------------------------------------------
# Stateful parser
# ---------------------------------------------------------------------------
# Walks the file line by line, tracking nesting depth of:
#   • if_depth   — incremented by if/for/while/case, decremented by fi/done/esac
#   • brace_depth — incremented by trailing {, decremented by leading }
#
# A line is only a candidate for migration when BOTH depths are zero (i.e. we
# are at the "root" level of the file, outside any block or function body).
#
# The block-state is evaluated BEFORE testing the current line, then updated
# AFTER, so that the opening line of a block (e.g. "if ...") is still
# considered "outside" while the body lines inside it are "inside".
# ---------------------------------------------------------------------------
MATCHES=$(awk '
  # ---- helpers ----
  function trim(s) { sub(/^[[:space:]]+/, "", s); return s }

  {
    line = $0
    t = trim(line)

    # Evaluate nesting state BEFORE considering this line as a candidate.
    in_block = (if_depth > 0 || brace_depth > 0)

    # ---- Candidate detection ----
    # Match:  export PATH=...  or  PATH=...  (any quoting style)
    is_path_assign = (t ~ /^(export[[:space:]]+)?PATH=/)

    # Match:  path+=(...) or path=(...)
    is_path_array  = (t ~ /^path\+?=\(/)

    is_path_line = (is_path_assign || is_path_array)

    # For array forms, require balanced parens on the same line.
    # If the opening ( has no matching ) on this line, it is a multiline
    # array — skip it entirely.
    is_balanced = 1
    if (is_path_array && t !~ /\)/) is_balanced = 0

    # Skip comments (leading # after optional whitespace).
    is_comment = (t ~ /^#/)

    if (is_path_line && !is_comment && is_balanced && !in_block) {
      print NR ":" line
    }

    # ---- Update block state for the NEXT line ----

    # Conditional / loop openers.
    # Match "if ", "if(", "for ", "for(", "while ", "while(", "case ".
    if (t ~ /^(if|for|while|case)([[:space:]]|\()/) if_depth++

    # Also catch "elif" which continues a block without closing it — but
    # we only track depth so this is a no-op (depth stays the same).

    # Conditional / loop closers.
    if (t == "fi" || t == "done" || t == "esac") if_depth--

    # Brace depth for function bodies. A trailing { opens a block;
    # a leading } closes one.
    if (t ~ /\{[[:space:]]*$/) brace_depth++
    if (t ~ /^\}/)             brace_depth--

    # Clamp to zero in case of mismatched braces/blocks in the source file.
    if (if_depth   < 0) if_depth   = 0
    if (brace_depth < 0) brace_depth = 0
  }
' "$ZSHRC")

# ---------------------------------------------------------------------------
# Report findings
# ---------------------------------------------------------------------------
if [[ -z "$MATCHES" ]]; then
  if [[ "$QUIET" == false ]]; then
    echo "✅ No explicit PATH definitions found at root level in $ZSHRC."
    echo "   Nothing to migrate."
  fi
  exit 0
fi

if [[ "$QUIET" == false ]]; then
  echo "Found these lines in $ZSHRC:"
  echo "-----------------------------------------"
  echo "$MATCHES"
  echo "-----------------------------------------"
  echo
fi

# ---------------------------------------------------------------------------
# Dry-run exit
# ---------------------------------------------------------------------------
if [[ "$APPLY" == false ]]; then
  if [[ "$QUIET" == false ]]; then
    echo "[DRY-RUN] No files were modified."
    echo "Run with --apply to move these lines to $ZSHENV."
  fi
  exit 0
fi

# ---------------------------------------------------------------------------
# Apply mode — create backups, move lines, clean up
# ---------------------------------------------------------------------------
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

BACKUP_DIR="${ZSH_CONFIG_BACKUPS:-$HOME/.zsh_config/backups}"
mkdir -p "$BACKUP_DIR"

ZSHRC_BAK_FILE="$BACKUP_DIR/.zshrc.bak.${TIMESTAMP}"
ZSHENV_BAK_FILE="$BACKUP_DIR/.zshenv.bak.${TIMESTAMP}"

# Backup .zshrc (always exists at this point).
cp "$ZSHRC" "$ZSHRC_BAK_FILE"

# Backup .zshenv if it exists; otherwise create an empty one.
HAD_ZSHENV=false
if [[ -f "$ZSHENV" ]]; then
  cp "$ZSHENV" "$ZSHENV_BAK_FILE"
  HAD_ZSHENV=true
else
  touch "$ZSHENV"
fi

if [[ "$QUIET" == false ]]; then
  echo "📦 Backups created in $BACKUP_DIR:"
  echo "   $ZSHRC_BAK_FILE"
  if [[ "$HAD_ZSHENV" == true ]]; then
    echo "   $ZSHENV_BAK_FILE"
  else
    echo "   (created new $ZSHENV)"
  fi
  echo
fi

# ---- Append migrated lines to .zshenv ----
{
  echo ""
  echo "# --- Automatically migrated from .zshrc on ${TIMESTAMP} ---"
  # Strip the "NR:" prefix that awk added, keeping only the original line.
  echo "$MATCHES" | cut -d: -f2-
  echo "typeset -U path"
  echo "# --- End of migration ---"
} >> "$ZSHENV"

# ---- Remove migrated lines from .zshrc (by line number, using awk) ----
# Collect line numbers as a comma-separated string. We avoid newline-separated
# values because BSD awk's -v flag doesn't handle embedded newlines properly.
LINE_NUMBERS=$(echo "$MATCHES" | cut -d: -f1 | paste -sd, -)
TMP_ZSHRC=$(mktemp)

awk -v lines="$LINE_NUMBERS" '
  BEGIN {
    n = split(lines, arr, ",")
    for (i = 1; i <= n; i++) skip[arr[i]+0] = 1
  }
  !(FNR in skip) { print }
' "$ZSHRC" > "$TMP_ZSHRC"

# Write through the file instead of mv, so a symlinked ~/.zshrc stays a link.
cat "$TMP_ZSHRC" > "$ZSHRC"
rm -f "$TMP_ZSHRC"

# ---- Append backup note to .zshrc if not present ----
BACKUP_NOTE="# Backups of previous configurations are stored in ~/.zsh_config/backups/"
if ! grep -qF "$BACKUP_NOTE" "$ZSHRC"; then
  echo "" >> "$ZSHRC"
  echo "$BACKUP_NOTE" >> "$ZSHRC"
fi

# ---- Final report ----
COUNT=$(echo "$MATCHES" | wc -l | tr -d ' ')
if [[ "$QUIET" == true ]]; then
  echo "⚡ [personal-zsh] Automatically migrated $COUNT PATH line(s) from ~/.zshrc to ~/.zshenv"
else
  echo "✅ Done. $COUNT line(s) moved to $ZSHENV and removed from $ZSHRC."
  echo ""
  echo "Next steps:"
  echo "  1. Open a new terminal."
  echo "  2. Run:  echo \$path"
  echo "     or:   echo \$PATH | tr ':' '\\n'"
  echo "  3. Verify your paths are all present."
fi
