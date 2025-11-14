# NVM (lazy-load to keep startup fast)
export NVM_DIR="${NVM_DIR:-$HOME/.nvm}"
if [ -s "$NVM_DIR/nvm.sh" ]; then
  nvm() {
    unset -f nvm
    # shellcheck source=/dev/null
    . "$NVM_DIR/nvm.sh"
    if [ -s "$NVM_DIR/bash_completion" ]; then
      # shellcheck source=/dev/null
      . "$NVM_DIR/bash_completion"
    fi
    nvm "$@"
  }
fi

# SDKMAN (lazy-load)
export SDKMAN_DIR="${SDKMAN_DIR:-$HOME/.sdkman}"
if [ -s "$SDKMAN_DIR/bin/sdkman-init.sh" ]; then
  sdk() {
    unset -f sdk
    # shellcheck source=/dev/null
    . "$SDKMAN_DIR/bin/sdkman-init.sh"
    sdk "$@"
  }
fi
