# Shared tree rendering helper for lsclip / lscatclip
[ -n "${ZSH_VERSION-}" ] && setopt local_options no_aliases
unset -f _shellrc_render_tree 2>/dev/null || true

_shellrc_render_tree() {
  local list="$1" depth="${2:-0}" root="${3:-}" label="${4:-GIT TREE}"
  [ -n "$root" ] || root="$(pwd)"
  [ -f "$list" ] || return 1
  case "$depth" in
    "" ) depth=0 ;;
  esac

  printf '=== %s: %s ===\n' "$label" "$root"
  printf './\n'

  LC_ALL=C awk -v maxd="$depth" -F'/' '
    function indent(n, s, i){ s=""; for(i=1;i<n;i++) s=s "  "; return s }
    {
      path=$0
      if (path == "" || path == ".") next
      gsub(/^\.\/+/, "", path)
      if (path == "") next
      paths[++N]=path
      n=split(path, seg, "/")
      for (i=1; i<n; i++) {
        d=seg[1]
        for (j=2; j<=i; j++) d=d "/" seg[j]
        dirs[d]=1
        children[d SUBSEP seg[i+1]]=1
      }
    }
    END {
      if (N == 0) exit 0
      for (k in children) {
        split(k, a, SUBSEP)
        cc[a[1]]++
      }
      for (idx=1; idx<=N; idx++) {
        path=paths[idx]
        n=split(path, seg, "/")
        cur=""
        for (j=1; j<n; j++) {
          cur=(j==1 ? seg[1] : cur "/" seg[j])
          if (!(printed_dir[cur])) {
            d=cur
            depth=j
            name=seg[j]
            while (cc[d]==1) {
              nxt=""
              for (k in children) {
                split(k, a, SUBSEP)
                if (a[1]==d) {
                  nxt=a[2]
                  break
                }
              }
              if (nxt=="") break
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
              pathdir=(ii==1 ? seg[1] : pathdir "/" seg[ii])
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
  ' "$list"
}
