# Git diff → clipboard with counts
[ -n "${ZSH_VERSION-}" ] && setopt local_options no_aliases
unalias gdc 2>/dev/null || true
unset -f gdc 2>/dev/null || true

gdc() {
  local b tmp added removed changed
  b=$(git symbolic-ref --quiet --short refs/remotes/origin/HEAD 2>/dev/null || echo origin/main)
  git fetch -q origin || true
  tmp="$(mktemp)" || return 1
  git diff --no-color "${b}"...HEAD >"$tmp"
  added=$(grep -E "^\+" "$tmp" | grep -Ev "^\+\+\+" | wc -l | tr -d " ")
  removed=$(grep -E "^\-" "$tmp" | grep -Ev "^---" | wc -l | tr -d " ")
  changed=$((added + removed))
  clip <"$tmp" || { rm -f "$tmp"; return 1; }
  echo "Copied git diff: $changed lines (+$added / -$removed)"
  rm -f "$tmp"
}

