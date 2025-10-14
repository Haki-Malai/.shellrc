# Shared ignore list and helpers for traversal commands

# Globs to skip everywhere
# Extend by exporting _SHELLRC_IGNORE_GLOBS before sourcing, if needed.
if [ -z "${_SHELLRC_IGNORE_GLOBS+x}" ]; then
  _SHELLRC_IGNORE_GLOBS=(
    '.git' '.git/*' '*/.git' '*/.git/*'
    '__pycache__' '__pycache__/*' '*/__pycache__' '*/__pycache__/*'
    '.venv' '.venv/*' 'venv' 'venv/*' '*/.venv' '*/venv' '*/venv/*'
    'node_modules' 'node_modules/*' '*/node_modules' '*/node_modules/*'
    '.mypy_cache' '.mypy_cache/*' '*/.mypy_cache' '*/.mypy_cache/*'
    '.pytest_cache' '.pytest_cache/*' '*/.pytest_cache' '*/.pytest_cache/*'
    '.tox' '.tox/*' '*/.tox' '*/.tox/*'
  )
fi

# Test if a path should be ignored
_shellrc_should_ignore() {
  local p="$1" g
  for g in "${_SHELLRC_IGNORE_GLOBS[@]}"; do
    [[ "$p" == $g ]] && return 0
  done
  return 1
}

# Find prune expression for directories
_shellrc_find_prune_set() {
  [ -n "${ZSH_VERSION-}" ] && typeset -ga _SHELLRC_PRUNE || true
  _SHELLRC_PRUNE=(
    '('
      -path "./.git" -o -path "*/.git" -o
      -path "*/__pycache__" -o
      -path "*/.venv" -o -path "*/venv" -o
      -path "*/node_modules" -o
      -path "*/.mypy_cache" -o
      -path "*/.pytest_cache" -o
      -path "*/.tox"
    ')' -prune -o
  )
}
