# shell/rc/05-pyenv.sh
# Ensure pyenv shims win over /usr/bin/python3

# Only run in interactive shells (init.sh already does this, but keep safe)
case $- in *i*) :;; *) return 0 2>/dev/null || exit 0;; esac

export PYENV_ROOT="${PYENV_ROOT:-$HOME/.pyenv}"

_shellrc_pyenv_root_is_safe() {
  local root_user current_user

  if [ -d "$PYENV_ROOT" ] && [ ! -w "$PYENV_ROOT" ]; then
    return 1
  fi
  if [ -d "$PYENV_ROOT/shims" ] && [ ! -w "$PYENV_ROOT/shims" ]; then
    return 1
  fi

  if type _shellrc_path_home_user >/dev/null 2>&1 && type _shellrc_current_user >/dev/null 2>&1; then
    root_user="$(_shellrc_path_home_user "$PYENV_ROOT" 2>/dev/null || true)"
    current_user="$(_shellrc_current_user 2>/dev/null || true)"
    if [ -n "$root_user" ] && [ -n "$current_user" ] && [ "$root_user" != "$current_user" ]; then
      return 1
    fi
  fi

  return 0
}

# If pyenv exists, set PATH so shims are first and initialize it.
if command -v pyenv >/dev/null 2>&1 && _shellrc_pyenv_root_is_safe; then
  # Put pyenv on PATH (in case it isn't already)
  export PATH="$PYENV_ROOT/bin:$PATH"

  # Put shims first so `python3` resolves to pyenv
  export PATH="$PYENV_ROOT/shims:$PATH"

  # Initialize for the current shell
  if [ -n "${ZSH_VERSION-}" ]; then
    eval "$(pyenv init - zsh)"
  elif [ -n "${BASH_VERSION-}" ]; then
    eval "$(pyenv init - bash)"
  else
    eval "$(pyenv init -)"
  fi
fi
