# shell/rc/init.sh — zsh + bash
case $- in *i*) :;; *) return 0 2>/dev/null || exit 0;; esac

# resolve this file path for bash/zsh
if [ -n "${BASH_SOURCE-}" ]; then _SRC="${BASH_SOURCE[0]}";
elif [ -n "${ZSH_VERSION-}" ]; then _SRC="${(%):-%N}";
else _SRC="$0"; fi

__DIR="$(cd -- "$(dirname -- "$_SRC")" && pwd -P)"
DOTS_ROOT="$(cd -- "$__DIR/../.." && pwd -P)"; export DOTS_ROOT

# OS
case "$(uname -s)" in
  Darwin) DOTS_OS="mac" ;; Linux) DOTS_OS="linux" ;; *) DOTS_OS="other" ;;
esac; export DOTS_OS

# glob-safe loader
_load_glob() {
  [ -n "${ZSH_VERSION-}" ] && setopt local_options no_nomatch
  for f in $1; do [ -e "$f" ] || continue; . "$f"; done
}

# modules (00..89), then OS, then local
_load_glob "$DOTS_ROOT/shell/rc"/[0-8][0-9]-*.sh
[ "$DOTS_OS" = mac ]   && [ -f "$DOTS_ROOT/shell/rc/90-os-macos.sh" ] && . "$DOTS_ROOT/shell/rc/90-os-macos.sh"
[ "$DOTS_OS" = linux ] && [ -f "$DOTS_ROOT/shell/rc/90-os-linux.sh" ] && . "$DOTS_ROOT/shell/rc/90-os-linux.sh"
[ -f "$DOTS_ROOT/shell/rc/99-local.sh" ] && . "$DOTS_ROOT/shell/rc/99-local.sh"
_load_glob "$DOTS_ROOT/shell/rc/local.d/"*.sh

dots_diag() {
  echo "DOTS_ROOT=$DOTS_ROOT"
  echo "DOTS_OS=$DOTS_OS"
  echo "shell=${ZSH_VERSION:+zsh}${BASH_VERSION:+bash}"
  command -v clip >/dev/null 2>&1 && echo "clip=$(command -v clip)" || echo "clip=missing"
  command -v pyenv >/dev/null 2>&1 && echo "pyenv=$(command -v pyenv)" || echo "pyenv=missing"
}
