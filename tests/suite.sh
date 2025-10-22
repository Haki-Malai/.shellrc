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
  run_test "aliases register" test_aliases_exist
  run_test "clip writes via backend" test_clip_backend
  run_test "lsclip emits tree" test_lsclip_tree
  run_test "lsclip max depth" test_lsclip_max_depth
  run_test "lsclip rejects non-git" test_lsclip_non_git
  run_test "lscatclip git mode" test_lscatclip_git
  run_test "lscatclip tree output" test_lscatclip_tree
  run_test "lscatclip max depth" test_lscatclip_max_depth
  run_test "lscatclip no matches" test_lscatclip_no_matches
  run_test "lstype ranks lines" test_lstype_lines
  run_test "lstype ranks bytes" test_lstype_bytes
  run_test "prompt includes cat" test_prompt_contains_cat

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

test_aliases_exist() {
  alias ls >/dev/null 2>&1 || return 1
  alias vi >/dev/null 2>&1 || return 1
}

test_clip_backend() {
  reset_clip_capture
  printf 'hello clip\n' | clip || return 1
  local content
  content="$(clip_contents)"
  [ "$content" = "hello clip" ] || return 1
}

test_lsclip_tree() {
  local repo path
  repo="$(make_tmp_dir)" || return 1
  path="$repo/project"
  mkdir -p "$path/dir/sub" "$path/node_modules"
  printf 'file a\n' >"$path/a.txt"
  printf 'nested\n' >"$path/dir/sub/nested.txt"
  printf 'skip\n' >"$path/node_modules/ignored.js"
  (
    cd "$path" || return 1
    git init -q
    git add a.txt dir/sub/nested.txt node_modules/ignored.js
    reset_clip_capture
    lsclip >/dev/null || return 1
  ) || return 1

  local output
  output="$(clip_contents)"
  printf '%s\n' "$output" | command grep -F -- "=== GIT TREE: $path ===" >/dev/null || return 1
  printf '%s\n' "$output" | command grep -Fx -- "./" >/dev/null || return 1
  printf '%s\n' "$output" | command grep -F -- "a.txt" >/dev/null || return 1
  printf '%s\n' "$output" | command grep -F -- "dir/sub/" >/dev/null || return 1
  printf '%s\n' "$output" | command grep -F -- "    nested.txt" >/dev/null || return 1
  ! printf '%s\n' "$output" | command grep -Fq -- "node_modules" || return 1
  rm -rf "$repo"
}

test_lsclip_max_depth() {
  local repo path
  repo="$(make_tmp_dir)" || return 1
  path="$repo/project"
  mkdir -p "$path/dir/sub"
  printf 'root\n' >"$path/root.txt"
  printf 'nested\n' >"$path/dir/sub/nested.txt"
  (
    cd "$path" || return 1
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

test_lsclip_non_git() {
  local dir
  dir="$(make_tmp_dir)" || return 1
  (
    cd "$dir" || return 1
    reset_clip_capture
    lsclip >/dev/null 2>&1
  )
  local status=$?
  rm -rf "$dir"
  [ "$status" -ne 0 ]
}

test_lscatclip_git() {
  local repo path
  repo="$(make_tmp_dir)" || return 1
  path="$repo/project"
  mkdir -p "$path"
  printf 'alpha\nbeta\n' >"$path/keep.txt"
  printf 'ignore me\n' >"$path/skip.log"
  (
    cd "$path" || return 1
    git init -q
    git add keep.txt skip.log
    reset_clip_capture
    lscatclip --git --in '*.txt' --out 'skip*' >/dev/null || return 1
  ) || return 1

  local output
  output="$(clip_contents)"
  printf '%s\n' "$output" | command grep -F -- "=== $path ===" >/dev/null || return 1
  printf '%s\n' "$output" | command grep -F -- "----- keep.txt -----" >/dev/null || return 1
  printf '%s\n' "$output" | command grep -F -- "alpha" >/dev/null || return 1
  ! printf '%s\n' "$output" | command grep -Fq -- "skip.log" || return 1
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

test_lscatclip_no_matches() {
  local repo path
  repo="$(make_tmp_dir)" || return 1
  path="$repo/project"
  mkdir -p "$path"
  printf 'alpha\n' >"$path/keep.txt"
  (
    cd "$path" || return 1
    git init -q
    git add keep.txt
    reset_clip_capture
    lscatclip --git --in '*.md' >/dev/null 2>&1
  )
  local status=$?
  rm -rf "$repo"
  [ "$status" -ne 0 ]
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

test_prompt_contains_cat() {
  if [ -n "${BASH_VERSION-}" ]; then
    case "$PS1" in *"🐈"*) :;; *) return 1;; esac
  elif [ -n "${ZSH_VERSION-}" ]; then
    case "$PROMPT" in *"🐈"*) :;; *) return 1;; esac
  fi
}

# Allow direct execution for debugging.
if [ "${BASH_SOURCE-}" = "$0" ] 2>/dev/null; then
  tests_suite_main "$@"
fi
