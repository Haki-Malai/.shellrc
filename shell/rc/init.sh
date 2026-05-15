# shell/rc/init.sh
case $- in *i*) :;; *) return 0 2>/dev/null || exit 0;; esac

# resolve path
if [ -n "${BASH_SOURCE-}" ]; then _SRC="${BASH_SOURCE[0]}"; elif [ -n "${ZSH_VERSION-}" ]; then _SRC="${(%):-%N}"; else _SRC="$0"; fi
__DIR="$(cd -- "$(dirname -- "$_SRC")" && pwd -P)"
DOTS_ROOT="$(cd -- "$__DIR/../.." && pwd -P)"; export DOTS_ROOT

case "$(uname -s)" in Darwin) DOTS_OS="mac";; Linux) DOTS_OS="linux";; *) DOTS_OS="other";; esac
export DOTS_OS

# load files matching a pattern with shell-native sorted globs
_load_glob() {
  local dir="$1" pat="$2"
  [ -d "$dir" ] || return 0

  if [ -n "${ZSH_VERSION-}" ]; then
    emulate -L zsh
    setopt NULL_GLOB
    local f
    for f in "$dir"/${~pat}; do
      [ -f "$f" ] && . "$f"
    done
    return 0
  fi

  if [ -n "${BASH_VERSION-}" ]; then
    local f nullglob_was_set
    if shopt -q nullglob; then
      nullglob_was_set=0
    else
      nullglob_was_set=1
    fi
    shopt -s nullglob
    for f in "$dir"/$pat; do
      [ -f "$f" ] && . "$f"
    done
    [ "$nullglob_was_set" -eq 0 ] || shopt -u nullglob
    return 0
  fi
}

# ordered modules
_load_glob "$DOTS_ROOT/shell/rc" "[0-8][0-9]-*.sh"
[ "$DOTS_OS" = "linux" ] && _load_glob "$DOTS_ROOT/shell/rc" "90-os-linux.sh"
[ "$DOTS_OS" = "mac"   ] && _load_glob "$DOTS_ROOT/shell/rc" "90-os-macos.sh"
_load_glob "$DOTS_ROOT/shell/rc" "99-local.sh"
_load_glob "$DOTS_ROOT/shell/rc/local.d" "*.sh"   # optional; no error if missing

dots_diag() {
  echo "DOTS_ROOT=$DOTS_ROOT"
  echo "DOTS_OS=$DOTS_OS"
  echo "shell=${ZSH_VERSION:+zsh}${BASH_VERSION:+bash}"
  command -v clip >/dev/null && echo "clip=$(type -p clip 2>/dev/null)"
}

_load_funcs() {
  local base="$1"
  [ -d "$base" ] || return 0

  if [ -n "${ZSH_VERSION-}" ]; then
    emulate -L zsh
    setopt NULL_GLOB
    local f
    for f in "$base"/*.sh "$base"/*/*.sh; do
      [ -f "$f" ] && . "$f"
    done
    return 0
  fi

  if [ -n "${BASH_VERSION-}" ]; then
    local f nullglob_was_set
    if shopt -q nullglob; then
      nullglob_was_set=0
    else
      nullglob_was_set=1
    fi
    shopt -s nullglob
    for f in "$base"/*.sh "$base"/*/*.sh; do
      [ -f "$f" ] && . "$f"
    done
    [ "$nullglob_was_set" -eq 0 ] || shopt -u nullglob
    return 0
  fi
}
_load_funcs "$DOTS_ROOT/shell/functions"
