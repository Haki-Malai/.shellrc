# Git-tracked tree → clipboard
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

  local out f; out="$(mktemp)" || return 1
  # assoc portable
  if [ -n "${ZSH_VERSION-}" ]; then typeset -A printed; else declare -A printed; fi

  {
    printf '%s\n' "=== GIT TREE: $(pwd) ==="
    printf '%s\n' "./"
    # newline-separated list avoids -z and subshell issues
    while IFS= read -r f; do
      _shellrc_should_ignore "$f" && continue

      # split path portable
      local last
      if [ -n "${ZSH_VERSION-}" ]; then
        local -a parts; parts=("${(s:/:)f}")
        last="${parts[-1]}"
      else
        local -a parts; IFS='/' read -r -a parts <<<"$f"
        last="${parts[${#parts[@]}-1]}"
      fi

      # print parent dirs once
      if [ -n "${ZSH_VERSION-}" ]; then
        local i dir; for (( i=1; i<${#parts[@]}; i++ )); do
          dir="${(j:/:)parts[1,i]}"
          if [ -n "$maxdepth" ] && [ $i -gt "$maxdepth" ]; then break; fi
          if [ -z "${printed[$dir]+x}" ]; then printed[$dir]=1; printf '%*s%s/\n' $(( (i-1)*2 )) '' "${parts[i]}"; fi
        done
      else
        local i dir; for (( i=0; i<${#parts[@]}-1; i++ )); do
          dir="${dir:+$dir/}${parts[i]}"
          if [ -n "$maxdepth" ] && [ $((i+1)) -gt "$maxdepth" ]; then break; fi
          if [ -z "${printed[$dir]+x}" ]; then printed[$dir]=1; printf '%*s%s/\n' $(( i*2 )) '' "${parts[i]}"; fi
        done
      fi

      # file line
      if [ -z "$maxdepth" ]; then
        printf '%*s%s\n' $(( (${#parts[@]}-1)*2 )) '' "$last"
      else
        # depth is number of components
        local depth
        if [ -n "${ZSH_VERSION-}" ]; then depth=${#parts[@]}; else depth=${#parts[@]}; fi
        [ "$depth" -le "$maxdepth" ] && printf '%*s%s\n' $(( (depth-1)*2 )) '' "$last"
      fi
    done < <(git ls-files)
  } >"$out"

  clip <"$out" && echo "copied $(wc -l <"$out" | tr -d ' ') lines, $(wc -c <"$out" | tr -d ' ') bytes to clipboard"
  rm -f "$out"
}

