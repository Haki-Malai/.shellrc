#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
ORIG_PATH="${PATH}"

if [[ $# -gt 0 && $1 == "--debug" ]]; then
  set -x
fi

run_suite_for_shell() {
  local shell_name="$1"

  if ! command -v "$shell_name" >/dev/null 2>&1; then
    printf 'skip %-5s (not installed)\n' "$shell_name"
    return 0
  fi

  local tmp_home stub_bin clip_out rc cmd
  tmp_home="$(mktemp -d "${TMPDIR:-/tmp}/shellrc-test-home.XXXXXX")"
  stub_bin="$(mktemp -d "${TMPDIR:-/tmp}/shellrc-test-bin.XXXXXX")"
  clip_out="$(mktemp "${TMPDIR:-/tmp}/shellrc-clip.XXXXXX")"

  cleanup() {
    rm -rf "$tmp_home" "$stub_bin"
    rm -f "$clip_out"
  }
  trap cleanup EXIT INT TERM

  cat >"$stub_bin/pbcopy" <<'EOF'
#!/bin/sh
cat > "${SHELLRC_TEST_CLIP_OUTPUT:?}"
EOF
  chmod +x "$stub_bin/pbcopy"

  cat >"$stub_bin/curl" <<'EOF'
#!/bin/sh
printf '%s\n' '198.51.100.42'
EOF
  chmod +x "$stub_bin/curl"

  cat >"$stub_bin/pyenv" <<'EOF'
#!/bin/sh
case "$1" in
  init) exit 0 ;;
  virtualenv-init) exit 0 ;;
  *) exit 1 ;;
esac
EOF
  chmod +x "$stub_bin/pyenv"

  cat >"$stub_bin/ssh-agent" <<'EOF'
#!/bin/sh
echo 'SSH_AUTH_SOCK=/tmp/shellrc-test-agent.sock; export SSH_AUTH_SOCK;'
echo 'SSH_AGENT_PID=12345; export SSH_AGENT_PID;'
echo 'echo Agent pid 12345;'
exit 0
EOF
  chmod +x "$stub_bin/ssh-agent"

  cat >"$stub_bin/ssh-add" <<'EOF'
#!/bin/sh
exit 0
EOF
  chmod +x "$stub_bin/ssh-add"

  # Ensure mktemp uses predictable namespace inside tests
  export TMPDIR="${TMPDIR:-/tmp}"

  local env_prefix=(
    env -i
    "HOME=$tmp_home"
    "PATH=$stub_bin:$ORIG_PATH"
    "TERM=xterm"
    "LC_ALL=C"
    "LANG=C"
    "DOTS_REPO_ROOT=$ROOT"
    "SHELLRC_TEST_MODE=1"
    "SHELLRC_TEST_CLIP_OUTPUT=$clip_out"
  )

  local shell_cmd
  case "$shell_name" in
    bash)
      shell_cmd=( "$shell_name" "--noprofile" "--norc" "-ic" '. "$DOTS_REPO_ROOT/tests/suite.sh"; tests_suite_main' )
      ;;
    zsh)
      shell_cmd=( "$shell_name" "-f" "-ic" '. "$DOTS_REPO_ROOT/tests/suite.sh"; tests_suite_main' )
      ;;
    *)
      printf 'skip %-5s (unsupported shell harness)\n' "$shell_name"
      return 0
      ;;
  esac

  printf 'running %-5s ... ' "$shell_name"
  if "${env_prefix[@]}" "${shell_cmd[@]}"; then
    echo "ok"
    rc=0
  else
    rc=$?
    echo "fail"
  fi

  trap - EXIT INT TERM
  cleanup
  return "$rc"
}

overall_status=0
for shell_name in bash zsh; do
  if ! run_suite_for_shell "$shell_name"; then
    overall_status=1
  fi
done

exit "$overall_status"
