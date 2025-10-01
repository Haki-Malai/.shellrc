[ -n "${BASH_VERSION-}" ] || return 0

function lscatclip {
  local use_git=0
  local max_line_chars="${CLIPFILES_MAX_LINE_CHARS:-250000}"
  local -a patterns=()
  local maxdepth=""   # unlimited by default

  while [ $# -gt 0 ]; do
    case "$1" in
      --git) use_git=1 ;;
      --glob) shift; [ -n "${1-}" ] || { echo "missing pattern for --glob" >&2; return 2; }; patterns+=("$1") ;;
      -n|--max-depth)
        shift
        if [ -n "${1-}" ] && [[ "$1" =~ ^[0-9]+$ ]]; then
          maxdepth="$1"
          shift
          continue
        fi
        # No numeric value provided -> leave unlimited
        ;;
      -h|--help)
        cat <<'USAGE'
Usage: lscatcli [--git] [--glob 'PATTERN' ...] [-n N|--max-depth N]
  --git                Use Git-tracked files (preserve git order). Depth ignored.
  --glob 'PATTERN'     Recursive glob. Repeatable. E.g. '*.py' '*.tf' '*ml' '*ini'
  -n N                 Limit recursion depth (find -maxdepth N). Omit for unlimited.
Defaults:
  If no flags given: --glob '*.py'
Behavior:
  - Recurses, prunes .git, __pycache__, venvs, node_modules, caches.
  - Skips binaries.
  - Clipboard backend autodetected (wl-copy, xclip, xsel, clip.exe).
  - Warns if any line exceeds CLIPFILES_MAX_LINE_CHARS (default 250000).
USAGE
        return 0 ;;
      *) echo "unknown arg: $1" >&2; return 2 ;;
    esac; shift
  done
  [ ${#patterns[@]} -gt 0 ] || patterns=('*.py')

  local copier=""
  if command -v wl-copy >/dev/null 2>&1; then copier="wl-copy"
  elif command -v xclip >/dev/null 2>&1; then copier="xclip -selection clipboard"
  elif command -v xsel  >/dev/null 2>&1; then copier="xsel --clipboard --input"
  elif command -v clip.exe >/dev/null 2>&1; then copier="clip.exe"
  else echo "install wl-copy or xclip or xsel" >&2; return 1; fi

  local list tmp
  list="$(mktemp)" || return 1
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
    tmp="$(mktemp)" || { rm -f "$list"; return 1; }
    awk -v RS='\0' ' !seen[$0]++ { printf "%s\0",$0 } ' "$list" >"$tmp" && mv "$tmp" "$list"
  fi

  [ -s "$list" ] || { echo "no files matched" >&2; rm -f "$list"; return 1; }

  local out f
  out="$(mktemp)" || { rm -f "$list"; return 1; }
  {
    builtin printf '%s\n' "=== $(pwd) ==="
    while IFS= read -r -d '' f; do
      case "$f" in ./*) f="${f#./}";; esac
      if [ -f "$f" ] && grep -Iq . -- "$f"; then
        builtin printf '%s\n' "----- $f -----"
        cat -- "$f"
        builtin printf '\n'
      elif [ -f "$f" ]; then
        builtin printf '%s\n\n' "----- $f ----- [skipped binary]"
      fi
    done <"$list"
  } >"$out"

  read -r over_count max_len <<EOF
$(awk -v m="$max_line_chars" '{l=length($0); if(l>m)c++; if(l>mx)mx=l} END{print (c?c:0), (mx?mx:0)}' "$out")
EOF

  case "$copier" in
    "wl-copy") wl-copy <"$out" ;;
    "xsel --clipboard --input") xsel --clipboard --input <"$out" ;;
    "clip.exe") clip.exe <"$out" ;;
    *) xclip -selection clipboard <"$out" ;;
  esac

  local lines bytes
  lines=$(wc -l <"$out" | tr -d ' ')
  bytes=$(wc -c <"$out" | tr -d ' ')
  echo "copied $lines lines, $bytes bytes to clipboard"
  [ "$over_count" -gt 0 ] && echo "warning: $over_count lines exceed ${max_line_chars} chars (max seen $max_len). set CLIPFILES_MAX_LINE_CHARS to adjust." >&2

  rm -f "$list" "$out"
}

# Git tree → clipboard (Git-tracked files only).
# Usage: gitreeclip [-n N]    # N = max depth, omit for unlimited
# Prunes: .git, venv/.venv, node_modules, __pycache__, .mypy_cache, .pytest_cache, .tox
function lsclip {
  [ -n "${BASH_VERSION-}" ] || return 0
  git rev-parse --is-inside-work-tree >/dev/null 2>&1 || { echo "not a git repo" >&2; return 1; }

  local maxdepth=""

  while [ $# -gt 0 ]; do
    case "$1" in
      -n|--max-depth) shift; [[ "${1-}" =~ ^[0-9]+$ ]] && maxdepth="$1" ;;
      -h|--help)
        cat <<'USAGE'
Usage: gitreeclip [-n N|--max-depth N]
  Copies a clean directory tree (Git-tracked files only) to the clipboard.
  -n N   Limit tree depth to N. Omit for full depth.
USAGE
        return 0 ;;
      *) echo "unknown arg: $1" >&2; return 2 ;;
    esac; shift
  done

  # Clipboard backend
  local copier=""
  if command -v wl-copy >/dev/null 2>&1; then copier="wl-copy"
  elif command -v xclip >/dev/null 2>&1; then copier="xclip -selection clipboard"
  elif command -v xsel  >/dev/null 2>&1; then copier="xsel --clipboard --input"
  elif command -v clip.exe >/dev/null 2>&1; then copier="clip.exe"
  else echo "install wl-copy or xclip or xsel" >&2; return 1; fi

  # Build tree from git-tracked files
  local out f
  out="$(mktemp)" || return 1

  # assoc to track which directories already printed
  declare -A printed=()

  {
    builtin printf '%s\n' "=== GIT TREE: $(pwd) ==="
    builtin printf '%s\n' "./"
    git ls-files -z \
    | while IFS= read -r -d '' f; do
        # prune noisy paths even if tracked
        case "$f" in
          .git/*|.git|.venv/*|.venv|venv/*|venv|node_modules/*|node_modules|__pycache__/*|__pycache__|.mypy_cache/*|.mypy_cache|.pytest_cache/*|.pytest_cache|.tox/*|.tox)
            continue;;
        esac

        # split path
        IFS='/' read -r -a parts <<<"$f"
        local_path=""
        # print directories up to file's parent
        if [ "${#parts[@]}" -gt 1 ]; then
          for (( i=0; i<${#parts[@]}-1; i++ )); do
            local_path="${local_path:+$local_path/}${parts[i]}"
            # depth = i+1; enforce maxdepth if set
            if [ -n "$maxdepth" ] && [ $((i+1)) -gt "$maxdepth" ]; then
              break
            fi
            if [ -z "${printed[$local_path]+x}" ]; then
              printed[$local_path]=1
              # indent: 2 spaces per level-1
              builtin printf '%*s' $(( (i)*2 )) ''
              builtin printf '%s/\n' "${parts[i]}"
            fi
          done
        fi

        # file line
        if [ -z "$maxdepth" ] || [ "${#parts[@]}" -le "$maxdepth" ]; then
          # indent equals 2 spaces per directory level
          builtin printf '%*s' $(( (${#parts[@]}-1)*2 )) ''
          builtin printf '%s\n' "${parts[-1]}"
        fi
      done
  } >"$out"

  # Copy
  case "$copier" in
    "wl-copy") wl-copy <"$out" ;;
    "xsel --clipboard --input") xsel --clipboard --input <"$out" ;;
    "clip.exe") clip.exe <"$out" ;;
    *) xclip -selection clipboard <"$out" ;;
  esac

  local lines bytes
  lines=$(wc -l <"$out" | tr -d ' ')
  bytes=$(wc -c <"$out" | tr -d ' ')
  echo "copied $lines lines, $bytes bytes to clipboard"
  rm -f "$out"
}

