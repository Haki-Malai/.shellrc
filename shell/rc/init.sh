# shell/rc/init.sh
case $- in *i*) :;; *) return 0 2>/dev/null || exit 0;; esac

# Resolve this file path for bash/zsh
if [ -n "${BASH_SOURCE-}" ]; then _SRC="${BASH_SOURCE[0]}";
elif [ -n "${ZSH_VERSION-}" ]; then _SRC="${(%):-%N}";
else _SRC="$0"; fi

__DIR="$(cd -- "$(dirname -- "$_SRC")" && pwd -P)"
DOTS_ROOT="$(cd -- "$__DIR/../.." && pwd -P)"
export DOTS_ROOT

# Fallback if something went wrong
[ -d "$DOTS_ROOT/shell/rc" ] || DOTS_ROOT="$(cd -- "$HOME/.shellrc" 2>/dev/null && pwd -P || echo "$HOME/.shellrc")"

case "$(uname -s)" in
  Darwin) DOTS_OS="mac" ;; Linux) DOTS_OS="linux" ;; *) DOTS_OS="other" ;;
esac
export DOTS_OS

# Glob loader safe for zsh
_load_glob() {
  [ -n "${ZSH_VERSION-}" ] && setopt local_options no_nomatch
  for f in $1; do [ -e "$f" ] || continue; . "$f"; done
}

# Common modules 00..89
_load_glob "$DOTS_ROOT/shell/rc"/[0-8][0-9]-*.sh

# OS-specific
[ "$DOTS_OS" = "linux" ] && [ -f "$DOTS_ROOT/shell/rc/90-os-linux.sh" ] && . "$DOTS_ROOT/shell/rc/90-os-linux.sh"
[ "$DOTS_OS" = "mac"   ] && [ -f "$DOTS_ROOT/shell/rc/90-os-macos.sh" ] && . "$DOTS_ROOT/shell/rc/90-os-macos.sh"

# Local last
[ -f "$DOTS_ROOT/shell/rc/99-local.sh" ] && . "$DOTS_ROOT/shell/rc/99-local.sh"
_load_glob "$DOTS_ROOT/shell/rc/local.d/"*.sh

# Quick diag
dots_diag() {
  echo "DOTS_ROOT=$DOTS_ROOT"
  echo "DOTS_OS=$DOTS_OS"
  echo "shell=${ZSH_VERSION:+zsh}${BASH_VERSION:+bash}"
  command -v clip >/dev/null && echo "clip=$(whence -p clip 2>/dev/null || type -p clip)"
}
