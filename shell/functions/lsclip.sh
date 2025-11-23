# Git-tracked tree → clipboard (compact, POSIX)
[ -n "${ZSH_VERSION-}" ] && setopt local_options no_aliases
unalias lsclip 2>/dev/null || true
unset -f lsclip 2>/dev/null || true
type _shellrc_should_ignore >/dev/null 2>&1 || return 0

lsclip() {
  local maxdepth="" target_dir="."
  local dir_set=0
  while [ $# -gt 0 ]; do
    case "$1" in
      -n|--max-depth) shift; [[ "${1-}" =~ ^[0-9]+$ ]] && maxdepth="$1" ;;
      -h|--help) printf '%s\n' "Usage: lsclip [-n N|--max-depth N] [DIR]"; return 0 ;;
      --) shift; break ;;
      -*)
        echo "unknown arg: $1" >&2
        return 2
        ;;
      *)
        if [ "$dir_set" -eq 0 ]; then
          target_dir="$1"
          dir_set=1
        else
          echo "unknown arg: $1" >&2
          return 2
        fi
        ;;
    esac; shift
  done

  if [ $# -gt 0 ]; then
    if [ "$dir_set" -eq 0 ]; then
      target_dir="$1"
      shift
    else
      echo "unknown arg: $1" >&2
      return 2
    fi
  fi

  if [ $# -gt 0 ]; then
    echo "unknown arg: $1" >&2
    return 2
  fi

  [ -d "$target_dir" ] || { echo "no such directory: $target_dir" >&2; return 1; }

  (
    cd "$target_dir" || exit 1

    git rev-parse --is-inside-work-tree >/dev/null 2>&1 || { echo "not a git repo" >&2; exit 1; }

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
    all="$(mktemp)" || exit 1
    filtered="$(mktemp)" || { rm -f "$all"; exit 1; }
    out="$(mktemp)" || { rm -f "$all" "$filtered"; exit 1; }

    git ls-files -z | tr '\0' '\n' | LC_ALL=C sort >"$all"

    while IFS= read -r p; do
      [ -n "$p" ] || continue
      _ignored_ancestor "$p" && continue
      printf '%s\n' "$p"
    done <"$all" >"$filtered"

    if ! _shellrc_render_tree "$filtered" "${maxdepth:-0}" "$(pwd)" "GIT TREE" >"$out"; then
      rm -f "$all" "$filtered" "$out"
      exit 1
    fi

    if clip <"$out"; then
      printf 'copied %s lines, %s bytes to clipboard\n' "$(wc -l <"$out" | tr -d ' ')" "$(wc -c <"$out" | tr -d ' ')"
      rm -f "$all" "$filtered" "$out"
      exit 0
    else
      echo "clipboard backend not available" >&2
      rm -f "$all" "$filtered" "$out"
      exit 1
    fi
  )
}
