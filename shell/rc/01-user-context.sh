# Keep interactive shells sane after changing users without starting in $HOME.

case $- in *i*) :;; *) return 0 2>/dev/null || exit 0;; esac

_shellrc_current_user() {
  if command -v id >/dev/null 2>&1; then
    id -un 2>/dev/null && return 0
  fi
  if [ -n "${USER-}" ]; then
    printf '%s\n' "$USER"
  elif [ -n "${LOGNAME-}" ]; then
    printf '%s\n' "$LOGNAME"
  else
    return 1
  fi
}

_shellrc_user_home() {
  local user home
  user="$1"
  case "$user" in
    ''|*[!A-Za-z0-9._-]*) return 1 ;;
  esac

  home="$(eval "printf '%s\n' ~$user" 2>/dev/null)" || return 1
  case "$home" in
    "~$user"|'' ) return 1 ;;
  esac
  printf '%s\n' "$home"
}

_shellrc_path_home_user() {
  local path rest root
  path="$1"

  if [ -n "${SHELLRC_TEST_USERS_ROOT-}" ]; then
    root="${SHELLRC_TEST_USERS_ROOT%/}"
    case "$path" in
      "$root"/*)
        rest="${path#"$root"/}"
        printf '%s\n' "${rest%%/*}"
        return 0
        ;;
    esac
  fi

  case "$path" in
    /Users/*)
      rest="${path#/Users/}"
      printf '%s\n' "${rest%%/*}"
      ;;
    /home/*)
      rest="${path#/home/}"
      printf '%s\n' "${rest%%/*}"
      ;;
    *)
      return 1
      ;;
  esac
}

_shellrc_home_for_current_user() {
  local user home_user actual_home
  user="$1"
  home_user="$(_shellrc_path_home_user "${HOME-}" 2>/dev/null || true)"

  if [ -n "${HOME-}" ] && [ -d "$HOME" ] && { [ -z "$home_user" ] || [ "$home_user" = "$user" ]; }; then
    printf '%s\n' "$HOME"
    return 0
  fi

  actual_home="$(_shellrc_user_home "$user" 2>/dev/null || true)"
  if [ -n "$actual_home" ] && [ -d "$actual_home" ]; then
    printf '%s\n' "$actual_home"
    return 0
  fi

  return 1
}

_shellrc_cd_home_if_foreign_pwd() {
  local user pwd_user target_home
  user="$(_shellrc_current_user 2>/dev/null || true)"
  [ -n "$user" ] || return 0

  pwd_user="$(_shellrc_path_home_user "${PWD-}" 2>/dev/null || true)"
  [ -n "$pwd_user" ] || return 0
  [ "$pwd_user" != "$user" ] || return 0

  target_home="$(_shellrc_home_for_current_user "$user" 2>/dev/null || true)"
  [ -n "$target_home" ] || return 0
  [ -d "$target_home" ] || return 0
  cd -- "$target_home" 2>/dev/null || return 0
}

_shellrc_cd_home_if_foreign_pwd
