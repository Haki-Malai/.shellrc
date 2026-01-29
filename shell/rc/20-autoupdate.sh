# auto-update dotfiles repo in the background (fast-forward only)
# set DOTS_AUTOUPDATE=0 to disable
# set DOTS_AUTOUPDATE_INTERVAL (seconds) to control frequency

[ "${DOTS_AUTOUPDATE:-1}" -eq 0 ] 2>/dev/null && return 0

_dots_now() {
  if [ -n "${EPOCHSECONDS-}" ]; then
    printf '%s' "$EPOCHSECONDS"
  else
    date +%s
  fi
}

_dots_autoupdate_run() (
  local repo="$DOTS_ROOT"
  local lock="/tmp/.shellrc-autoupdate.lock"

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
  [ "${behind:-0}" -gt 0 ] 2>/dev/null && git merge --ff-only --quiet
)

_dots_autoupdate_start() {
  local interval ts now last pid

  interval="${DOTS_AUTOUPDATE_INTERVAL:-600}"
  [ "$interval" -gt 0 ] 2>/dev/null || return 0

  ts="/tmp/.shellrc-autoupdate.ts"
  now="$(_dots_now)"
  last=0
  [ -f "$ts" ] && read -r last < "$ts" 2>/dev/null
  [ $((now - last)) -lt "$interval" ] 2>/dev/null && return 0

  printf '%s' "$now" >| "$ts" 2>/dev/null || return 0

  # run in a subshell so the parent shell doesn't print job notifications
  ( _dots_autoupdate_run >/dev/null 2>&1 & )
}

_dots_autoupdate_start
