# Load repo env (template committed, real values ignored)
if [ -f "$DOTS_ROOT/env/env.sh" ]; then
  # shellcheck source=/dev/null
  . "$DOTS_ROOT/env/env.sh"
fi

_shellrc_source_env_file() {
  local file="$1"
  [ -f "$file" ] || return 0
  set -a
  # shellcheck source=/dev/null
  . "$file" >/dev/null 2>&1 || true
  set +a
}

_shellrc_auto_env() {
  local dir file
  dir="$PWD"

  if [ "${_SHELLRC_ENV_DIR-}" = "$dir" ]; then
    return 0
  fi
  _SHELLRC_ENV_DIR="$dir"

  for file in .env .env.local .env.development .env.test; do
    if [ -f "$file" ]; then
      _shellrc_source_env_file "$file"
    fi
  done
}

if [ -n "${ZSH_VERSION-}" ]; then
  autoload -Uz add-zsh-hook 2>/dev/null || true
  add-zsh-hook chpwd _shellrc_auto_env
  _shellrc_auto_env
elif [ -n "${BASH_VERSION-}" ]; then
  if [ -n "${PROMPT_COMMAND-}" ]; then
    PROMPT_COMMAND="_shellrc_auto_env;${PROMPT_COMMAND}"
  else
    PROMPT_COMMAND="_shellrc_auto_env"
  fi
  _shellrc_auto_env
fi
