# Reuse an existing ssh-agent if possible; otherwise start one once.
if command -v ssh-agent >/dev/null 2>&1; then
  if [ -z "${SSH_AUTH_SOCK-}" ] || [ ! -S "$SSH_AUTH_SOCK" ]; then
    eval "$(ssh-agent -s)" >/dev/null 2>&1
  fi
fi
