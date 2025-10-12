# Clipboard backend + user-facing clip() that reads stdin
[ -n "${ZSH_VERSION-}" ] && setopt local_options no_aliases
unalias clip 2>/dev/null || true
unset -f clip 2>/dev/null || true

_clip_cmd() {
  if command -v pbcopy >/dev/null 2>&1; then echo "pbcopy"
  elif command -v wl-copy >/dev/null 2>&1; then echo "wl-copy"
  elif command -v xclip  >/dev/null 2>&1; then echo "xclip -selection clipboard"
  elif command -v xsel   >/dev/null 2>&1; then echo "xsel --clipboard --input"
  elif command -v clip.exe >/dev/null 2>&1; then echo "clip.exe"
  else echo ""; fi
}

clip() {
  local c; c="$(_clip_cmd)"
  [ -n "$c" ] || { echo "install pbcopy/wl-copy/xclip/xsel" >&2; return 1; }
  eval "$c"
}

