# Git defaults:
# - disable pager output by default
# - include untracked files in stash push/save flows
_git_yolo_malai_identity() {
  command git log --all --format='%aN	%aE%n%cN	%cE' 2>/dev/null |
    awk -F '\t' 'BEGIN { found = 0 }
      tolower($1) ~ /malai/ && $1 != "" && $2 != "" {
        print $1 "\t" $2
        found = 1
        exit
      }
      END { exit found ? 0 : 1 }'
}

_git_print_commit_account() {
  local name email colors color
  name="$(command git show --format='%an' --no-patch HEAD 2>/dev/null)" || return $?
  email="$(command git show --format='%ae' --no-patch HEAD 2>/dev/null)" || return $?
  if type _shellrc_prompt_color_codes >/dev/null 2>&1; then
    colors="$(_shellrc_prompt_color_codes 2>/dev/null)" || colors=""
    color="${colors%% *}"
  fi
  printf 'Commiter identity: \033[0;1;38;5;%sm%s\033[0m <%s>\n' "${color:-178}" "$name" "$email"
}

_git_current_head() {
  command git rev-parse --verify HEAD 2>/dev/null
}

_git_current_branch() {
  command git symbolic-ref --quiet --short HEAD 2>/dev/null
}

git() {
  if [ "$#" -eq 0 ]; then
    command git --no-pager
    return $?
  fi

  if [ "$1" = "yolo" ]; then
    local identity name email
    identity="$(_git_yolo_malai_identity)" || identity=""
    if [ -n "$identity" ]; then
      name="${identity%%	*}"
      email="${identity#*	}"
      command git add . &&
        GIT_AUTHOR_NAME="$name" GIT_AUTHOR_EMAIL="$email" GIT_COMMITTER_NAME="$name" GIT_COMMITTER_EMAIL="$email" command git commit --no-edit --amend &&
        command git push -f
    else
      command git add . &&
        command git commit --no-edit --amend &&
        command git push -f
    fi
    local rc=$?
    if [ "$rc" -eq 0 ]; then
      _git_print_commit_account
    fi
    return "$rc"
  fi

  if [ "$1" = "commit" ]; then
    local before after
    before="$(_git_current_head)" || before=""
    command git --no-pager "$@"
    local rc=$?
    after="$(_git_current_head)" || after=""
    if [ "$rc" -eq 0 ] && [ -n "$after" ] && [ "$after" != "$before" ]; then
      _git_print_commit_account
    fi
    return "$rc"
  fi

  if [ "$1" = "checkout" ]; then
    local before after
    before="$(_git_current_branch)" || before=""
    command git --no-pager "$@"
    local rc=$?
    after="$(_git_current_branch)" || after=""
    if [ "$rc" -eq 0 ] && [ -n "$before" ] && [ "$after" != "$before" ] && [ "${#before}" -ge 6 ]; then
      previousBranch="$before"
    fi
    return "$rc"
  fi

  if [ "$1" = "ri" ]; then
    local branch
    shift
    branch="$(_git_current_branch)" || branch=""
    if [ -z "$branch" ]; then
      printf 'git ri: current HEAD is not a branch\n' >&2
      return 1
    fi
    command git --no-pager fetch origin main &&
      git checkout main &&
      command git --no-pager merge --ff-only origin/main &&
      git checkout "$branch" &&
      command git --no-pager rebase -i "$@" main
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
