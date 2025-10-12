# history and defaults
[ -n "${BASH_VERSION-}" ] && shopt -s checkwinsize histappend cmdhist
[ -n "${ZSH_VERSION-}" ] && setopt APPEND_HISTORY INC_APPEND_HISTORY SHARE_HISTORY
export HISTCONTROL=ignoreboth:erasedups
export EDITOR=vim
export PATH="$PATH:$HOME/.bin"
