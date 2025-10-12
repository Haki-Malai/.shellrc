# Concatenate matched files to clipboard; supports git mode or glob patterns
lscatclip() {
  local use_git=0 max_line_chars="${CLIPFILES_MAX_LINE_CHARS:-250000}" maxdepth="" patterns=()

  while [ $# -gt 0 ]; do
    case "$1" in
      --git) use_git=1 ;;
      --glob) shift; [ -n "${1-}" ] || { echo "missing pattern for --glob" >&2; return 2; }; patterns+=("$1") ;;
      -n|--max-depth) shift; [[ "${1-}" =~ ^[0-9]+$ ]] && maxdepth="$1" ;;
      -h|--help)
        cat <<'USAGE'
Usage: lscatclip [--git] [--glob 'PATTERN' ...] [-n N|--max-depth N]
  --git      Git-tracked files order; ignores depth.
  --glob     Recursive glob pattern. Repeatable.
  -n N       Limit recursion depth for --glob mode.
Defaults: --glob '*.py' if none given.
USAGE
        return 0 ;;
      *) echo "unknown arg: $1" >&2; return 2 ;;
    esac; shift
  done
  [ ${#patterns[@]} -gt 0 ] || patterns=('*.py')

  local list out f; list="$(mktemp)" || return 1
  : >"$list"

  if [ "$use_git" -eq 1 ]; then
    git rev-parse --is-inside-work-tree >/dev/null 2>&1 || { echo "not a git repo" >&2; rm -f "$list"; return 1; }
    git ls-files -z >"$list"
  else
    local pat
    for pat in "${patterns[@]}"; do
      if [ -n "$maxdepth" ]; then
        find . -maxdepth "$maxdepth" \
          \( -path './.git' -o -path '*/__pycache__' -o -path '*/.venv' -o -path '*/venv' \
             -o -path '*/node_modules' -o -path '*/.mypy_cache' -o -path '*/.pytest_cache' -o -path '*/.tox' \) -prune -o \
          -type f -name "$pat" -print0 2>/dev/null | sort -z >>"$list"
      else
        find . \
          \( -path './.git' -o -path '*/__pycache__' -o -path '*/.venv' -o -path '*/venv' \
             -o -path '*/node_modules' -o -path '*/.mypy_cache' -o -path '*/.pytest_cache' -o -path '*/.tox' \) -prune -o \
          -type f -name "$pat" -print0 2>/dev/null | sort -z >>"$list"
      fi
    done
    # de-dup
    local tmp; tmp="$(mktemp)" || { rm -f "$list"; return 1; }
    awk -v RS='\0' '!seen[$0]++ { printf "%s\0",$0 }' "$list" >"$tmp" && mv "$tmp" "$list"
  fi

  [ -s "$list" ] || { echo "no files matched" >&2; rm -f "$list"; return 1; }

  out="$(mktemp)" || { rm -f "$list"; return 1; }
  {
    printf '%s\n' "=== $(pwd) ==="
    while IFS= read -r -d '' f; do
      case "$f" in ./*) f="${f#./}";; esac
      if [ -f "$f" ] && grep -Iq . -- "$f"; then
        printf '%s\n' "----- $f -----"
        cat -- "$f"
        printf '\n'
      elif [ -f "$f" ]; then
        printf '%s\n\n' "----- $f ----- [skipped binary]"
      fi
    done <"$list"
  } >"$out"

  # stats
  read -r over_count max_len <<EOF
$(awk -v m="$max_line_chars" '{l=length($0); if(l>m)c++; if(l>mx)mx=l} END{print (c?c:0), (mx?mx:0)}' "$out")
EOF

  clip <"$out" || { rm -f "$list" "$out"; return 1; }
  echo "copied $(wc -l <"$out" | tr -d ' ') lines, $(wc -c <"$out" | tr -d ' ') bytes to clipboard"
  [ "$over_count" -gt 0 ] && echo "warning: $over_count lines exceed ${max_line_chars} (max $max_len)" >&2
  rm -f "$list" "$out"
}

