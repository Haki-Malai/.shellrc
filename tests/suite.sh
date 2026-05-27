#!/usr/bin/env bash

# shellcheck disable=SC2034 # used in zsh context

tests_suite_main() {
  if [ -n "${BASH_VERSION-}" ]; then
    set -euo pipefail
  elif [ -n "${ZSH_VERSION-}" ]; then
    emulate -L sh
    set -eu
    setopt pipefail 2>/dev/null || true
  else
    set -eu
  fi

  local repo_root="${DOTS_REPO_ROOT:-}"
  local clip_file="${SHELLRC_TEST_CLIP_OUTPUT:-}"

  if [ -z "$repo_root" ] || [ -z "$clip_file" ]; then
    echo "missing DOTS_REPO_ROOT or SHELLRC_TEST_CLIP_OUTPUT" >&2
    return 1
  fi

  # shellcheck source=/dev/null
  . "$repo_root/shell/rc/init.sh"

  tests__run=0
  tests__fail=0
  tests__shell="${BASH_VERSION:+bash}${ZSH_VERSION:+zsh}"

  run_test "env loads core modules" test_env_loads
  run_test "user switch moves out of foreign home" test_user_switch_moves_out_of_foreign_home
  run_test "pyenv skips foreign unwritable root" test_pyenv_skips_foreign_unwritable_root
  run_test "aliases register" test_aliases_exist
  run_test "autoupdate starts on each init" test_autoupdate_runs_per_init
  run_test "nvm lazy load skips auto-use" test_nvm_lazy_load_no_use
  run_test "git wrapper defaults" test_git_wrapper_defaults
  run_test "git checkout tracks previous branch" test_git_checkout_previous_branch
  run_test "git ri updates base before interactive rebase" test_git_ri_updates_base_before_rebase
  run_test "git commit prints account" test_git_commit_account
  run_test "git yolo amends and pushes only with force" test_git_yolo
  run_test "git force push uses lease" test_git_push_force_uses_lease
  run_test "git stash includes untracked" test_git_stash_includes_untracked
  run_test "clip writes via backend" test_clip_backend
  run_test "lsclip emits tree" test_lsclip_tree
  run_test "lsclip max depth" test_lsclip_max_depth
  run_test "lsclip dir arg" test_lsclip_dir_arg
  run_test "lsclip rejects non-git" test_lsclip_non_git
  run_test "lscatclip git mode" test_lscatclip_git
  run_test "lscatclip diff mode" test_lscatclip_diff
  run_test "lscatclip diff on main branch" test_lscatclip_diff_main_branch
  run_test "lscatclip tree output" test_lscatclip_tree
  run_test "lscatclip max depth" test_lscatclip_max_depth
  run_test "lscatclip dir arg" test_lscatclip_dir_arg
  run_test "lscatclip --out excludes" test_lscatclip_out
  run_test "lscatclip --out dir glob excludes subtree" test_lscatclip_out_dir_glob
  run_test "lscatclip --includes content filter" test_lscatclip_includes
  run_test "lscatclip no matches" test_lscatclip_no_matches
  run_test "lstype ranks lines" test_lstype_lines
  run_test "lstype ranks bytes" test_lstype_bytes
  run_test "lstype dir arg" test_lstype_dir_arg
  run_test "prompt includes cat" test_prompt_contains_cat
  run_test "prompt colors derive from username hash" test_prompt_username_hash_colors

  printf '%s: %d run, %d failed\n' "${tests__shell:-unknown}" "$tests__run" "$tests__fail"
  if [ "$tests__fail" -eq 0 ]; then
    return 0
  fi
  return 1
}

run_test() {
  tests__run=$(( tests__run + 1 ))
  local name="$1"; shift
  if "$@"; then
    printf '  ✔ %s\n' "$name"
  else
    tests__fail=$(( tests__fail + 1 ))
    printf '  ✖ %s\n' "$name"
  fi
}

make_tmp_dir() {
  mktemp -d "${TMPDIR:-/tmp}/shellrc-case.XXXXXX"
}

reset_clip_capture() {
  : > "${SHELLRC_TEST_CLIP_OUTPUT:?}"
}

clip_contents() {
  cat -- "${SHELLRC_TEST_CLIP_OUTPUT:?}"
}

test_env_loads() {
  [ -n "${DOTS_ROOT-}" ] || return 1
  [ -d "$DOTS_ROOT" ] || return 1
  [ "$DOTS_ROOT" = "$DOTS_REPO_ROOT" ] || return 1
  [ -n "${DOTS_OS-}" ] || return 1
  type lsclip >/dev/null 2>&1 || return 1
  type lscatclip >/dev/null 2>&1 || return 1
  type clip >/dev/null 2>&1 || return 1
}

test_user_switch_moves_out_of_foreign_home() {
  local tmp users_root current_user current_home foreign_dir result
  tmp="$(make_tmp_dir)" || return 1
  users_root="$tmp/users"
  current_user="$(id -un 2>/dev/null)" || { rm -rf "$tmp"; return 1; }
  current_home="$users_root/$current_user"
  foreign_dir="$users_root/previous-user/project"

  mkdir -p "$current_home" "$foreign_dir" || { rm -rf "$tmp"; return 1; }
  result="$(
    cd "$foreign_dir" || exit 1
    SHELLRC_TEST_USERS_ROOT="$users_root"
    HOME="$current_home"
    export SHELLRC_TEST_USERS_ROOT HOME
    . "$DOTS_REPO_ROOT/shell/rc/01-user-context.sh"
    printf '%s\n' "$PWD"
  )" || { rm -rf "$tmp"; return 1; }

  [ "$result" = "$current_home" ] || { rm -rf "$tmp"; return 1; }
  rm -rf "$tmp"
}

test_pyenv_skips_foreign_unwritable_root() {
  local tmp users_root foreign_pyenv fakebin marker
  tmp="$(make_tmp_dir)" || return 1
  users_root="$tmp/users"
  foreign_pyenv="$users_root/previous-user/.pyenv"
  fakebin="$tmp/bin"
  marker="$tmp/pyenv-called"

  mkdir -p "$foreign_pyenv/shims" "$fakebin" || { rm -rf "$tmp"; return 1; }
  chmod 0555 "$foreign_pyenv" "$foreign_pyenv/shims" || { rm -rf "$tmp"; return 1; }
  printf '%s\n' '#!/bin/sh' 'printf called > "$SHELLRC_TEST_PYENV_MARKER"' 'exit 0' > "$fakebin/pyenv"
  chmod +x "$fakebin/pyenv" || { chmod 0755 "$foreign_pyenv" "$foreign_pyenv/shims"; rm -rf "$tmp"; return 1; }

  (
    export SHELLRC_TEST_USERS_ROOT="$users_root"
    export SHELLRC_TEST_PYENV_MARKER="$marker"
    export PYENV_ROOT="$foreign_pyenv"
    export PATH="$fakebin:$PATH"
    . "$DOTS_REPO_ROOT/shell/rc/01-user-context.sh"
    . "$DOTS_REPO_ROOT/shell/rc/05-pyenv.sh"
  ) || { chmod 0755 "$foreign_pyenv" "$foreign_pyenv/shims"; rm -rf "$tmp"; return 1; }

  chmod 0755 "$foreign_pyenv" "$foreign_pyenv/shims"
  [ ! -f "$marker" ] || { rm -rf "$tmp"; return 1; }
  rm -rf "$tmp"
}

test_aliases_exist() {
  alias ls >/dev/null 2>&1 || return 1
  alias vi >/dev/null 2>&1 || return 1
  if [ "${DOTS_OS-}" = "mac" ]; then
    alias nmr >/dev/null 2>&1 || return 1
    alias nmr | command grep -F -- "dscacheutil -flushcache" >/dev/null || return 1
    alias nmr | command grep -F -- "networksetup -setdnsservers Wi-Fi 1.1.1.1 8.8.8.8" >/dev/null || return 1
  fi
  if [ "${DOTS_OS-}" = "linux" ]; then
    alias nmr >/dev/null 2>&1 || return 1
    alias nmr | command grep -F -- "sudo systemctl restart NetworkManager" >/dev/null || return 1
  fi
}

test_autoupdate_runs_per_init() {
  local tmp marker stamp_count fakebin
  tmp="$(make_tmp_dir)" || return 1
  marker="$tmp/fetch.count"
  fakebin="$tmp/bin"
  mkdir -p "$fakebin" "$tmp/repo"
  cat >"$fakebin/git" <<'EOF'
#!/bin/sh
[ "$1" = "--no-pager" ] && shift
case "$1" in
  rev-parse)
    exit 0
    ;;
  status)
    exit 0
    ;;
  fetch)
    count=0
    [ -f "$SHELLRC_TEST_FETCH_COUNT" ] && read -r count < "$SHELLRC_TEST_FETCH_COUNT"
    count=$(( count + 1 ))
    printf '%s\n' "$count" > "$SHELLRC_TEST_FETCH_COUNT"
    exit 0
    ;;
  rev-list)
    printf '0 0\n'
    exit 0
    ;;
esac
exit 1
EOF
  chmod +x "$fakebin/git"
  (
    i=0
    export TMPDIR="$tmp"
    export DOTS_AUTOUPDATE=1
    export DOTS_ROOT="$tmp/repo"
    export PATH="$fakebin:$PATH"
    export SHELLRC_TEST_FETCH_COUNT="$marker"
    . "$DOTS_REPO_ROOT/shell/rc/20-autoupdate.sh"
    while [ "$i" -lt 50 ]; do
      [ "$(cat "$marker" 2>/dev/null || true)" = "1" ] && break
      i=$(( i + 1 ))
      sleep 0.05
    done
    [ "$(cat "$marker" 2>/dev/null || true)" = "1" ] || return 1
    i=0
    . "$DOTS_REPO_ROOT/shell/rc/20-autoupdate.sh"
    while [ "$i" -lt 50 ]; do
      [ "$(cat "$marker" 2>/dev/null || true)" = "2" ] && break
      i=$(( i + 1 ))
      sleep 0.05
    done
  ) || { rm -rf "$tmp"; return 1; }

  [ "$(cat "$marker")" = "2" ] || { rm -rf "$tmp"; return 1; }
  stamp_count="$(find "$tmp" -maxdepth 1 -name '.shellrc-autoupdate.*.ts' -print | wc -l | tr -d ' ')"
  [ "$stamp_count" = "0" ] || { rm -rf "$tmp"; return 1; }
  rm -rf "$tmp"
}

test_nvm_lazy_load_no_use() {
  local tmp log
  tmp="$(make_tmp_dir)" || return 1
  log="$tmp/nvm.log"
  mkdir -p "$tmp/nvm"
  cat >"$tmp/nvm/nvm.sh" <<'EOF'
printf 'source:%s\n' "$*" >> "${SHELLRC_TEST_NVM_LOG:?}"
nvm() {
  printf 'call:%s\n' "$*" >> "${SHELLRC_TEST_NVM_LOG:?}"
}
EOF

  (
    export NVM_DIR="$tmp/nvm"
    export SHELLRC_TEST_NVM_LOG="$log"
    unset -f nvm 2>/dev/null || true
    . "$DOTS_REPO_ROOT/shell/rc/60-devtools.sh"
    nvm current
  ) || { rm -rf "$tmp"; return 1; }

  command grep -Fx -- "source:--no-use" "$log" >/dev/null || { rm -rf "$tmp"; return 1; }
  command grep -Fx -- "call:current" "$log" >/dev/null || { rm -rf "$tmp"; return 1; }
  rm -rf "$tmp"
}

test_git_wrapper_defaults() {
  local def
  def="$(typeset -f git 2>/dev/null || true)"
  [ -n "$def" ] || return 1
  printf '%s\n' "$def" | command grep -F -- "command git --no-pager" >/dev/null || return 1
}

test_git_checkout_previous_branch() {
  local repo
  repo="$(make_tmp_dir)" || return 1
  (
    cd "$repo" || return 1
    git init -q
    git config user.email "test@example.com"
    git config user.name "Test User"
    printf 'base\n' >base.txt
    git add base.txt
    git commit -m "base" -q
    git branch -M main
    git branch short
    git branch feature
    git branch sixsix
    git branch longfeature
    unset previousBranch
    git checkout short -q || return 1
    [ "${previousBranch-}" = "main" ] || return 1
    git checkout feature -q || return 1
    [ "${previousBranch-}" = "short" ] || return 1
    git checkout main -q || return 1
    [ "${previousBranch-}" = "feature" ] || return 1
    git checkout "$previousBranch" -q || return 1
    [ "$(git symbolic-ref --quiet --short HEAD)" = "feature" ] || return 1
    [ "${previousBranch-}" = "main" ] || return 1
    git checkout does-not-exist >/dev/null 2>&1 && return 1
    [ "${previousBranch-}" = "main" ] || return 1
    git checkout sixsix -q || return 1
    [ "${previousBranch-}" = "feature" ] || return 1
    git checkout longfeature -q || return 1
    [ "${previousBranch-}" = "sixsix" ] || return 1
  ) || { rm -rf "$repo"; return 1; }

  rm -rf "$repo"
}

test_git_ri_updates_base_before_rebase() {
  local repo remote seed work main_head dev_head merge_base
  repo="$(make_tmp_dir)" || return 1
  remote="$repo/origin.git"
  seed="$repo/seed"
  work="$repo/work"
  git init --bare -q "$remote"
  mkdir -p "$seed"
  (
    cd "$seed" || return 1
    git init -q
    git config user.email "test@example.com"
    git config user.name "Test User"
    printf 'base\n' >base.txt
    git add base.txt
    git commit -m "base" -q
    git branch -M main
    git remote add origin "$remote"
    git push -u origin main -q
    git clone -q -b main "$remote" "$work"
    printf 'upstream\n' >upstream.txt
    git add upstream.txt
    git commit -m "upstream" -q
    git push origin main -q
    git checkout -b dev -q
    printf 'dev\n' >dev.txt
    git add dev.txt
    git commit -m "dev" -q
    git push origin dev -q
    cd "$work" || return 1
    git config user.email "test@example.com"
    git config user.name "Test User"
    git checkout -b feature -q
    printf 'feature\n' >feature.txt
    git add feature.txt
    git commit -m "feature" -q
    unset previousBranch
    GIT_SEQUENCE_EDITOR=true git ri || return 1
    [ "$(git symbolic-ref --quiet --short HEAD)" = "feature" ] || return 1
    [ "${previousBranch-}" = "main" ] || return 1
    main_head="$(git rev-parse main)" || return 1
    [ "$main_head" = "$(git rev-parse origin/main)" ] || return 1
    merge_base="$(git merge-base feature main)" || return 1
    [ "$merge_base" = "$main_head" ] || return 1
    git checkout -b feature_dev main -q
    printf 'feature dev\n' >feature-dev.txt
    git add feature-dev.txt
    git commit -m "feature dev" -q
    unset previousBranch
    GIT_SEQUENCE_EDITOR=true git ri dev || return 1
    [ "$(git symbolic-ref --quiet --short HEAD)" = "feature_dev" ] || return 1
    [ "${previousBranch-}" = "dev" ] || return 1
    dev_head="$(git rev-parse dev)" || return 1
    [ "$dev_head" = "$(git rev-parse origin/dev)" ] || return 1
    merge_base="$(git merge-base feature_dev dev)" || return 1
    [ "$merge_base" = "$dev_head" ] || return 1
  ) || { rm -rf "$repo"; return 1; }

  rm -rf "$repo"
}

test_git_commit_account() {
  local repo output color
  repo="$(make_tmp_dir)" || return 1
  (
    cd "$repo" || return 1
    git init -q
    git config user.email "test@example.com"
    git config user.name "Test User"
    printf 'base\n' >base.txt
    git add base.txt
    output="$(git commit -m "base" 2>&1)" || return 1
    color="$(_shellrc_prompt_color_codes)"
    color="${color%% *}"
    printf '%s\n' "$output" | command grep -F -- "Commiter identity: " >/dev/null || return 1
    printf '%s\n' "$output" | command grep -F -- "$(printf '\033[0;1;38;5;%smTest User\033[0m <test@example.com>' "${color:-178}")" >/dev/null || return 1
  ) || { rm -rf "$repo"; return 1; }

  rm -rf "$repo"
}

test_git_yolo() {
  local repo remote project_dir local_head remote_before remote_head subject content worktree_status output author email color
  repo="$(make_tmp_dir)" || return 1
  remote="$repo/origin.git"
  project_dir="$repo/project"
  git init --bare -q "$remote"
  mkdir -p "$project_dir"
  (
    cd "$project_dir" || return 1
    git init -q
    git config user.email "test@example.com"
    git config user.name "Test User"
    printf 'base\n' >base.txt
    git add base.txt
    git commit -m "base" -q
    printf 'malai\n' >malai.txt
    git add malai.txt
    GIT_AUTHOR_NAME="Haki Malai" GIT_AUTHOR_EMAIL="haki@example.com" GIT_COMMITTER_NAME="Haki Malai" GIT_COMMITTER_EMAIL="haki@example.com" git commit -m "malai identity" -q
    git branch -M main
    git remote add origin "$remote"
    git push -u origin main -q
    remote_before="$(git --git-dir="$remote" rev-parse main)" || return 1
    printf 'changed\n' >base.txt
    output="$(git yolo 2>&1)" || return 1
    worktree_status="$(git status --short)"
    [ -z "$worktree_status" ] || return 1
    local_head="$(git rev-parse HEAD)"
    remote_head="$(git --git-dir="$remote" rev-parse main)"
    [ "$remote_head" = "$remote_before" ] || return 1
    [ "$local_head" != "$remote_head" ] || return 1
    subject="$(git show --format=%s --no-patch HEAD)"
    [ "$subject" = "malai identity" ] || return 1
    content="$(git show HEAD:base.txt)"
    [ "$content" = "changed" ] || return 1
    printf 'staged change\n' >base.txt
    git add base.txt
    printf 'unstaged change\n' >malai.txt
    output="$(git yolo 2>&1)" || return 1
    worktree_status="$(git status --short)"
    [ "$worktree_status" = " M malai.txt" ] || return 1
    subject="$(git show --format=%s --no-patch HEAD)"
    [ "$subject" = "malai identity" ] || return 1
    content="$(git show HEAD:base.txt)"
    [ "$content" = "staged change" ] || return 1
    content="$(git show HEAD:malai.txt)"
    [ "$content" = "malai" ] || return 1
    command git checkout -- malai.txt
    worktree_status="$(git status --short)"
    [ -z "$worktree_status" ] || return 1
    printf 'changed again\n' >base.txt
    output="$(git yolo -f 2>&1)" || return 1
    worktree_status="$(git status --short)"
    [ -z "$worktree_status" ] || return 1
    local_head="$(git rev-parse HEAD)"
    remote_head="$(git --git-dir="$remote" rev-parse main)"
    [ "$local_head" = "$remote_head" ] || return 1
    subject="$(git show --format=%s --no-patch HEAD)"
    [ "$subject" = "malai identity" ] || return 1
    content="$(git show HEAD:base.txt)"
    [ "$content" = "changed again" ] || return 1
    author="$(git show --format=%an --no-patch HEAD)"
    email="$(git show --format=%ae --no-patch HEAD)"
    [ "$author" = "Haki Malai" ] || return 1
    [ "$email" = "haki@example.com" ] || return 1
    color="$(_shellrc_prompt_color_codes)"
    color="${color%% *}"
    printf '%s\n' "$output" | command grep -F -- "Commiter identity: " >/dev/null || return 1
    printf '%s\n' "$output" | command grep -F -- "$(printf '\033[0;1;38;5;%smHaki Malai\033[0m <haki@example.com>' "${color:-178}")" >/dev/null || return 1
  ) || { rm -rf "$repo"; return 1; }

  rm -rf "$repo"
}

test_git_push_force_uses_lease() {
  local repo remote project_dir other_dir remote_before remote_after
  repo="$(make_tmp_dir)" || return 1
  remote="$repo/origin.git"
  project_dir="$repo/project"
  other_dir="$repo/other"
  git init --bare -q "$remote"
  mkdir -p "$project_dir"
  (
    cd "$project_dir" || return 1
    git init -q
    git config user.email "test@example.com"
    git config user.name "Test User"
    printf 'base\n' >base.txt
    git add base.txt
    git commit -m "base" -q
    git branch -M main
    git remote add origin "$remote"
    git push -u origin main -q
    git clone -q "$remote" "$other_dir"
    (
      cd "$other_dir" || return 1
      git config user.email "other@example.com"
      git config user.name "Other User"
      printf 'remote\n' >remote.txt
      git add remote.txt
      git commit -m "remote" -q
      git push origin main -q
    ) || return 1
    remote_before="$(git --git-dir="$remote" rev-parse main)" || return 1
    printf 'local\n' >local.txt
    git add local.txt
    git commit -m "local" -q
    git push -f origin main >/dev/null 2>&1 && return 1
    remote_after="$(git --git-dir="$remote" rev-parse main)" || return 1
    [ "$remote_after" = "$remote_before" ] || return 1
    git push --force origin main >/dev/null 2>&1 && return 1
    remote_after="$(git --git-dir="$remote" rev-parse main)" || return 1
    [ "$remote_after" = "$remote_before" ] || return 1
  ) || { rm -rf "$repo"; return 1; }

  rm -rf "$repo"
}

test_git_stash_includes_untracked() {
  local repo repo_path
  repo="$(make_tmp_dir)" || return 1
  repo_path="$repo/project"
  mkdir -p "$repo_path"
  (
    cd "$repo_path" || return 1
    git init -q
    git config user.email "test@example.com"
    git config user.name "Test User"
    printf 'base\n' >base.txt
    git add base.txt
    git commit -m "base" -q
    printf 'change\n' >>base.txt
    printf 'scratch\n' >untracked.txt
    git stash -m "capture all" >/dev/null || return 1
    [ ! -f untracked.txt ] || return 1
    git stash show --name-only --include-untracked stash@{0} | command grep -Fx -- "untracked.txt" >/dev/null || return 1
  ) || { rm -rf "$repo"; return 1; }

  rm -rf "$repo"
}

test_clip_backend() {
  reset_clip_capture
  printf 'hello clip\n' | clip || return 1
  local content
  content="$(clip_contents)"
  [ "$content" = "hello clip" ] || return 1
}

test_lsclip_tree() {
  local repo project_dir
  repo="$(make_tmp_dir)" || return 1
  project_dir="$repo/project"
  mkdir -p "$project_dir/dir/sub" "$project_dir/node_modules"
  printf 'file a\n' >"$project_dir/a.txt"
  printf 'nested\n' >"$project_dir/dir/sub/nested.txt"
  printf 'skip\n' >"$project_dir/node_modules/ignored.js"
  (
    cd "$project_dir" || return 1
    git init -q
    git add a.txt dir/sub/nested.txt node_modules/ignored.js
    reset_clip_capture
    lsclip >/dev/null || return 1
  ) || return 1

  local output
  output="$(clip_contents)"
  printf '%s\n' "$output" | command grep -F -- "=== GIT TREE: $project_dir ===" >/dev/null || return 1
  printf '%s\n' "$output" | command grep -Fx -- "./" >/dev/null || return 1
  printf '%s\n' "$output" | command grep -F -- "a.txt" >/dev/null || return 1
  printf '%s\n' "$output" | command grep -F -- "dir/sub/" >/dev/null || return 1
  printf '%s\n' "$output" | command grep -F -- "    nested.txt" >/dev/null || return 1
  ! printf '%s\n' "$output" | command grep -Fq -- "node_modules" || return 1
  rm -rf "$repo"
}

test_lsclip_max_depth() {
  local repo project_dir
  repo="$(make_tmp_dir)" || return 1
  project_dir="$repo/project"
  mkdir -p "$project_dir/dir/sub"
  printf 'root\n' >"$project_dir/root.txt"
  printf 'nested\n' >"$project_dir/dir/sub/nested.txt"
  (
    cd "$project_dir" || return 1
    git init -q
    git add root.txt dir/sub/nested.txt
    reset_clip_capture
    lsclip --max-depth 1 >/dev/null || return 1
  ) || return 1

  local output
  output="$(clip_contents)"
  printf '%s\n' "$output" | command grep -F -- "root.txt" >/dev/null || return 1
  ! printf '%s\n' "$output" | command grep -Fq -- "nested.txt" || return 1
  rm -rf "$repo"
}

test_lsclip_dir_arg() {
  local repo project_dir output
  repo="$(make_tmp_dir)" || return 1
  project_dir="$repo/project"
  mkdir -p "$project_dir/dir"
  printf 'root\n' >"$project_dir/root.txt"
  printf 'inner\n' >"$project_dir/dir/inner.txt"
  (
    cd "$repo" || return 1
    (
      cd "$project_dir" || return 1
      git init -q
      git add root.txt dir/inner.txt
    ) || return 1
    reset_clip_capture
    lsclip ./project >/dev/null || return 1
  ) || { rm -rf "$repo"; return 1; }

  output="$(clip_contents)"
  printf '%s\n' "$output" | command grep -F -- "=== GIT TREE: $project_dir ===" >/dev/null || { rm -rf "$repo"; return 1; }
  printf '%s\n' "$output" | command grep -F -- "root.txt" >/dev/null || { rm -rf "$repo"; return 1; }
  printf '%s\n' "$output" | command grep -F -- "dir/" >/dev/null || { rm -rf "$repo"; return 1; }
  printf '%s\n' "$output" | command grep -F -- "inner.txt" >/dev/null || { rm -rf "$repo"; return 1; }
  rm -rf "$repo"
}

test_lsclip_non_git() {
  local dir
  dir="$(make_tmp_dir)" || return 1
  (
    cd "$dir" || return 1
    reset_clip_capture
    lsclip >/dev/null 2>&1
  )
  local rc=$?
  rm -rf "$dir"
  [ "$rc" -ne 0 ]
}

test_lscatclip_git() {
  local repo project_dir
  repo="$(make_tmp_dir)" || return 1
  project_dir="$repo/project"
  mkdir -p "$project_dir"
  printf 'alpha\nbeta\n' >"$project_dir/keep.txt"
  printf 'ignore me\n' >"$project_dir/skip.log"
  (
    cd "$project_dir" || return 1
    git init -q
    git add keep.txt skip.log
    reset_clip_capture
    lscatclip --git --in '*.txt' --out 'skip*' >/dev/null || return 1
  ) || return 1

  local output
  output="$(clip_contents)"
  printf '%s\n' "$output" | command grep -F -- "=== $project_dir ===" >/dev/null || return 1
  printf '%s\n' "$output" | command grep -F -- "----- keep.txt -----" >/dev/null || return 1
  printf '%s\n' "$output" | command grep -F -- "alpha" >/dev/null || return 1
  ! printf '%s\n' "$output" | command grep -Fq -- "skip.log" || return 1
  rm -rf "$repo"
}

test_lscatclip_diff() {
  local repo project_dir output
  repo="$(make_tmp_dir)" || return 1
  project_dir="$repo/project"
  mkdir -p "$project_dir"
  printf 'base\n' >"$project_dir/base.txt"
  (
    cd "$project_dir" || return 1
    git init -q
    git config user.email "test@example.com"
    git config user.name "Test User"
    git add base.txt
    git commit -m "base" -q
    git branch -M main
    git checkout -b feature -q
    printf 'change\n' >>"$project_dir/base.txt"
    printf 'new\n' >"$project_dir/new.txt"
    git add new.txt
    reset_clip_capture
    lscatclip --diff --in '*.txt' >/dev/null || return 1
  ) || { rm -rf "$repo"; return 1; }

  output="$(clip_contents)"
  printf '%s\n' "$output" | command grep -F -- "=== $project_dir ===" >/dev/null || { rm -rf "$repo"; return 1; }
  printf '%s\n' "$output" | command grep -F -- "----- base.txt -----" >/dev/null || { rm -rf "$repo"; return 1; }
  printf '%s\n' "$output" | command grep -F -- "----- new.txt -----" >/dev/null || { rm -rf "$repo"; return 1; }
  printf '%s\n' "$output" | command grep -F -- "=== GIT DIFF: main ===" >/dev/null || { rm -rf "$repo"; return 1; }
  printf '%s\n' "$output" | command grep -F -- "diff --git a/base.txt b/base.txt" >/dev/null || { rm -rf "$repo"; return 1; }
  printf '%s\n' "$output" | command grep -F -- "diff --git a/new.txt b/new.txt" >/dev/null || { rm -rf "$repo"; return 1; }
  rm -rf "$repo"
}

test_lscatclip_diff_main_branch() {
  local repo project_dir output
  repo="$(make_tmp_dir)" || return 1
  project_dir="$repo/project"
  mkdir -p "$project_dir"
  printf 'base\n' >"$project_dir/base.txt"
  (
    cd "$project_dir" || return 1
    git init -q
    git config user.email "test@example.com"
    git config user.name "Test User"
    git add base.txt
    git commit -m "base" -q
    git branch -M main
    printf 'worktree\n' >>"$project_dir/base.txt"
    printf 'scratch\n' >"$project_dir/untracked.txt"
    reset_clip_capture
    lscatclip --diff --in '*.txt' >/dev/null || return 1
  ) || { rm -rf "$repo"; return 1; }

  output="$(clip_contents)"
  printf '%s\n' "$output" | command grep -F -- "=== $project_dir ===" >/dev/null || { rm -rf "$repo"; return 1; }
  printf '%s\n' "$output" | command grep -F -- "----- base.txt -----" >/dev/null || { rm -rf "$repo"; return 1; }
  printf '%s\n' "$output" | command grep -F -- "----- untracked.txt -----" >/dev/null || { rm -rf "$repo"; return 1; }
  printf '%s\n' "$output" | command grep -F -- "=== GIT DIFF: main ===" >/dev/null || { rm -rf "$repo"; return 1; }
  printf '%s\n' "$output" | command grep -F -- "diff --git a/base.txt b/base.txt" >/dev/null || { rm -rf "$repo"; return 1; }
  rm -rf "$repo"
}

test_lscatclip_tree() {
  local dir
  dir="$(make_tmp_dir)" || return 1
  (
    cd "$dir" || return 1
    mkdir -p src/lib
    printf 'root\n' >README.md
    printf 'inner\n' >src/lib/file.ts
    reset_clip_capture
    lscatclip --glob '*.md' --glob '*.ts' --tree >/dev/null || return 1
  ) || return 1

  local output
  output="$(clip_contents)"
  printf '%s\n' "$output" | command grep -F -- "=== FILE TREE: $dir ===" >/dev/null || return 1
  printf '%s\n' "$output" | command grep -Fx -- "./" >/dev/null || return 1
  printf '%s\n' "$output" | command grep -F -- "src/lib/" >/dev/null || return 1
  printf '%s\n' "$output" | command grep -F -- "----- README.md -----" >/dev/null || return 1
  rm -rf "$dir"
}

test_lscatclip_max_depth() {
  local dir
  dir="$(make_tmp_dir)" || return 1
  (
    cd "$dir" || return 1
    mkdir -p nested/deeper
    printf 'root\n' >root.txt
    printf 'inside\n' >nested/deeper/inner.txt
    reset_clip_capture
    lscatclip --glob '*.txt' --max-depth 1 >/dev/null || return 1
  ) || return 1

  local output
  output="$(clip_contents)"
  printf '%s\n' "$output" | command grep -F -- "----- root.txt -----" >/dev/null || return 1
  ! printf '%s\n' "$output" | command grep -Fq -- "inner.txt" || return 1
  rm -rf "$dir"
}

test_lscatclip_dir_arg() {
  local base target output
  base="$(make_tmp_dir)" || return 1
  target="$base/work"
  mkdir -p "$target/docs" "$target/bin"
  printf 'readme\n' >"$target/docs/readme.md"
  printf 'ignore\n' >"$target/bin/app.js"
  (
    cd "$base" || return 1
    reset_clip_capture
    lscatclip --glob '*.md' ./work >/dev/null || return 1
  ) || { rm -rf "$base"; return 1; }

  output="$(clip_contents)"
  printf '%s\n' "$output" | command grep -F -- "=== $target ===" >/dev/null || { rm -rf "$base"; return 1; }
  printf '%s\n' "$output" | command grep -F -- "----- docs/readme.md -----" >/dev/null || { rm -rf "$base"; return 1; }
  ! printf '%s\n' "$output" | command grep -Fq -- "app.js" || { rm -rf "$base"; return 1; }
  rm -rf "$base"
}

test_lscatclip_out() {
  local dir output
  dir="$(make_tmp_dir)" || return 1
  (
    cd "$dir" || return 1
    mkdir -p node_modules deep/node_modules
    printf 'keep\n' >keep.js
    printf 'dep\n' >node_modules/dep.js
    printf 'nested\n' >deep/node_modules/inner.js
    reset_clip_capture
    lscatclip --glob '*.js' --out 'node_modules' >/dev/null || return 1
  ) || { rm -rf "$dir"; return 1; }

  output="$(clip_contents)"
  printf '%s\n' "$output" | command grep -F -- "keep.js" >/dev/null || { rm -rf "$dir"; return 1; }
  ! printf '%s\n' "$output" | command grep -Fq -- "dep.js" || { rm -rf "$dir"; return 1; }
  ! printf '%s\n' "$output" | command grep -Fq -- "inner.js" || { rm -rf "$dir"; return 1; }
  rm -rf "$dir"
}

test_lscatclip_out_dir_glob() {
  local dir output
  dir="$(make_tmp_dir)" || return 1
  (
    cd "$dir" || return 1
    mkdir -p tests/unit
    printf 'keep\n' >keep.js
    printf 'skip\n' >tests/unit/skip.js
    reset_clip_capture
    lscatclip --glob '*.js' --out 'tests/*' >/dev/null || return 1
  ) || { rm -rf "$dir"; return 1; }

  output="$(clip_contents)"
  printf '%s\n' "$output" | command grep -F -- "keep.js" >/dev/null || { rm -rf "$dir"; return 1; }
  ! printf '%s\n' "$output" | command grep -Fq -- "skip.js" || { rm -rf "$dir"; return 1; }
  rm -rf "$dir"
}

test_lscatclip_includes() {
  local dir output
  dir="$(make_tmp_dir)" || return 1
  (
    cd "$dir" || return 1
    printf 'keep special\n' >keep.txt
    printf 'plain text\n' >skip.txt
    reset_clip_capture
    lscatclip --glob '*.txt' --includes 'special' >/dev/null || return 1
  ) || { rm -rf "$dir"; return 1; }

  output="$(clip_contents)"
  printf '%s\n' "$output" | command grep -F -- "----- keep.txt -----" >/dev/null || { rm -rf "$dir"; return 1; }
  ! printf '%s\n' "$output" | command grep -Fq -- "skip.txt" || { rm -rf "$dir"; return 1; }
  rm -rf "$dir"
}

test_lscatclip_no_matches() {
  local repo project_dir
  repo="$(make_tmp_dir)" || return 1
  project_dir="$repo/project"
  mkdir -p "$project_dir"
  printf 'alpha\n' >"$project_dir/keep.txt"
  (
    cd "$project_dir" || return 1
    git init -q
    git add keep.txt
    reset_clip_capture
    lscatclip --git --in '*.md' >/dev/null 2>&1
  )
  local rc=$?
  rm -rf "$repo"
  [ "$rc" -ne 0 ]
}

test_lstype_lines() {
  local dir out_file output top_ext top_count
  dir="$(make_tmp_dir)" || return 1
  out_file="$dir/out.txt"
  (
    cd "$dir" || return 1
    mkdir -p sub
    printf 'a\nb\nc\nd\n' >sub/app.py
    printf 'x\n' >one.txt
    printf 'y\nz\n' >two.txt
    lstype --limit 2 >"$out_file" || return 1
  ) || { rm -rf "$dir"; return 1; }

  output="$(cat "$out_file")"
  printf '%s\n' "$output" | command grep -F -- '# top 2 file types by lines' >/dev/null || { rm -rf "$dir"; return 1; }
  top_ext="$(printf '%s\n' "$output" | awk -F'\t' 'NR==4 {print $2}')"
  top_count="$(printf '%s\n' "$output" | awk -F'\t' 'NR==4 {print $1}')"
  [ "$top_ext" = ".py" ] || { rm -rf "$dir"; return 1; }
  [ "$top_count" = "4" ] || { rm -rf "$dir"; return 1; }
  printf '%s\n' "$output" | command grep -F -- $'\t.txt' >/dev/null || { rm -rf "$dir"; return 1; }
  rm -rf "$dir"
}

test_lstype_bytes() {
  local dir out_file output top_ext top_count
  dir="$(make_tmp_dir)" || return 1
  out_file="$dir/out.txt"
  (
    cd "$dir" || return 1
    printf 'aaaaaa' >big.bin
    printf 'bb' >small.txt
    lstype --bytes --limit 1 >"$out_file" || return 1
  ) || { rm -rf "$dir"; return 1; }

  output="$(cat "$out_file")"
  printf '%s\n' "$output" | command grep -F -- '# top 1 file types by bytes' >/dev/null || { rm -rf "$dir"; return 1; }
  top_ext="$(printf '%s\n' "$output" | awk -F'\t' 'NR==4 {print $2}')"
  top_count="$(printf '%s\n' "$output" | awk -F'\t' 'NR==4 {print $1}')"
  [ "$top_ext" = ".bin" ] || { rm -rf "$dir"; return 1; }
  [ "$top_count" = "6" ] || { rm -rf "$dir"; return 1; }
  rm -rf "$dir"
}

test_lstype_dir_arg() {
  local base target out_file output top_ext top_count
  base="$(make_tmp_dir)" || return 1
  target="$base/proj"
  out_file="$base/out.txt"
  mkdir -p "$target/src"
  printf 'one\ntwo\nthree\n' >"$target/src/app.js"
  printf 'note\n' >"$target/notes.txt"
  (
    cd "$base" || return 1
    lstype --limit 1 "$target" >"$out_file" || return 1
  ) || { rm -rf "$base"; return 1; }

  output="$(cat "$out_file")"
  printf '%s\n' "$output" | command grep -F -- '# top 1 file types by lines' >/dev/null || { rm -rf "$base"; return 1; }
  top_ext="$(printf '%s\n' "$output" | awk -F'\t' 'NR==4 {print $2}')"
  top_count="$(printf '%s\n' "$output" | awk -F'\t' 'NR==4 {print $1}')"
  [ "$top_ext" = ".js" ] || { rm -rf "$base"; return 1; }
  [ "$top_count" = "3" ] || { rm -rf "$base"; return 1; }
  rm -rf "$base"
}

test_prompt_contains_cat() {
  if [ -n "${BASH_VERSION-}" ]; then
    case "$PS1" in *"🐈"*) :;; *) return 1;; esac
  elif [ -n "${ZSH_VERSION-}" ]; then
    _build_prompt
    case "$PROMPT" in *"🐈"*) :;; *) return 1;; esac
  fi
}

test_prompt_username_hash_colors() {
  local username hash hash_prefix expected colors user_color rest time_color ip_color prompt
  username="$(_shellrc_prompt_username)" || return 1
  hash="$(_shellrc_prompt_user_hex "$username")" || return 1
  hash_prefix="${hash}${hash}000000"

  expected="$((16 + (16#${hash_prefix:0:2} % 216)))"
  expected="$expected $((16 + (16#${hash_prefix:2:2} % 216)))"
  expected="$expected $((16 + (16#${hash_prefix:4:2} % 216)))"

  colors="$(_shellrc_prompt_color_codes "$username")" || return 1
  [ "$colors" = "$expected" ] || return 1

  user_color="${colors%% *}"
  rest="${colors#* }"
  time_color="${rest%% *}"
  ip_color="${rest##* }"

  if [ -n "${BASH_VERSION-}" ]; then
    prompt="$PS1"
    printf '%s\n' "$prompt" | command grep -F -- "38;5;${user_color}m\\]\\u" >/dev/null || return 1
    printf '%s\n' "$prompt" | command grep -F -- "38;5;${time_color}m\\]\\A" >/dev/null || return 1
    printf '%s\n' "$prompt" | command grep -F -- "38;5;${ip_color}m\\]" >/dev/null || return 1
  elif [ -n "${ZSH_VERSION-}" ]; then
    PROMPT_MAX=1000
    _build_prompt
    prompt="$PROMPT"
    printf '%s\n' "$prompt" | command grep -F -- "%F{${user_color}}%n%f" >/dev/null || return 1
    printf '%s\n' "$prompt" | command grep -F -- "%F{${time_color}}%*%f" >/dev/null || return 1
    printf '%s\n' "$prompt" | command grep -F -- "%F{${ip_color}}" >/dev/null || return 1
  fi
}

# Allow direct execution for debugging.
if [ "${BASH_SOURCE-}" = "$0" ] 2>/dev/null; then
  tests_suite_main "$@"
fi
