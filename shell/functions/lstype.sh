# List file types ranked by line or byte totals.
[ -n "${ZSH_VERSION-}" ] && setopt local_options no_aliases
unalias lstype 2>/dev/null || true
unset -f lstype 2>/dev/null || true

type _shellrc_should_ignore >/dev/null 2>&1 || return 0

lstype() {
  local metric="lines" limit=10 target_dir="."
  local dir_set=0 lstype_status=0
  local _lstype_restore_xtrace=0 _lstype_restore_verbose=0

  case $- in *x*) _lstype_restore_xtrace=1 ;; esac
  case $- in *v*) _lstype_restore_verbose=1 ;; esac

  { set +o xtrace +o verbose; } >/dev/null 2>&1 || { set +x +v; } >/dev/null 2>&1 || true

  while :; do
    while [ $# -gt 0 ]; do
      case "$1" in
        --bytes) metric="bytes" ;;
        --lines) metric="lines" ;;
        -n|--limit)
          shift
          if [ -z "${1-}" ]; then
            echo "missing value for --limit" >&2
            lstype_status=2
            break 2
          fi
          case "$1" in
            *[!0-9]*)
              echo "limit must be an integer >= 0" >&2
              lstype_status=2
              break 2
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
          lstype_status=0
          break 2
          ;;
        *)
          if [ "$dir_set" -eq 0 ]; then
            target_dir="$1"
            dir_set=1
          else
            echo "unknown arg: $1" >&2
            lstype_status=2
            break 2
          fi
          ;;
      esac
      shift
    done

    if [ "$lstype_status" -ne 0 ]; then
      break
    fi

    if [ $# -gt 0 ]; then
      if [ "$dir_set" -eq 0 ]; then
        target_dir="$1"
        shift
      else
        echo "unknown arg: $1" >&2
        lstype_status=2
        break
      fi
    fi

    if [ $# -gt 0 ]; then
      echo "unknown arg: $1" >&2
      lstype_status=2
      break
    fi

    if [ ! -d "$target_dir" ]; then
      echo "no such directory: $target_dir" >&2
      lstype_status=1
      break
    fi

    _lstype__run() {
      if [ -n "${ZSH_VERSION-}" ]; then
        setopt localoptions noxtrace noverbose
      else
        { set +o xtrace +o verbose; } >/dev/null 2>&1 || { set +x +v; } >/dev/null 2>&1 || true
      fi

      local py ignore_globs=""
      if command -v python3 >/dev/null 2>&1; then
        py="python3"
      elif command -v python >/dev/null 2>&1; then
        py="python"
      else
        echo "python is required for lstype" >&2
        return 1
      fi

      if [ "${#_SHELLRC_IGNORE_GLOBS[@]:-0}" -gt 0 ] 2>/dev/null; then
        ignore_globs=$(printf '%s\n' "${_SHELLRC_IGNORE_GLOBS[@]}")
      fi

      LSTYPE_METRIC="$metric" \
      LSTYPE_LIMIT="$limit" \
      LSTYPE_NOEXT="[noext]" \
      LSTYPE_IGNORE_GLOBS="$ignore_globs" \
        "$py" - <<'PY'
import fnmatch
import os
import sys

metric = os.environ.get("LSTYPE_METRIC", "lines")
limit_env = os.environ.get("LSTYPE_LIMIT", "10")
noext_label = os.environ.get("LSTYPE_NOEXT", "[noext]")
ignore_globs_raw = os.environ.get("LSTYPE_IGNORE_GLOBS", "")
ignore_globs = [g for g in ignore_globs_raw.splitlines() if g]

try:
    limit = int(limit_env)
except ValueError:
    limit = 10


def should_ignore(path: str) -> bool:
    return any(fnmatch.fnmatch(path, pat) for pat in ignore_globs)


counts = {}
total = 0

for dirpath, dirnames, filenames in os.walk("."):
    rel_dir = dirpath[2:] if dirpath.startswith("./") else ("" if dirpath == "." else dirpath)

    dirnames[:] = [
        d
        for d in dirnames
        if not should_ignore(f"{rel_dir + '/' if rel_dir else ''}{d}")
    ]

    for name in filenames:
        rel = f"{rel_dir + '/' if rel_dir else ''}{name}"
        if should_ignore(rel):
            continue
        full_path = os.path.join(dirpath, name)
        if not os.path.isfile(full_path):
            continue

        if "." in os.path.basename(name):
            ext = "." + name.rsplit(".", 1)[-1]
        else:
            ext = noext_label

        try:
            if metric == "bytes":
                val = os.path.getsize(full_path)
            else:
                with open(full_path, "rb") as fh:
                    val = sum(buf.count(b"\n") for buf in iter(lambda: fh.read(8192), b""))
        except OSError:
            continue

        counts[ext] = counts.get(ext, 0) + val
        total += val


if not counts:
    sys.stderr.write("no files found\n")
    sys.exit(1)

items = sorted(counts.items(), key=lambda kv: (-kv[1], kv[0]))
if limit > 0:
    items = items[:limit]
    limit_text = str(limit)
else:
    limit_text = "all"

print(f"# top {limit_text} file types by {metric}")
print(f"# total {metric}: {total}")
print("count\ttype")
for ext, val in items:
    print(f"{val}\t{ext}")
PY
    }

    (
      { set +o xtrace +o verbose; } >/dev/null 2>&1 || { set +x +v; } >/dev/null 2>&1 || true
      cd "$target_dir" || exit 1
      _lstype__run
    )
    lstype_status=$?
    unset -f _lstype__run 2>/dev/null || true
    break
  done

  if [ "$_lstype_restore_verbose" -eq 1 ]; then
    set -o verbose 2>/dev/null || set -v 2>/dev/null || true
  fi
  if [ "$_lstype_restore_xtrace" -eq 1 ]; then
    set -o xtrace 2>/dev/null || set -x 2>/dev/null || true
  fi

  return $lstype_status
}
