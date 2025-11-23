# List file types ranked by line or byte totals.
[ -n "${ZSH_VERSION-}" ] && setopt local_options no_aliases
unalias lstype 2>/dev/null || true
unset -f lstype 2>/dev/null || true

type _shellrc_should_ignore >/dev/null 2>&1 || return 0
type _shellrc_find_prune_set >/dev/null 2>&1 || return 0

lstype() {
  local metric="lines" limit=10 target_dir="."
  local dir_set=0

  while [ $# -gt 0 ]; do
    case "$1" in
      --bytes) metric="bytes" ;;
      --lines) metric="lines" ;;
      -n|--limit)
        shift
        if [ -z "${1-}" ]; then
          echo "missing value for --limit" >&2
          return 2
        fi
        case "$1" in
          *[!0-9]*)
            echo "limit must be an integer >= 0" >&2
            return 2
            ;;
          *)
            limit="$1"
            ;;
        esac
        ;;
      --)
        shift
        break
        ;;
      -h|--help)
        cat <<'USAGE'
Usage: lstype [--lines|--bytes] [-n N|--limit N] [DIR]
Ranks file extensions in a directory (recursively).

Options:
  --lines        Rank by total line count (default)
  --bytes        Rank by total byte size
  -n, --limit N  Show only the top N types (default 10, 0 = all)
USAGE
        return 0
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
    esac
    shift
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

  _lstype__run() {
    local files_tmp agg_tmp sorted_tmp total_tmp
    files_tmp="$(mktemp)" || return 1
    agg_tmp="$(mktemp)" || { rm -f "$files_tmp"; return 1; }
    sorted_tmp="$(mktemp)" || { rm -f "$files_tmp" "$agg_tmp"; return 1; }
    total_tmp="$(mktemp)" || { rm -f "$files_tmp" "$agg_tmp" "$sorted_tmp"; return 1; }

    _shellrc_find_prune_set

    : >"$files_tmp"
    while IFS= read -r -d '' f; do
      [ -n "$f" ] || continue
      local rel ext value
      case "$f" in ./*) rel="${f#./}";; *) rel="$f";; esac
      _shellrc_should_ignore "$rel" && continue
      if [ ! -f "$rel" ]; then
        continue
      fi
      case "$rel" in
        *.*) ext=".${rel##*.}" ;;
        *) ext="[noext]" ;;
      esac
      if [ "$metric" = "bytes" ]; then
        value=$(command wc -c <"$rel" 2>/dev/null || echo 0)
      else
        value=$(command wc -l <"$rel" 2>/dev/null || echo 0)
      fi
      [ -n "$value" ] || value=0
      printf '%s\t%s\n' "$ext" "$value" >>"$files_tmp"
    done < <(find . "${_SHELLRC_PRUNE[@]}" -type f -print0 2>/dev/null)

    if [ ! -s "$files_tmp" ]; then
      echo "no files found" >&2
      rm -f "$files_tmp" "$agg_tmp" "$sorted_tmp" "$total_tmp"
      return 1
    fi

    : >"$agg_tmp"
    LC_ALL=C awk -F'\t' -v out="$agg_tmp" -v total_out="$total_tmp" '
      {
        counts[$1]+=$2
        total+=$2
      }
      END {
        for (k in counts) {
          printf "%s\t%s\n", counts[k], k >> out
        }
        if (total_out != "") {
          printf "%s\n", total > total_out
        }
      }
    ' "$files_tmp"

    LC_ALL=C sort -k1,1nr -k2,2 "$agg_tmp" >"$sorted_tmp"

    local top_tmp limit_text
    top_tmp="$(mktemp)" || {
      rm -f "$files_tmp" "$agg_tmp" "$sorted_tmp" "$total_tmp"
      return 1
    }

    if [ "$limit" -gt 0 ] 2>/dev/null; then
      head -n "$limit" "$sorted_tmp" >"$top_tmp"
      limit_text="$limit"
    else
      cat "$sorted_tmp" >"$top_tmp"
      limit_text="all"
    fi

    local total
    total=$(cat "$total_tmp" 2>/dev/null)
    [ -n "$total" ] || total=0

    {
      printf '# top %s file types by %s\n' "$limit_text" "$metric"
      printf '# total %s: %s\n' "$metric" "$total"
      printf 'count\ttype\n'
      cat "$top_tmp"
    }

    rm -f "$files_tmp" "$agg_tmp" "$sorted_tmp" "$total_tmp" "$top_tmp"
  }

  (
    cd "$target_dir" || exit 1
    _lstype__run
  )
  local status=$?
  unset -f _lstype__run 2>/dev/null || true
  return $status
}
