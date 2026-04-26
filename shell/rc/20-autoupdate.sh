# auto-update dotfiles repo in the background (fast-forward only)
# set DOTS_AUTOUPDATE=0 to disable

[ "${DOTS_AUTOUPDATE:-1}" -eq 0 ] 2>/dev/null && return 0

_dots_tmpdir() {
  local base
  base="${TMPDIR-}"
  if [ -n "$base" ] && [ -d "$base" ] && [ -w "$base" ]; then
    printf '%s' "$base"
    return
  fi
  if [ -d /tmp ] && [ -w /tmp ]; then
    printf '%s' "/tmp"
    return
  fi
  if [ -n "${HOME-}" ]; then
    base="$HOME/.cache/.shellrc"
    if mkdir -p "$base" 2>/dev/null && [ -w "$base" ]; then
      printf '%s' "$base"
      return
    fi
    if [ -w "$HOME" ]; then
      printf '%s' "$HOME"
      return
    fi
  fi
  printf '%s' "."
}

_dots_autoupdate_run() (
  local repo="$DOTS_ROOT"
  local tmp uid lock

  tmp="$(_dots_tmpdir)"
  uid="${UID:-${EUID:-${USER:-user}}}"
  lock="$tmp/.shellrc-autoupdate.${uid}.lock"

  mkdir "$lock" 2>/dev/null || exit 0
  trap 'rmdir "$lock" 2>/dev/null' EXIT

  command -v git >/dev/null 2>&1 || exit 0
  cd "$repo" 2>/dev/null || exit 0

  git rev-parse --is-inside-work-tree >/dev/null 2>&1 || exit 0
  git rev-parse --abbrev-ref --symbolic-full-name @{u} >/dev/null 2>&1 || exit 0
  [ -z "$(git status --porcelain 2>/dev/null)" ] || exit 0

  GIT_TERMINAL_PROMPT=0 git fetch --quiet || exit 0

  local counts ahead behind
  counts="$(git rev-list --left-right --count HEAD...@{u} 2>/dev/null)" || exit 0
  ahead="${counts%% *}"
  behind="${counts##* }"
  if [ "${behind:-0}" -gt 0 ] 2>/dev/null; then
    git merge --ff-only --quiet || exit 0
    if [ -x "$repo/shell/shared-sync.sh" ]; then
      "$repo/shell/shared-sync.sh" --quiet
    fi
  fi
)

_dots_autoupdate_start() {
  # run in a subshell so the parent shell doesn't print job notifications
  ( _dots_autoupdate_run >/dev/null 2>&1 & )
}

_dots_autoupdate_start
