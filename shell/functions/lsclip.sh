# Git-tracked tree → clipboard (compact, POSIX)
[ -n "${ZSH_VERSION-}" ] && setopt local_options no_aliases
unalias lsclip 2>/dev/null || true
unset -f lsclip 2>/dev/null || true
type _shellrc_should_ignore >/dev/null 2>&1 || return 0

lsclip() {
  git rev-parse --is-inside-work-tree >/dev/null 2>&1 || { echo "not a git repo" >&2; return 1; }

  local maxdepth=""
  while [ $# -gt 0 ]; do
    case "$1" in
      -n|--max-depth) shift; [[ "${1-}" =~ ^[0-9]+$ ]] && maxdepth="$1" ;;
      -h|--help) printf '%s\n' "Usage: lsclip [-n N|--max-depth N]"; return 0 ;;
      *) echo "unknown arg: $1" >&2; return 2 ;;
    esac; shift
  done

  _ignored_ancestor() {
    local p="$1" cur
    cur="$p"
    while :; do
      _shellrc_should_ignore "$cur" && return 0
      case "$cur" in
        */*) cur="${cur%/*}" ;;
        *) break ;;
      esac
    done
    return 1
  }

  local all filtered out
  all="$(mktemp)" || return 1
  filtered="$(mktemp)" || { rm -f "$all"; return 1; }
  out="$(mktemp)" || { rm -f "$all" "$filtered"; return 1; }

  git ls-files -z | tr '\0' '\n' | LC_ALL=C sort >"$all"

  while IFS= read -r p; do
    [ -n "$p" ] || continue
    _ignored_ancestor "$p" && continue
    printf '%s\n' "$p"
  done <"$all" >"$filtered"

  if ! _shellrc_render_tree "$filtered" "${maxdepth:-0}" "$(pwd)" "GIT TREE" >"$out"; then
    rm -f "$all" "$filtered" "$out"
    return 1
  fi

  if clip <"$out"; then
    printf 'copied %s lines, %s bytes to clipboard\n' "$(wc -l <"$out" | tr -d ' ')" "$(wc -c <"$out" | tr -d ' ')"
    rm -f "$all" "$filtered" "$out"
    return 0
  else
    echo "clipboard backend not available" >&2
    rm -f "$all" "$filtered" "$out"
    return 1
  fi
}
