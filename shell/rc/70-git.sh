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
  command git --no-pager push --no-verify "${args[@]}"
}

_git_branch_pr_rows() {
  command gh pr list \
    --state "$1" \
    --limit 1000 \
    --json number,headRefName,url,isCrossRepository \
    --jq '.[] | select(.isCrossRepository == false) | [.number, .headRefName, .url] | @tsv'
}

_git_branch_pr_context() {
  if ! command git rev-parse --git-dir >/dev/null 2>&1; then
    printf 'git branch: not a git repo\n' >&2
    return 1
  fi
  if ! command -v gh >/dev/null 2>&1; then
    printf 'git branch: gh is required\n' >&2
    return 1
  fi
}

_git_branch_print_pr() {
  printf '\033[35m#%s\033[0m \033[1;32m%s\033[0m \033[36m%s\033[0m\n' "$1" "$2" "$3"
}

_git_branch_pr() {
  local branch branch_rows marker number pr_row rows tab url worktree_path
  _git_branch_pr_context || return $?
  rows="$(_git_branch_pr_rows open)" || return $?
  branch_rows="$(command git for-each-ref --format='%(HEAD)%09%(refname:short)%09%(worktreepath)' refs/heads)" || return $?
  tab="$(printf '\t')"

  while IFS="$tab" read -r marker branch worktree_path; do
    [ -n "$branch" ] || continue
    if [ "$marker" != "*" ] && [ -n "$worktree_path" ]; then
      marker="+"
    fi
    pr_row="$(printf '%s\n' "$rows" | awk -F '\t' -v branch="$branch" '$2 == branch { print; exit }')"
    if [ -n "$pr_row" ]; then
      IFS="$tab" read -r number branch url <<EOF
$pr_row
EOF
      printf '%s ' "$marker"
      _git_branch_print_pr "$number" "$branch" "$url"
    elif [ "$marker" = "*" ]; then
      printf '* \033[32m%s\033[0m\n' "$branch"
    elif [ "$marker" = "+" ]; then
      printf '+ \033[36m%s\033[0m\n' "$branch"
    else
      printf '  %s\n' "$branch"
    fi
  done <<EOF
$branch_rows
EOF
}

_git_branch_is_checked_out() {
  command git worktree list --porcelain |
    awk -v ref="refs/heads/$1" '
      $1 == "branch" && $2 == ref { found = 1 }
      END { exit found ? 0 : 1 }
    '
}

_git_branch_remote_exists() {
  printf '%s\n' "$1" |
    awk -v ref="refs/heads/$2" '
      $2 == ref { found = 1 }
      END { exit found ? 0 : 1 }
    '
}

_git_branch_rows_include() {
  printf '%s\n' "$1" |
    awk -F '\t' -v branch="$2" '
      $2 == branch { found = 1 }
      END { exit found ? 0 : 1 }
    '
}

_git_branch_clean() {
  local branch candidate_count candidate_rows number remote_heads reply row rows tab url
  _git_branch_pr_context || return $?
  if ! command git remote get-url origin >/dev/null 2>&1; then
    printf 'git branch --clean: origin remote not found\n' >&2
    return 1
  fi

  remote_heads="$(command git ls-remote --heads origin)" || return $?
  rows="$(_git_branch_pr_rows merged)" || return $?
  candidate_count=0
  candidate_rows=""
  tab="$(printf '\t')"

  while IFS="$tab" read -r number branch url; do
    [ -n "$branch" ] || continue
    command git show-ref --verify --quiet "refs/heads/$branch" || continue
    _git_branch_remote_exists "$remote_heads" "$branch" && continue
    _git_branch_rows_include "$candidate_rows" "$branch" && continue
    if _git_branch_is_checked_out "$branch"; then
      printf '\033[33mSkipping checked-out branch: %s\033[0m\n' "$branch" >&2
      continue
    fi
    row="$(printf '%s\t%s\t%s' "$number" "$branch" "$url")"
    if [ -n "$candidate_rows" ]; then
      candidate_rows="${candidate_rows}
${row}"
    else
      candidate_rows="$row"
    fi
    candidate_count=$((candidate_count + 1))
  done <<EOF
$rows
EOF

  if [ "$candidate_count" -eq 0 ]; then
    printf '\033[2mNo merged local PR branches with deleted origin branches.\033[0m\n'
    return 0
  fi

  printf 'Local branches eligible for deletion:\n'
  while IFS="$tab" read -r number branch url; do
    _git_branch_print_pr "$number" "$branch" "$url"
  done <<EOF
$candidate_rows
EOF
  printf 'Force-delete %d local branch%s? [y/N] ' "$candidate_count" "$([ "$candidate_count" -eq 1 ] || printf 'es')"
  IFS= read -r reply || reply=""
  case "$reply" in
    y|Y|yes|YES|Yes)
      ;;
    *)
      printf 'Cancelled.\n'
      return 0
      ;;
  esac

  while IFS="$tab" read -r number branch url; do
    command git branch -D -- "$branch" || return $?
  done <<EOF
$candidate_rows
EOF
}

_git_cdx_write_patch() {
  local diff_rc patch_file source_root untracked_file
  source_root="$1"
  patch_file="$2"

  command git -C "$source_root" diff --binary >"$patch_file" || return $?
  command git -C "$source_root" ls-files --others --exclude-standard -z |
    while IFS= read -r -d '' untracked_file; do
      [ -f "$source_root/$untracked_file" ] || continue
      command git -C "$source_root" diff --binary --no-index -- /dev/null "$untracked_file" >>"$patch_file"
      diff_rc=$?
      case "$diff_rc" in
        0|1)
          ;;
        *)
          return "$diff_rc"
          ;;
      esac
    done
}

_git_cdx_apply() {
  local patch_file project_root project_name source_root worktree_id

  if [ "$#" -ne 1 ]; then
    printf 'usage: git cdx apply <worktree-id>\n' >&2
    return 2
  fi

  worktree_id="$1"
  case "$worktree_id" in
    ""|*[!A-Za-z0-9_-]*)
      printf 'git cdx: invalid worktree id: %s\n' "$worktree_id" >&2
      return 2
      ;;
  esac

  project_root="$(command git rev-parse --show-toplevel 2>/dev/null)" || {
    printf 'git cdx: not a git repo\n' >&2
    return 1
  }
  project_name="${project_root##*/}"
  if [ -z "${HOME-}" ]; then
    printf 'git cdx: HOME is not set\n' >&2
    return 1
  fi

  source_root="$HOME/.codex/worktrees/$worktree_id/$project_name"
  if ! command git -C "$source_root" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    printf 'git cdx: codex worktree project not found: %s\n' "$source_root" >&2
    return 1
  fi

  patch_file="/tmp/$worktree_id.patch"
  _git_cdx_write_patch "$source_root" "$patch_file" || return $?
  command git -C "$project_root" apply --3way "$patch_file"
}

_git_cdx_print_summary() {
  awk '
    function extension(path, name) {
      sub(/^.* -> /, "", path)
      gsub(/^"|"$/, "", path)
      if (path ~ /\/$/) {
        return "[dir]"
      }
      name = path
      sub(/^.*\//, "", name)
      if (name !~ /\./ || name ~ /^\.[^.]+$/) {
        return "[no ext]"
      }
      sub(/^.*\./, ".", name)
      return name
    }
    length($0) >= 4 {
      ext = extension(substr($0, 4))
      counts[ext]++
      total++
    }
    END {
      for (ext in counts) {
        keys[++count] = ext
      }
      for (i = 1; i <= count; i++) {
        for (j = i + 1; j <= count; j++) {
          if (counts[keys[j]] > counts[keys[i]] ||
              (counts[keys[j]] == counts[keys[i]] && keys[j] < keys[i])) {
            key = keys[i]
            keys[i] = keys[j]
            keys[j] = key
          }
        }
      }
      printf "  "
      for (i = 1; i <= count; i++) {
        if (i > 1) {
          printf "  "
        }
        printf "\033[1;33m%d\033[0m \033[36m%s\033[0m", counts[keys[i]], keys[i]
      }
      printf "  \033[2m(%d change%s)\033[0m\n", total, (total == 1 ? "" : "s")
    }
  '
}

_git_cdx_print_verbose_status() {
  awk '
    {
      code = substr($0, 1, 2)
      if (code == "??") color = 36
      else if (code ~ /D/) color = 31
      else if (code ~ /A/) color = 32
      else if (code ~ /R|C/) color = 35
      else color = 33
      printf "\033[%dm%s\033[0m\n", color, $0
    }
  '
}

_git_cdx_list() {
  local branch field head short_head verbose worktree worktree_status

  verbose=0
  case "$#:${1-}" in
    0:)
      ;;
    1:-v|1:--verbose)
      verbose=1
      ;;
    *)
      printf 'usage: git cdx list [-v|--verbose]\n' >&2
      return 2
      ;;
  esac
  if ! command git rev-parse --show-toplevel >/dev/null 2>&1; then
    printf 'git cdx: not a git repo\n' >&2
    return 1
  fi

  branch=""
  head=""
  worktree=""
  while IFS= read -r -d '' field; do
    case "$field" in
      worktree\ *)
        worktree="${field#worktree }"
        branch=""
        head=""
        ;;
      HEAD\ *)
        head="${field#HEAD }"
        ;;
      branch\ *)
        branch="${field#branch refs/heads/}"
        ;;
      "")
        [ -n "$worktree" ] || continue
        worktree_status="$(command git -C "$worktree" status --short 2>/dev/null)" || continue
        [ -n "$worktree_status" ] || continue
        short_head="$(command git -C "$worktree" rev-parse --short "$head")" || return $?
        if [ -n "$branch" ]; then
          printf '\033[1;36m%s\033[0m  \033[33m%s\033[0m \033[32m[%s]\033[0m\n' "$worktree" "$short_head" "$branch"
        else
          printf '\033[1;36m%s\033[0m  \033[33m%s\033[0m \033[35m(detached HEAD)\033[0m\n' "$worktree" "$short_head"
        fi
        if [ "$verbose" -eq 1 ]; then
          printf '%s\n' "$worktree_status" | _git_cdx_print_verbose_status
        else
          printf '%s\n' "$worktree_status" | _git_cdx_print_summary
        fi
        ;;
    esac
  done < <(command git worktree list --porcelain -z)
}

_git_cdx() {
  case "${1-}" in
    apply)
      shift
      _git_cdx_apply "$@"
      ;;
    list)
      shift
      _git_cdx_list "$@"
      ;;
    ""|-h|--help)
      printf 'usage: git cdx apply <worktree-id>\n'
      printf '       git cdx list [-v|--verbose]\n'
      ;;
    *)
      printf 'git cdx: unknown subcommand: %s\n' "$1" >&2
      return 2
      ;;
  esac
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
    local commit_args
    commit_args=(--no-edit --amend)
    if [ "$push_after_amend" -eq 0 ]; then
      commit_args+=(--no-verify)
    fi
    if [ -n "$identity" ]; then
      name="${identity%%	*}"
      email="${identity#*	}"
      GIT_AUTHOR_NAME="$name" GIT_AUTHOR_EMAIL="$email" GIT_COMMITTER_NAME="$name" GIT_COMMITTER_EMAIL="$email" command git commit "${commit_args[@]}"
    else
      command git commit "${commit_args[@]}"
    fi
    local rc=$?
    if [ "$rc" -eq 0 ] && [ "$push_after_amend" -eq 0 ]; then
      command git push --no-verify --force-with-lease
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

  if [ "$1" = "cdx" ]; then
    shift
    _git_cdx "$@"
    return $?
  fi

  if [ "$1" = "branch" ]; then
    case "$#:${2-}" in
      2:--pr)
        _git_branch_pr
        return $?
        ;;
      2:--clean)
        _git_branch_clean
        return $?
        ;;
    esac
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
