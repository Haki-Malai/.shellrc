# pick clipboard backend
_clip_cmd() {
  if command -v pbcopy >/dev/null 2>&1; then echo "pbcopy"
  elif command -v wl-copy >/dev/null 2>&1; then echo "wl-copy"
  elif command -v xclip  >/dev/null 2>&1; then echo "xclip -selection clipboard"
  elif command -v xsel   >/dev/null 2>&1; then echo "xsel --clipboard --input"
  elif command -v clip.exe >/dev/null 2>&1; then echo "clip.exe"; else echo ""; fi
}
alias clip="$(_clip_cmd)"

# Move your existing lscatclip/lsclip here. Ensure they use _clip_cmd and support pbcopy.
# Keep your pruning and max-line logic unchanged.
