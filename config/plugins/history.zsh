# History Configuration
HISTSIZE=10000
SAVEHIST=10000
HISTFILE=$HOME/.zsh_history

# History Options
setopt APPEND_HISTORY          # Append to history file instead of overwriting
setopt SHARE_HISTORY           # Share history between different sessions
setopt HIST_IGNORE_ALL_DUPS    # Delete old recorded event if new event is a duplicate
setopt HIST_REDUCE_BLANKS      # Remove superfluous blanks from each command line
setopt HIST_IGNORE_SPACE       # Do not record an event starting with a space
setopt HIST_VERIFY             # Do not execute immediately upon history expansion
setopt INC_APPEND_HISTORY      # Write to the history file immediately, not when the shell exits
