# Git-tracked tree → clipboard
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
  # associative map portable to zsh/bash
  if [ -n "${ZSH_VERSION-}" ]; then typeset -A printed; else declare -A printed; fi

  {
    printf '%s\n' "=== GIT TREE: $(pwd) ==="
    printf '%s\n' "./"
    git ls-files -z | while IFS= read -r -d '' f; do
      case "$f" in
        .git/*|.git|.venv/*|.venv|venv/*|venv|node_modules/*|node_modules|__pycache__/*|__pycache__|.mypy_cache/*|.mypy_cache|.pytest_cache/*|.pytest_cache|.tox/*|.tox) continue;;
      esac
      IFS='/' read -r -a parts <<<"$f"
      local_path=""
      if [ "${#parts[@]}" -gt 1 ]; then
        for (( i=0; i<${#parts[@]}-1; i++ )); do
          local_path="${local_path:+$local_path/}${parts[i]}"
          if [ -n "$maxdepth" ] && [ $((i+1)) -gt "$maxdepth" ]; then break; fi
          if [ -z "${printed[$local_path]+x}" ]; then
            printed[$local_path]=1
            printf '%*s%s/\n' $(( i*2 )) '' "${parts[i]}"
          fi
        done
      fi
      if [ -z "$maxdepth" ] || [ "${#parts[@]}" -le "$maxdepth" ]; then
        printf '%*s%s\n' $(( (${#parts[@]}-1)*2 )) '' "${parts[-1]}"
      fi
    done
  } >"$out"

  clip <"$out" && echo "copied $(wc -l <"$out" | tr -d ' ') lines, $(wc -c <"$out" | tr -d ' ') bytes to clipboard"
  rm -f "$out"
}

