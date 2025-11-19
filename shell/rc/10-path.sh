# pyenv path hints (Homebrew Intel/ARM)
[ -x /opt/homebrew/bin/pyenv ] && PATH="$PATH:/opt/homebrew/bin"
[ -x /usr/local/bin/pyenv ]   && PATH="$PATH:/usr/local/bin"
export PATH

if command -v pyenv >/dev/null 2>&1; then
  eval "$(pyenv init --path)" 2>/dev/null || true
  eval "$(pyenv virtualenv-init -)" 2>/dev/null || true
fi

# auto-activate venv if present
[ -d "venv" ] && . venv/bin/activate
export VIRTUAL_ENV_DISABLE_PROMPT=1
