# Exit for non-interactive
[[ $- != *i* ]] && return

# Resolve repo root
__FILE="${BASH_SOURCE[0]}"
__DIR="$(cd -- "$(dirname "$__FILE")" && pwd -P)"
DOTS_ROOT="$(cd -- "$__DIR/../.." && pwd -P)"
export DOTS_ROOT

# OS detect
case "$OSTYPE" in
  darwin*) DOTS_OS="mac" ;;
  linux*)  DOTS_OS="linux" ;;
  *)       DOTS_OS="other" ;;
esac
export DOTS_OS

# Loader
_load_dir() {
  local d="$1"
  shopt -s nullglob
  for f in "$d"/*.sh; do . "$f"; done
  shopt -u nullglob
}

# Ordered modules
_load_dir "$DOTS_ROOT/shell/rc"
# OS overrides at the end
[ "$DOTS_OS" = "linux" ] && [ -f "$DOTS_ROOT/shell/rc/90-os-linux.sh" ] && . "$DOTS_ROOT/shell/rc/90-os-linux.sh"
[ "$DOTS_OS" = "mac"   ] && [ -f "$DOTS_ROOT/shell/rc/90-os-macos.sh" ] && . "$DOTS_ROOT/shell/rc/90-os-macos.sh"

# Local last
[ -f "$DOTS_ROOT/shell/rc/99-local.sh" ] && . "$DOTS_ROOT/shell/rc/99-local.sh"
shopt -s nullglob; for f in "$DOTS_ROOT/shell/rc/local.d"/*.sh; do . "$f"; done; shopt -u nullglob
