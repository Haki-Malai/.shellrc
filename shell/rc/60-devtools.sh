# NVM
export NVM_DIR="${NVM_DIR:-$HOME/.nvm}"

_shellrc_prepend_latest_nvm_node() {
  local best_bin best_major best_minor best_patch dir major minor node_dir patch rest version

  node_dir="$NVM_DIR/versions/node"
  [ -d "$node_dir" ] || return 0
  if [ -n "${ZSH_VERSION-}" ]; then
    setopt LOCAL_OPTIONS NULL_GLOB
  fi

  best_major=-1
  best_minor=-1
  best_patch=-1
  for dir in "$node_dir"/v*; do
    [ -x "$dir/bin/node" ] || continue
    version="${dir##*/}"
    version="${version#v}"
    major="${version%%.*}"
    rest="${version#*.}"
    [ "$rest" != "$version" ] || continue
    minor="${rest%%.*}"
    patch="${rest#*.}"
    [ "$patch" != "$rest" ] || continue
    patch="${patch%%.*}"

    case "$major" in ""|*[!0-9]*) continue ;; esac
    case "$minor" in ""|*[!0-9]*) continue ;; esac
    case "$patch" in ""|*[!0-9]*) continue ;; esac

    if [ "$major" -gt "$best_major" ] ||
      { [ "$major" -eq "$best_major" ] && [ "$minor" -gt "$best_minor" ]; } ||
      { [ "$major" -eq "$best_major" ] && [ "$minor" -eq "$best_minor" ] && [ "$patch" -gt "$best_patch" ]; }; then
      best_major="$major"
      best_minor="$minor"
      best_patch="$patch"
      best_bin="$dir/bin"
    fi
  done

  [ -n "${best_bin-}" ] || return 0
  case ":${PATH-}:" in
    *":$best_bin:"*) ;;
    *) PATH="$best_bin${PATH:+:$PATH}"; export PATH ;;
  esac
}

_shellrc_prepend_latest_nvm_node
unset -f _shellrc_prepend_latest_nvm_node 2>/dev/null || true

if [ -s "$NVM_DIR/nvm.sh" ]; then
  nvm() {
    unset -f nvm
    # shellcheck source=/dev/null
    . "$NVM_DIR/nvm.sh" --no-use
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
