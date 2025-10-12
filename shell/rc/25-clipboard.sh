_clip_cmd() {
  if command -v pbcopy >/dev/null 2>&1; then echo "pbcopy"
  elif command -v wl-copy >/dev/null 2>&1; then echo "wl-copy"
  elif command -v xclip  >/dev/null 2>&1; then echo "xclip -selection clipboard"
  elif command -v xsel   >/dev/null 2>&1; then echo "xsel --clipboard --input"
  elif command -v clip.exe >/dev/null 2>&1; then echo "clip.exe"
  else echo ""; fi
}

# In lsclip where you used declare -A:
if [ -n "${ZSH_VERSION-}" ]; then typeset -A printed; else declare -A printed; fi
