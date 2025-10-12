# ls color cross-platform
if command -v gls >/dev/null 2>&1; then alias ls='gls --color=auto'
elif [[ ${DOTS_OS} == mac ]]; then alias ls='ls -G'
else alias ls='ls --color=auto'; fi

alias vi='vim'
alias oc='opencommit'
alias grep='grep --exclude-dir={__pycache__,node_modules,.git}'
alias bb='[[ "$DOTS_OS" == mac ]] && sudo shutdown -h now || shutdown 0'
alias bbr='[[ "$DOTS_OS" == mac ]] && sudo shutdown -r now || shutdown -r 0'
