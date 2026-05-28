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

_git_has_force_flag() {
  local arg
  for arg in "$@"; do
    case "$arg" in
      -f|--force)
        return 0
        ;;
    esac
  done
  return 1
}

_git_has_staged_changes() {
  command git diff --cached --quiet --exit-code
  local rc=$?
  case "$rc" in
    0)
      return 1
      ;;
    1)
      return 0
      ;;
    *)
      return "$rc"
      ;;
  esac
}

_git_lc_print_numstat() {
  local label
  label="${1-}"
  awk -F '\t' -v label="$label" '
    function number(value) {
      return value ~ /^[0-9]+$/ ? value + 0 : 0
    }
    NF {
      add = number($1)
      remove = number($2)
      path = $3
      for (i = 4; i <= NF; i++) {
        path = path "\t" $i
      }
      added += add
      removed += remove
      printf "\033[32m+%d\033[0m \033[31m-%d\033[0m %s\n", add, remove, path
    }
    END {
      printf "\033[32m+%d\033[0m \033[31m-%d\033[0m", added, removed
      if (label != "") {
        printf " %s", label
      }
      printf "\n"
    }
  '
}

_git_lc_total_numstat() {
  awk -F '\t' '
    function number(value) {
      return value ~ /^[0-9]+$/ ? value + 0 : 0
    }
    NF {
      added += number($1)
      removed += number($2)
    }
    END { printf "%d %d", added, removed }
  '
}

_git_lc_print_total() {
  printf '\033[32m+%d\033[0m \033[31m-%d\033[0m' "$1" "$2"
  if [ -n "${3-}" ]; then
    printf ' %s' "$3"
  fi
  printf '\n'
}

_git_lc_untracked_numstat() {
  local file lines
  command git ls-files --others --exclude-standard |
    while IFS= read -r file; do
      [ -f "$file" ] || continue
      lines="$(awk 'END { print NR }' "./$file" 2>/dev/null)" || lines=0
      case "$lines" in
        ""|*[!0-9]*)
          lines=0
          ;;
      esac
      printf '%s\t0\t%s\n' "$lines" "$file"
    done
}

_git_lc_current_numstat() {
  local diff_output staged_rc untracked_output
  _git_has_staged_changes
  staged_rc=$?
  case "$staged_rc" in
    0)
      diff_output="$(command git diff --cached --numstat)" || return $?
      ;;
    1)
      if command git rev-parse --verify HEAD >/dev/null 2>&1; then
        diff_output="$(command git diff --numstat HEAD)" || return $?
      else
        diff_output="$(command git diff --numstat)" || return $?
      fi
      ;;
    *)
      return "$staged_rc"
      ;;
  esac

  if [ "$staged_rc" -eq 1 ]; then
    untracked_output="$(_git_lc_untracked_numstat)" || return $?
    if [ -n "$untracked_output" ]; then
      if [ -n "$diff_output" ]; then
        diff_output="${diff_output}
${untracked_output}"
      else
        diff_output="$untracked_output"
      fi
    fi
  fi
  if [ -n "$diff_output" ]; then
    printf '%s\n' "$diff_output"
  fi
  return 0
}

_git_lc_base_ref() {
  local base candidate
  base="${1:-main}"
  for candidate in "origin/$base" "$base"; do
    if command git rev-parse --verify --quiet "${candidate}^{commit}" >/dev/null; then
      printf '%s\n' "$candidate"
      return 0
    fi
  done
  printf 'git lc: unknown branch/ref: %s\n' "$base" >&2
  return 1
}

_git_lc_verbose() {
  local base_arg base_ref branch_added branch_numstat branch_removed branch_totals current_added current_numstat current_removed current_totals
  base_arg="${1:-main}"
  base_ref="$(_git_lc_base_ref "$base_arg")" || return $?
  current_numstat="$(_git_lc_current_numstat)" || return $?
  branch_numstat="$(command git diff --numstat "$base_ref"...HEAD)" || return $?

  printf 'current\n'
  printf '%s\n' "$current_numstat" | _git_lc_print_numstat "total"
  current_totals="$(printf '%s\n' "$current_numstat" | _git_lc_total_numstat)" || return $?
  current_added="${current_totals%% *}"
  current_removed="${current_totals#* }"

  printf '\nbranch (%s)\n' "$base_ref"
  printf '%s\n' "$branch_numstat" | _git_lc_print_numstat "total"
  branch_totals="$(printf '%s\n' "$branch_numstat" | _git_lc_total_numstat)" || return $?
  branch_added="${branch_totals%% *}"
  branch_removed="${branch_totals#* }"

  printf '\nbranch + current\n'
  _git_lc_print_total "$((branch_added + current_added))" "$((branch_removed + current_removed))" "total"
}

_git_lc() {
  local base_arg base_arg_set current_numstat current_totals verbose
  base_arg="main"
  base_arg_set=0
  verbose=0
  while [ "$#" -gt 0 ]; do
    case "$1" in
      -v|--verbose)
        verbose=1
        ;;
      -*)
        printf 'git lc: unknown arg: %s\n' "$1" >&2
        return 2
        ;;
      *)
        if [ "$base_arg_set" -eq 1 ]; then
          printf 'git lc: unknown arg: %s\n' "$1" >&2
          return 2
        fi
        base_arg="$1"
        base_arg_set=1
        ;;
    esac
    shift
  done

  if [ "$verbose" -eq 1 ]; then
    _git_lc_verbose "$base_arg"
    return $?
  fi
  if [ "$base_arg_set" -eq 1 ]; then
    printf 'git lc: branch argument requires -v\n' >&2
    return 2
  fi
  current_numstat="$(_git_lc_current_numstat)" || return $?
  current_totals="$(printf '%s\n' "$current_numstat" | _git_lc_total_numstat)" || return $?
  _git_lc_print_total "${current_totals%% *}" "${current_totals#* }"
}

_git_push_with_lease_for_force() {
  local args arg
  args=()
  for arg in "$@"; do
    case "$arg" in
      -f|--force)
        args+=(--force-with-lease)
        ;;
      *)
        args+=("$arg")
        ;;
    esac
  done
  command git --no-pager push "${args[@]}"
}

git() {
  if [ "$#" -eq 0 ]; then
    command git --no-pager
    return $?
  fi

  if [ "$1" = "yolo" ]; then
    local identity name email push_after_amend staged_rc
    shift
    push_after_amend=1
    if _git_has_force_flag "$@"; then
      push_after_amend=0
    fi
    _git_has_staged_changes
    staged_rc=$?
    case "$staged_rc" in
      0)
        ;;
      1)
        command git add . || return $?
        ;;
      *)
        return "$staged_rc"
        ;;
    esac
    identity="$(_git_yolo_malai_identity)" || identity=""
    if [ -n "$identity" ]; then
      name="${identity%%	*}"
      email="${identity#*	}"
      GIT_AUTHOR_NAME="$name" GIT_AUTHOR_EMAIL="$email" GIT_COMMITTER_NAME="$name" GIT_COMMITTER_EMAIL="$email" command git commit --no-edit --amend
    else
      command git commit --no-edit --amend
    fi
    local rc=$?
    if [ "$rc" -eq 0 ] && [ "$push_after_amend" -eq 0 ]; then
      command git push --force-with-lease
      rc=$?
    fi
    if [ "$rc" -eq 0 ]; then
      _git_print_commit_account
    fi
    return "$rc"
  fi

  if [ "$1" = "lc" ]; then
    shift
    _git_lc "$@"
    return $?
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
    if [ "$rc" -eq 0 ] && [ -n "$before" ] && [ "$after" != "$before" ]; then
      previousBranch="$before"
    fi
    return "$rc"
  fi

  if [ "$1" = "ri" ]; then
    local branch base_branch
    shift
    base_branch="main"
    case "${1-}" in
      ""|-*)
        ;;
      *)
        base_branch="$1"
        shift
        ;;
    esac
    branch="$(_git_current_branch)" || branch=""
    if [ -z "$branch" ]; then
      printf 'git ri: current HEAD is not a branch\n' >&2
      return 1
    fi
    command git --no-pager fetch origin "$base_branch" &&
      git checkout "$base_branch" &&
      command git --no-pager merge --ff-only "origin/$base_branch" &&
      git checkout "$branch" &&
      command git --no-pager rebase -i "$@" "$base_branch"
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

  if [ "$1" = "push" ] && _git_has_force_flag "$@"; then
    shift
    _git_push_with_lease_for_force "$@"
    return $?
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
