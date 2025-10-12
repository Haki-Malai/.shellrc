# shell/rc/25-clipboard.sh

# choose backend each call; robust for zsh + bash and tmux
_clip_backend() {
  if command -v pbcopy >/dev/null 2>&1; then echo "pbcopy"; return
  elif command -v wl-copy >/dev/null 2>&1; then echo "wl-copy"; return
  elif command -v xclip  >/dev/null 2>&1; then echo "xclip -selection clipboard"; return
  elif command -v xsel   >/dev/null 2>&1; then echo "xsel --clipboard --input"; return
  elif command -v clip.exe >/dev/null 2>&1; then echo "clip.exe"; return
  fi
  # macOS fallback via AppleScript if pbcopy is broken (rare)
  if [ "$(uname -s)" = "Darwin" ] && command -v osascript >/dev/null 2>&1; then
    echo "osascript"; return
  fi
  echo ""
}

# write to clipboard; reads stdin
_clip_pipe() {
  cmd="$(_clip_backend)"
  case "$cmd" in
    pbcopy|wl-copy|clip.exe) eval "$cmd" ;;
    "xclip -selection clipboard") xclip -selection clipboard ;;
    "xsel --clipboard --input") xsel --clipboard --input ;;
    osascript) osascript -e 'set the clipboard to (do shell script "cat")' ;;
    *) echo "no clipboard backend found; install pbcopy/wl-copy/xclip/xsel" >&2; return 1 ;;
  esac
}

# user-facing function: supports pipe or args
clip() {
  if [ -t 0 ] && [ $# -gt 0 ]; then
    printf "%s" "$*" | _clip_pipe
  else
    _clip_pipe
  fi
}

# optional paste helper
pastec() {
  if command -v pbpaste >/dev/null 2>&1; then pbpaste
  elif command -v xclip >/dev/null 2>&1; then xclip -selection clipboard -o
  elif command -v xsel  >/dev/null 2>&1; then xsel --clipboard --output
  else echo "no paste backend"; return 1; fi
}

# update lscatclip/lsclip to call `_clip_backend` instead of hard alias
