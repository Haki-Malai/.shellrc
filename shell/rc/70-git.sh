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
