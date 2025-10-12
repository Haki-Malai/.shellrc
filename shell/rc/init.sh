case $- in *i*) :;; *) return 0 2>/dev/null || exit 0;; esac

# Detect current file path in bash and zsh
if [ -n "${BASH_SOURCE-}" ]; then _SRC="${BASH_SOURCE[0]}"
elif [ -n "${ZSH_VERSION-}" ]; then _SRC="${(%):-%N}"
else _SRC="$0"; fi

# Resolve repo root
__DIR="$(cd -- "$(dirname -- "$_SRC")" && pwd -P)"
DOTS_ROOT="$(cd -- "$__DIR/../.." && pwd -P)"
export DOTS_ROOT

# OS detect
case "$(uname -s)" in
  Darwin) DOTS_OS="mac" ;;
  Linux)  DOTS_OS="linux" ;;
  *)      DOTS_OS="other" ;;
esac
export DOTS_OS

# Safe directory loader for both bash/zsh
_load_dir() {
  dir="$1"
  # In zsh, avoid NOMATCH errors for empty globs
  if [ -n "${ZSH_VERSION-}" ]; then setopt local_options no_nomatch; fi
  for f in "$dir"/*.sh; do [ -e "$f" ] || continue; . "$f"; done
}

# Load ordered modules
_load_dir "$DOTS_ROOT/shell/rc"

# OS overrides
[ "$DOTS_OS" = "linux" ] && [ -f "$DOTS_ROOT/shell/rc/90-os-linux.sh" ] && . "$DOTS_ROOT/shell/rc/90-os-linux.sh"
[ "$DOTS_OS" = "mac"   ] && [ -f "$DOTS_ROOT/shell/rc/90-os-macos.sh" ] && . "$DOTS_ROOT/shell/rc/90-os-macos.sh"

# Local last
[ -f "$DOTS_ROOT/shell/rc/99-local.sh" ] && . "$DOTS_ROOT/shell/rc/99-local.sh"
if [ -n "${ZSH_VERSION-}" ]; then setopt local_options no_nomatch; fi
for f in "$DOTS_ROOT/shell/rc/local.d/"*.sh; do [ -e "$f" ] || continue; . "$f"; done
