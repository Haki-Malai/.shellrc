# Sync shared files into $HOME at shell init.
if [ -x "$DOTS_ROOT/shell/shared-sync.sh" ]; then
  "$DOTS_ROOT/shell/shared-sync.sh" --quiet
fi
