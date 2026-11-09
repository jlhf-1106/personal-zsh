# Navigation
alias ..="cd .."
alias ...="cd ../.."
alias ....="cd ../../.."

# LS
if [ "$IS_MACOS" = true ]; then
  alias ls="ls -G"
else
  alias ls="ls --color=auto"
  alias open="xdg-open"
fi
alias ll="ls -lah"
alias la="ls -A"
alias l="ls -CF"

# Misc
alias zshconfig='$EDITOR ~/.zshrc'
alias reload="source ~/.zshrc"
