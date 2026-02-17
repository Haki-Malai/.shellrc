# Git defaults:
# - disable pager output by default
# - include untracked files in stash push/save flows
git() {
  if [ "$#" -eq 0 ]; then
    command git --no-pager
    return $?
  fi

  if [ "$1" = "stash" ]; then
    shift
    case "${1-}" in
      ""|-*)
        case "${1-}" in
          -h|--help)
            command git --no-pager stash "$@"
            ;;
          *)
            command git --no-pager stash push --include-untracked "$@"
            ;;
        esac
        return $?
        ;;
      push|save)
        shift
        command git --no-pager stash push --include-untracked "$@"
        return $?
        ;;
      *)
        command git --no-pager stash "$@"
        return $?
        ;;
    esac
  fi

  command git --no-pager "$@"
}

# Git diff → clipboard with counts
alias gdc='bash -c '"'"'
b=$(git symbolic-ref --quiet --short refs/remotes/origin/HEAD 2>/dev/null || echo origin/main)
git fetch -q origin
tmp=$(mktemp)
git diff --no-color "${b}"...HEAD >"$tmp"
added=$(grep -E "^\+" "$tmp" | grep -Ev "^\+\+\+" | wc -l | tr -d " ")
removed=$(grep -E "^\-" "$tmp" | grep -Ev "^---" | wc -l | tr -d " ")
changed=$((added + removed))
cmd="$(_clip_cmd)"; [ -z "$cmd" ] && { printf "Install pbcopy/wl-copy/xclip/xsel\n" >&2; rm -f "$tmp"; exit 1; }
eval "$cmd" <"$tmp"
echo "Copied git diff: $changed lines (+$added / -$removed)"
rm -f "$tmp"
'"'"''
