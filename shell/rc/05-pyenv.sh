# shell/rc/05-pyenv.sh
# Ensure pyenv shims win over /usr/bin/python3

# Only run in interactive shells (init.sh already does this, but keep safe)
case $- in *i*) :;; *) return 0 2>/dev/null || exit 0;; esac

export PYENV_ROOT="${PYENV_ROOT:-$HOME/.pyenv}"

# If pyenv exists, set PATH so shims are first and initialize it.
if command -v pyenv >/dev/null 2>&1; then
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
