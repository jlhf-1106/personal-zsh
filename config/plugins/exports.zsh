# General Exports
# Use the best editor available: the installer does not install Neovim.
if (( $+commands[nvim] )); then
  export EDITOR='nvim'
elif (( $+commands[vim] )); then
  export EDITOR='vim'
else
  export EDITOR='vi'
fi
export LANG=en_US.UTF-8
