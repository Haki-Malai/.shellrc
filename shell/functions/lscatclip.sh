# Concatenate matched files to clipboard; supports git mode or glob patterns
[ -n "${ZSH_VERSION-}" ] && setopt local_options no_aliases
unalias lscatclip 2>/dev/null || true
unset -f lscatclip 2>/dev/null || true
# require shared ignore helpers (loaded by init.sh)
type _shellrc_should_ignore >/dev/null 2>&1 || return 0

lscatclip() {
  local use_git=0 use_diff=0 show_tree=0 max_line_chars="${CLIPFILES_MAX_LINE_CHARS:-250000}" maxdepth="" target_dir="."
  local -a in_pats=() out_pats=() include_terms=()
  local dir_set=0

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
    # path, pattern. If pattern has '/', match path, else match path segments + basename.
    local p="$1" g="$2" base
    base="${p##*/}"
    if [[ "$g" == */* ]]; then
      if [ -n "${ZSH_VERSION-}" ]; then
        [[ "$p" == ${~g} ]]
      else
        [[ "$p" == $g ]]
      fi
    else
      if [ -n "${ZSH_VERSION-}" ]; then
        [[ "$p" == ${~g} ]] || [[ "$p" == */${~g} ]] || [[ "$p" == */${~g}/* ]] || [[ "$base" == ${~g} ]]
      else
        [[ "$p" == $g ]] || [[ "$p" == */$g ]] || [[ "$p" == */$g/* ]] || [[ "$base" == $g ]]
      fi
    fi
  }
  _matches_any() {
    # path, patterns...
    local p="$1"; shift; local g
    for g in "$@"; do _match_glob "$p" "$g" && return 0; done
    return 1
  }
  _file_contains_any() {
    # file, needles...
    local f="$1"; shift; local needle
    [ -f "$f" ] || return 1
    command grep -Iq . -- "$f" || return 1
    for needle in "$@"; do
      [ -n "$needle" ] || continue
      command grep -Fq -e "$needle" -- "$f" && return 0
    done
    return 1
  }

  # Parse args
  while [ $# -gt 0 ]; do
    case "$1" in
      --git) use_git=1 ;;
      --diff) use_git=1; use_diff=1 ;;
      --glob) shift; [ -n "${1-}" ] || { echo "missing pattern for --glob" >&2; return 2; }; in_pats+=("$1") ;;
      --in)   shift; [ -n "${1-}" ] || { echo "missing CSV for --in"  >&2; return 2; }; _append_csv_to_array "$1" in_pats ;;
      --out)  shift; [ -n "${1-}" ] || { echo "missing CSV for --out" >&2; return 2; }; _append_csv_to_array "$1" out_pats ;;
      -i|--includes) shift; [ -n "${1-}" ] || { echo "missing CSV for --includes" >&2; return 2; }; _append_csv_to_array "$1" include_terms ;;
      --tree) show_tree=1 ;;
      -n|--max-depth) shift; [[ "${1-}" =~ ^[0-9]+$ ]] && maxdepth="$1" ;;
      --)
        shift
        break
        ;;
      -h|--help)
        cat <<'USAGE'
Usage: lscatclip [--git] [--diff] [--in "*.ts,*.tsx" ...] [--out "*.md,*.test.ts" ...] [-i CSV|--includes CSV] [-n N|--max-depth N] [DIR]
Aliases:
  --glob PATTERN  Add an include glob (alias of --in)
Defaults:
  If no globs given: --in '*'
Notes:
  - Globs are shell-style, comma-separated. Quote them to avoid expansion.
  - Excludes are applied after collection. Git mode ignores depth.
  - --diff copies files changed in `git diff main` (errors on main branch).
  - --includes filters to files whose contents contain any literal string in the CSV (binary files are skipped).
USAGE
        return 0 ;;
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
  [ ${#in_pats[@]} -gt 0 ] || in_pats=('*')

  _lscatclip__run() {
    local list tmp f g rel selected tree_depth debug
    debug="${LSCATCLIP_DEBUG:-0}"
    list="$(mktemp)" || return 1
    : >"$list"

    if [ "$use_git" -eq 1 ]; then
      git rev-parse --is-inside-work-tree >/dev/null 2>&1 || { echo "not a git repo" >&2; rm -f "$list"; return 1; }
      local repo_root cwd_abs cwd_rel
      repo_root="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
      cwd_abs="$(pwd)"
      if [[ "$cwd_abs" == "$repo_root" ]]; then
        cwd_rel=""
      else
        cwd_rel="${cwd_abs#"$repo_root"/}"
      fi
      if [ "$use_diff" -eq 1 ]; then
        local branch
        branch="$(git symbolic-ref --quiet --short HEAD 2>/dev/null || true)"
        if [ "$branch" = "main" ]; then
          echo "cannot use --diff on main branch" >&2
          rm -f "$list"
          return 1
        fi
        git rev-parse --verify main >/dev/null 2>&1 || { echo "no main branch" >&2; rm -f "$list"; return 1; }
        # newline-separated to avoid subshell issues
        while IFS= read -r f; do
          [ "$debug" -eq 1 ] && echo "diff path: [$f]" >&2
          [ -n "$f" ] || continue
          case "$f" in ./*) f="${f#./}";; esac
          if [ -n "$cwd_rel" ] && [[ "$f" == "$cwd_rel/"* ]]; then
            f="${f#$cwd_rel/}"
          fi
          # filter by includes
          _shellrc_should_ignore "$f" && continue
          if _matches_any "$f" "${in_pats[@]}"; then
            printf '%s\n' "$f" >>"$list"
          fi
        done < <(git diff --name-only --relative main -- .)
      else
        # newline-separated to avoid subshell issues
        while IFS= read -r f; do
          [ "$debug" -eq 1 ] && echo "ls path: [$f]" >&2
          [ -n "$f" ] || continue
          case "$f" in ./*) f="${f#./}";; esac
          if [ -n "$cwd_rel" ] && [[ "$f" == "$cwd_rel/"* ]]; then
            f="${f#$cwd_rel/}"
          fi
          # filter by includes
          _shellrc_should_ignore "$f" && continue
          if _matches_any "$f" "${in_pats[@]}"; then
            printf '%s\n' "$f" >>"$list"
          fi
        done < <(git ls-files)
      fi
      [ "$debug" -eq 1 ] && { echo "collected (git):"; cat "$list" >&2; }
    else
      # Collect with find per include pattern
      _shellrc_find_prune_set
      for g in "${in_pats[@]}"; do
        if [[ "$g" == */* ]]; then
          local path_pat="$g" pwd_prefix
          case "$path_pat" in
            ./*) ;;
            /*)
              pwd_prefix="$(pwd)/"
              if [[ "$path_pat" == "$pwd_prefix"* ]]; then
                path_pat="./${path_pat#$pwd_prefix}"
              fi
              ;;
            *) path_pat="./$path_pat" ;;
          esac
          if [ -n "$maxdepth" ]; then
            find . -maxdepth "$maxdepth" "${_SHELLRC_PRUNE[@]}" \
              -type f -path "$path_pat" -print 2>/dev/null
          else
            find . "${_SHELLRC_PRUNE[@]}" \
              -type f -path "$path_pat" -print 2>/dev/null
          fi
        else
          if [ -n "$maxdepth" ]; then
            find . -maxdepth "$maxdepth" "${_SHELLRC_PRUNE[@]}" \
              -type f -name "$g" -print 2>/dev/null
          else
            find . "${_SHELLRC_PRUNE[@]}" \
              -type f -name "$g" -print 2>/dev/null
          fi
        fi
      done | LC_ALL=C sort -u >"$list"
      [ "$debug" -eq 1 ] && { echo "collected (find):"; cat "$list" >&2; }
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

    selected="$(mktemp)" || { rm -f "$list"; return 1; }
    while IFS= read -r f; do
      case "$f" in ./*) rel="${f#./}";; *) rel="$f";; esac
      [ -n "$rel" ] || continue
      _shellrc_should_ignore "$rel" && continue
      [ -f "$rel" ] || continue
      if [ ${#include_terms[@]} -gt 0 ]; then
        _file_contains_any "$rel" "${include_terms[@]}" || continue
      fi
      printf '%s\n' "$rel"
    done <"$list" >"$selected"

    [ -s "$selected" ] || { echo "no files matched" >&2; rm -f "$list" "$selected"; return 1; }

    tree_depth="$maxdepth"
    if [ -z "$tree_depth" ] || [ "$use_git" -eq 1 ]; then
      tree_depth=0
    fi

    local out; out="$(mktemp)" || { rm -f "$list" "$selected"; return 1; }
    : >"$out"
    if [ "$show_tree" -eq 1 ]; then
      if ! _shellrc_render_tree "$selected" "$tree_depth" "$(pwd)" "FILE TREE" >"$out"; then
        rm -f "$list" "$selected" "$out"
        return 1
      fi
      printf '\n' >>"$out"
    fi

    {
      printf '%s\n' "=== $(pwd) ==="
      while IFS= read -r rel; do
        [ -n "$rel" ] || continue
        if [ -f "$rel" ] && command grep -Iq . -- "$rel"; then
          printf '%s\n' "----- $rel -----"
          cat -- "$rel"
          printf '\n'
        elif [ -f "$rel" ]; then
          printf '%s\n\n' "----- $rel ----- [skipped binary]"
        fi
      done <"$selected"
    } >>"$out"

    # stats and copy
    read -r over_count max_len <<EOF
$(LC_ALL=C awk -v m="$max_line_chars" '{l=length($0); if(l>m)c++; if(l>mx)mx=l} END{print (c?c:0), (mx?mx:0)}' "$out" 2>/dev/null)
EOF
    clip <"$out" || { rm -f "$list" "$selected" "$out"; return 1; }
    echo "copied $(wc -l <"$out" | tr -d ' ') lines, $(wc -c <"$out" | tr -d ' ') bytes to clipboard"
    [ "$over_count" -gt 0 ] && echo "warning: $over_count lines exceed ${max_line_chars} (max $max_len)" >&2
    rm -f "$list" "$selected" "$out"
  }

  (
    cd "$target_dir" || exit 1
    _lscatclip__run
  )
  local rc=$?
  unset -f _lscatclip__run 2>/dev/null || true
  return $rc
}
