# pyenv
export PATH="$HOME/.pyenv/bin:$PATH"
eval "$(pyenv init --path)" 2>/dev/null || true
eval "$(pyenv virtualenv-init -)" 2>/dev/null || true

# project venv auto-activate
[ -d "venv" ] && . venv/bin/activate
export VIRTUAL_ENV_DISABLE_PROMPT=1
