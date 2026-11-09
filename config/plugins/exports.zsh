# General Exports
export EDITOR='nvim'

# Keep an existing LANG; minimal Linux/WSL may not have en_US.UTF-8 generated.
if [[ -z "$LANG" ]] && locale -a 2>/dev/null | grep -qiE '^en_US\.utf-?8$'; then
  export LANG=en_US.UTF-8
fi
