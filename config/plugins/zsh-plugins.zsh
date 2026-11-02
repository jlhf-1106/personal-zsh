# Zsh Plugin Configurations

# zsh-autosuggestions
# Set suggestion color (244 is a grey)
export ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE='fg=244'
# Strategy: history first, then completion
export ZSH_AUTOSUGGEST_STRATEGY=(history completion)

# fzf integration (if installed)
# fzf 0.48+ prints its own key bindings and completion, wherever it was
# installed (Homebrew on macOS or Linux, apt, ...). Older distro packages
# ship them as files instead.
if command -v fzf &> /dev/null; then
  if fzf_init="$(fzf --zsh 2>/dev/null)"; then
    eval "$fzf_init"
  else
    [ -f /usr/share/doc/fzf/examples/key-bindings.zsh ] && source /usr/share/doc/fzf/examples/key-bindings.zsh
    [ -f /usr/share/doc/fzf/examples/completion.zsh ] && source /usr/share/doc/fzf/examples/completion.zsh
  fi
  unset fzf_init
fi

# zsh-syntax-highlighting colors:
# - default typed text in soft white
# - valid command in soft green
# - invalid command in soft red
# - All states use 'none' attribute to ensure uniform font thickness
typeset -gA ZSH_HIGHLIGHT_STYLES 2>/dev/null || true
ZSH_HIGHLIGHT_STYLES[default]='none,fg=252'
ZSH_HIGHLIGHT_STYLES[command]='none,fg=114'
ZSH_HIGHLIGHT_STYLES[path]='none,fg=114'
ZSH_HIGHLIGHT_STYLES[path_prefix]='none,fg=252'
ZSH_HIGHLIGHT_STYLES[path_pathseparator]='none,fg=252'
ZSH_HIGHLIGHT_STYLES[alias]='none,fg=114'
ZSH_HIGHLIGHT_STYLES[builtin]='none,fg=114'
ZSH_HIGHLIGHT_STYLES[function]='none,fg=114'
ZSH_HIGHLIGHT_STYLES[hashed-command]='none,fg=114'
ZSH_HIGHLIGHT_STYLES[precommand]='none,fg=114'
ZSH_HIGHLIGHT_STYLES[commandseparator]='none,fg=252'
ZSH_HIGHLIGHT_STYLES[unknown-token]='none,fg=210'
