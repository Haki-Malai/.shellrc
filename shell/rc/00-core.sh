# History + defaults
export EDITOR=vim
export PATH="$PATH:$HOME/.bin"

# Bash-only tweaks
if [ -n "${BASH_VERSION-}" ]; then
  shopt -s checkwinsize histappend cmdhist
  export HISTCONTROL=ignoreboth:erasedups
fi

# zsh history options
if [ -n "${ZSH_VERSION-}" ]; then
  setopt APPEND_HISTORY
  setopt INC_APPEND_HISTORY
  setopt SHARE_HISTORY
  setopt HIST_IGNORE_DUPS
  setopt HIST_FIND_NO_DUPS
fi

# Default to emacs keybindings
set -o emacs
