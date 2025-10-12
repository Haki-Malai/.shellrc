# shell/rc/init.sh
case $- in *i*) :;; *) return 0 2>/dev/null || exit 0;; esac

# resolve path
if [ -n "${BASH_SOURCE-}" ]; then _SRC="${BASH_SOURCE[0]}"; elif [ -n "${ZSH_VERSION-}" ]; then _SRC="${(%):-%N}"; else _SRC="$0"; fi
__DIR="$(cd -- "$(dirname -- "$_SRC")" && pwd -P)"
DOTS_ROOT="$(cd -- "$__DIR/../.." && pwd -P)"; export DOTS_ROOT

case "$(uname -s)" in Darwin) DOTS_OS="mac";; Linux) DOTS_OS="linux";; *) DOTS_OS="other";; esac
export DOTS_OS

# load files matching a pattern without shell globbing
_load_glob() {
  local dir="$1" pat="$2"
  [ -d "$dir" ] || return 0
  while IFS= read -r -d '' f; do . "$f"; done < <(
    find "$dir" -maxdepth 1 -type f -name "$pat" -print0 2>/dev/null | LC_ALL=C sort -z
  )
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

