cd() {
  local previous_dir="$PWD"
  builtin cd "$@" || return $?
  lastDir="$previous_dir"
}
