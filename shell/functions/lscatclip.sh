# Concatenate matched files to clipboard; supports git mode or glob patterns
[ -n "${ZSH_VERSION-}" ] && setopt local_options no_aliases
unalias lscatclip 2>/dev/null || true
unset -f lscatclip 2>/dev/null || true
# require shared ignore helpers (loaded by init.sh)
type _shellrc_should_ignore >/dev/null 2>&1 || return 0

lscatclip() {
  local use_git=0 max_line_chars="${CLIPFILES_MAX_LINE_CHARS:-250000}" maxdepth=""
  local -a in_pats=() out_pats=()

  _append_csv_to_array() {
    # $1 = csv string, $2 = name of array to append to
    local csv="$1" __n="$2" line
    while IFS= read -r line; do
      [ -n "$line" ] || continue
      eval "$__n+=(\"\$line\")"
    done <<EOF
$(printf '%s' "$csv" | tr ',' '\n' | sed 's/^[[:space:]]\+//; s/[[:space:]]\+$//')
EOF
  }
  _match_glob() {
    # path, pattern. If pattern has '/', match path, else basename.
    local p="$1" g="$2" base
    base="${p##*/}"
    if [[ "$g" == */* ]]; then [[ "$p" == $g ]]; else [[ "$base" == $g ]]; fi
  }
  _matches_any() {
    # path, patterns...
    local p="$1"; shift; local g
    for g in "$@"; do _match_glob "$p" "$g" && return 0; done
    return 1
  }

  # Parse args
  while [ $# -gt 0 ]; do
    case "$1" in
      --git) use_git=1 ;;
      --glob) shift; [ -n "${1-}" ] || { echo "missing pattern for --glob" >&2; return 2; }; in_pats+=("$1") ;;
      --in)   shift; [ -n "${1-}" ] || { echo "missing CSV for --in"  >&2; return 2; }; _append_csv_to_array "$1" in_pats ;;
      --out)  shift; [ -n "${1-}" ] || { echo "missing CSV for --out" >&2; return 2; }; _append_csv_to_array "$1" out_pats ;;
      -n|--max-depth) shift; [[ "${1-}" =~ ^[0-9]+$ ]] && maxdepth="$1" ;;
      -h|--help)
        cat <<'USAGE'
Usage: lscatclip [--git] [--in "*.ts,*.tsx" ...] [--out "*.md,*.test.ts" ...] [-n N|--max-depth N]
Aliases:
  --glob PATTERN  Add an include glob (alias of --in)
Defaults:
  If no includes given: --in '*.py'
Notes:
  - Globs are shell-style, comma-separated. Quote them to avoid expansion.
  - Excludes are applied after collection. Git mode ignores depth.
USAGE
        return 0 ;;
      *) echo "unknown arg: $1" >&2; return 2 ;;
    esac; shift
  done
  [ ${#in_pats[@]} -gt 0 ] || in_pats=('*')

  local list tmp f g rel
  list="$(mktemp)" || return 1
  : >"$list"

  if [ "$use_git" -eq 1 ]; then
    git rev-parse --is-inside-work-tree >/dev/null 2>&1 || { echo "not a git repo" >&2; rm -f "$list"; return 1; }
    # newline-separated to avoid subshell issues
    while IFS= read -r f; do
      # filter by includes
      _shellrc_should_ignore "$f" && continue
      if _matches_any "$f" "${in_pats[@]}"; then
        printf '%s\n' "$f" >>"$list"
      fi
    done < <(git ls-files)
  else
    # Collect with find per include pattern
    for g in "${in_pats[@]}"; do
      if [ -n "$maxdepth" ]; then
        find . -maxdepth "$maxdepth" $(_shellrc_find_prune) \
          -type f -name "$g" -print 2>/dev/null
      else
        find . $(_shellrc_find_prune) \
          -type f -name "$g" -print 2>/dev/null
      fi
    done | LC_ALL=C sort -u >"$list"
  fi

  # Apply excludes
  if [ ${#out_pats[@]} -gt 0 ]; then
    tmp="$(mktemp)" || { rm -f "$list"; return 1; }
    while IFS= read -r f; do
      rel="${f#./}"
      if _matches_any "$rel" "${out_pats[@]}"; then
        continue
      fi
      printf '%s\n' "$f"
    done <"$list" >"$tmp"
    mv "$tmp" "$list"
  fi

  [ -s "$list" ] || { echo "no files matched" >&2; rm -f "$list"; return 1; }

  local out; out="$(mktemp)" || { rm -f "$list"; return 1; }
  {
    printf '%s\n' "=== $(pwd) ==="
    while IFS= read -r f; do
      case "$f" in ./*) rel="${f#./}";; *) rel="$f";; esac
      _shellrc_should_ignore "$rel" && continue
      if [ -f "$rel" ] && grep -Iq . -- "$rel"; then
        printf '%s\n' "----- $rel -----"
        cat -- "$rel"
        printf '\n'
      elif [ -f "$rel" ]; then
        printf '%s\n\n' "----- $rel ----- [skipped binary]"
      fi
    done <"$list"
  } >"$out"

  # stats and copy
  read -r over_count max_len <<EOF
$(LC_ALL=C awk -v m="$max_line_chars" '{l=length($0); if(l>m)c++; if(l>mx)mx=l} END{print (c?c:0), (mx?mx:0)}' "$out" 2>/dev/null)
EOF
  clip <"$out" || { rm -f "$list" "$out"; return 1; }
  echo "copied $(wc -l <"$out" | tr -d ' ') lines, $(wc -c <"$out" | tr -d ' ') bytes to clipboard"
  [ "$over_count" -gt 0 ] && echo "warning: $over_count lines exceed ${max_line_chars} (max $max_len)" >&2
  rm -f "$list" "$out"
}