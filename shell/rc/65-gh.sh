_gh_workflow_run_id() {
  printf '%s\n' "$1" | command awk '
    match($0, /\/actions\/runs\/[0-9]+/) {
      id = substr($0, RSTART, RLENGTH)
      sub(/^.*\//, "", id)
    }
    END { if (id != "") print id }
  '
}

gh() {
  if [ "${1-}" != "workflow" ] || [ "${2-}" != "run" ]; then
    command gh "$@"
    return $?
  fi

  local arg expect_repo output rc repo run_id watch
  local -a args
  expect_repo=0
  repo=""
  watch=0

  for arg in "$@"; do
    if [ "$arg" = "-w" ]; then
      watch=1
      continue
    fi

    args+=("$arg")
    if [ "$expect_repo" -eq 1 ]; then
      repo="$arg"
      expect_repo=0
      continue
    fi
    case "$arg" in
      -R|--repo) expect_repo=1 ;;
      --repo=*) repo="${arg#--repo=}" ;;
      -R?*) repo="${arg#-R}" ;;
    esac
  done

  if [ "$watch" -eq 0 ]; then
    command gh "$@"
    return $?
  fi

  if output="$(command gh "${args[@]}")"; then
    rc=0
  else
    rc=$?
  fi
  [ -z "$output" ] || printf '%s\n' "$output"
  [ "$rc" -eq 0 ] || return "$rc"

  run_id="$(_gh_workflow_run_id "$output")"
  if [ -z "$run_id" ]; then
    printf 'gh workflow run: could not determine dispatched run ID\n' >&2
    return 1
  fi

  if [ -n "$repo" ]; then
    command gh run watch "$run_id" --repo "$repo"
  else
    command gh run watch "$run_id"
  fi
}
