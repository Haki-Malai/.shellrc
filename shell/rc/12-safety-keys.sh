if [ -n "${ZSH_VERSION-}" ]; then
  typeset -g _SHELLRC_KEYMAP_BASELINE
  _SHELLRC_KEYMAP_BASELINE="${KEYMAP:-emacs}"
  autoload -Uz add-zsh-hook
  _shellrc_restore_keys() {
    [[ ${KEYMAP:-} = vi(ins|cmd) ]] && bindkey -e
  }
  add-zsh-hook precmd _shellrc_restore_keys
fi
