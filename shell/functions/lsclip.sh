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

  {
    printf '=== GIT TREE: %s ===\n' "$(pwd)"
    printf './\n'
    awk -v maxd="${maxdepth:-0}" -F'/' '
      function indent(n,  s,i){ s=""; for(i=1;i<n;i++) s=s "  "; return s }
      {
        paths[++N]=$0
        n=split($0, seg, "/")
        for (i=1;i<n;i++) {
          d=seg[1]; for (j=2;j<=i;j++) d=d "/" seg[j]
          dirs[d]=1
          children[d SUBSEP seg[i+1]]=1
        }
      }
      END {
        for (k in children) { split(k,a,SUBSEP); cc[a[1]]++ }

        for (idx=1; idx<=N; idx++) {
          path=paths[idx]
          n=split(path, seg, "/")
          cur=""
          for (j=1; j<n; j++) {
            cur=(j==1? seg[1] : cur "/" seg[j])
            if (!(printed_dir[cur])) {
              d=cur; depth=j; name=seg[j]
              while (cc[d]==1) {
                # find sole child name
                nxt=""
                for (k in children) { split(k,a,SUBSEP); if (a[1]==d) { nxt=a[2]; break } }
                if (!((d "/" nxt) in dirs)) break
                name=name "/" nxt
                d=d "/" nxt
                depth++
              }
              if (maxd==0 || depth<=maxd) {
                printf "%s%s/\n", indent(depth), name
              }
              pathdir=""
              for (ii=1; ii<=depth; ii++) {
                pathdir=(ii==1? seg[1] : pathdir "/" seg[ii])
                printed_dir[pathdir]=1
              }
            }
            if (maxd>0 && j>=maxd) break
          }
          if (!(printed_file[path])) {
            if (maxd==0 || n<=maxd) {
              print indent(n) seg[n]
            }
            printed_file[path]=1
          }
        }
      }
    ' "$filtered"
  } >"$out"

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
