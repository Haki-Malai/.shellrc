# shell/rc/50-prompt.sh

# The initial check waits for Docker; later prompt checks run in the background.
_shellrc_colima_cleanup() {
  if [ -n "${_SHELLRC_COLIMA_PID-}" ]; then
    kill "$_SHELLRC_COLIMA_PID" 2>/dev/null || true
  fi
  [ -z "${_SHELLRC_COLIMA_CACHE-}" ] || rm -rf -- "$_SHELLRC_COLIMA_CACHE"
  unset _SHELLRC_COLIMA_CACHE _SHELLRC_COLIMA_PID
}

_shellrc_colima_worker() {
  local cache="$1" storage="$2" generation="$3" state=unavailable response
  if ! command -v curl >/dev/null 2>&1; then
    state=unknown
  elif response="$(curl --silent --fail --max-time 1 --unix-socket "$storage/default/docker.sock" http://localhost/_ping)" && [ "$response" = OK ]; then
    state=healthy
  fi
  printf '%s %s\n' "$SECONDS" "$state" >"$cache/result.$generation.tmp" &&
    mv -f -- "$cache/result.$generation.tmp" "$cache/result.$generation"
}

_shellrc_colima_update() {
  [ -z "${ZSH_VERSION-}" ] || setopt local_options no_monitor no_notify
  local storage="${COLIMA_HOME:-$HOME/.colima}" checked state
  _SHELLRC_COLIMA_COLOR=244
  _SHELLRC_COLIMA_ICON='?'
  unset _SHELLRC_COLIMA_VISIBLE
  if [ -z "${_SHELLRC_COLIMA_CACHE-}" ]; then
    _SHELLRC_COLIMA_CACHE="$(mktemp -d /tmp/shellrc-colima.XXXXXX)" || return 0
    _SHELLRC_COLIMA_GENERATION=0
    _SHELLRC_COLIMA_LAST=-5
  fi
  if [ "${_SHELLRC_COLIMA_HOME-}" != "$storage" ]; then
    _SHELLRC_COLIMA_HOME="$storage"
    _SHELLRC_COLIMA_GENERATION=$(( ${_SHELLRC_COLIMA_GENERATION:-0} + 1 ))
    _SHELLRC_COLIMA_LAST=-5
  fi
  if [ -r "$_SHELLRC_COLIMA_CACHE/result.$_SHELLRC_COLIMA_GENERATION" ]; then
    read -r checked state <"$_SHELLRC_COLIMA_CACHE/result.$_SHELLRC_COLIMA_GENERATION"
    if [ "$(( SECONDS - checked ))" -lt 5 ]; then
      case "$state" in
        healthy) _SHELLRC_COLIMA_COLOR=46; _SHELLRC_COLIMA_ICON='●' ;;
        unavailable) _SHELLRC_COLIMA_COLOR=196; _SHELLRC_COLIMA_ICON='●' ;;
      esac
    fi
  fi
  [ "$_SHELLRC_COLIMA_ICON" = '?' ] || _SHELLRC_COLIMA_VISIBLE="$_SHELLRC_COLIMA_ICON"
  if [ -n "${_SHELLRC_COLIMA_PID-}" ] && kill -0 "$_SHELLRC_COLIMA_PID" 2>/dev/null; then
    return 0
  fi
  if [ "$(( SECONDS - _SHELLRC_COLIMA_LAST ))" -ge 5 ]; then
    _SHELLRC_COLIMA_LAST=$SECONDS
    if [ "${1-}" = --sync ]; then
      _shellrc_colima_worker "$_SHELLRC_COLIMA_CACHE" "$storage" "$_SHELLRC_COLIMA_GENERATION" >/dev/null 2>&1 || true
      _shellrc_colima_update
      return 0
    fi
    {
      if [ -n "${ZSH_VERSION-}" ]; then
        # Keep Zsh's detached-job syntax out of the shared Bash parser.
        eval '_shellrc_colima_worker "$_SHELLRC_COLIMA_CACHE" "$storage" "$_SHELLRC_COLIMA_GENERATION" >/dev/null 2>&1 &!'
      else
        _shellrc_colima_worker "$_SHELLRC_COLIMA_CACHE" "$storage" "$_SHELLRC_COLIMA_GENERATION" >/dev/null 2>&1 &
      fi
      _SHELLRC_COLIMA_PID=$!
      [ -n "${ZSH_VERSION-}" ] || disown "$_SHELLRC_COLIMA_PID" 2>/dev/null || true
    } >/dev/null 2>&1
  fi
  return 0
}

_shellrc_colima_prompt_tick() {
  _SHELLRC_PROMPT_EXIT_STATUS=$?
  _shellrc_colima_update
  return 0
}

# Shared LAN IP helper (cached)
_shellrc_lan_ip() {
  if [ -n "${_SHELLRC_LAN_IP_CACHE-}" ]; then
    printf '%s\n' "$_SHELLRC_LAN_IP_CACHE"
    return 0
  fi

  local ip=""
  case "${DOTS_OS:-}" in
    mac)
      if command -v ipconfig >/dev/null 2>&1; then
        ip=$(ipconfig getifaddr en0 2>/dev/null || ipconfig getifaddr en1 2>/dev/null)
      fi
      ;;
    linux)
      if command -v ip >/dev/null 2>&1; then
        ip=$(ip -4 addr show scope global 2>/dev/null | awk '/inet / { sub("/.*","",$2); print $2; exit }')
      fi
      if [ -z "$ip" ] && command -v hostname >/dev/null 2>&1; then
        ip=$(hostname -I 2>/dev/null | awk '{print $1}')
      fi
      ;;
  esac

  [ -n "$ip" ] || ip="127.0.0.1"
  _SHELLRC_LAN_IP_CACHE="$ip"
  printf '%s\n' "$_SHELLRC_LAN_IP_CACHE"
}

_shellrc_prompt_username() {
  if [ -n "${USER-}" ]; then
    printf '%s\n' "$USER"
  elif [ -n "${LOGNAME-}" ]; then
    printf '%s\n' "$LOGNAME"
  else
    id -un 2>/dev/null || printf '%s\n' "user"
  fi
}

_shellrc_prompt_user_hex() {
  local username hash
  username="${1:-$(_shellrc_prompt_username)}"
  hash=""

  if command -v sha256sum >/dev/null 2>&1; then
    hash="$(printf '%s' "$username" | sha256sum 2>/dev/null | awk '{print $1; exit}')"
  elif command -v shasum >/dev/null 2>&1; then
    hash="$(printf '%s' "$username" | shasum -a 256 2>/dev/null | awk '{print $1; exit}')"
  elif command -v cksum >/dev/null 2>&1; then
    hash="$(printf '%s' "$username" | cksum 2>/dev/null | awk '{printf "%08x%08x%08x\n", $1, ($1 * 1103515245 + 12345) % 4294967296, ($1 * 1664525 + 1013904223) % 4294967296; exit}')"
  fi

  [ -n "$hash" ] || hash="75736572"
  printf '%s\n' "$hash"
}

_shellrc_prompt_color_codes() {
  local username hash codes

  if [ "$#" -eq 0 ] && [ -n "${_SHELLRC_PROMPT_COLOR_CODES-}" ]; then
    printf '%s\n' "$_SHELLRC_PROMPT_COLOR_CODES"
    return 0
  fi

  username="${1:-$(_shellrc_prompt_username)}"
  hash="$(_shellrc_prompt_user_hex "$username")"
  hash="${hash}${hash}000000"
  codes="$((16 + (16#${hash:0:2} % 216))) $((16 + (16#${hash:2:2} % 216))) $((16 + (16#${hash:4:2} % 216)))"

  if [ "$#" -eq 0 ]; then
    _SHELLRC_PROMPT_COLOR_CODES="$codes"
  fi
  printf '%s\n' "$codes"
}

# ---------------------------
# zsh prompt (native, pretty)
# ---------------------------
if [ -n "${ZSH_VERSION-}" ]; then
  emulate zsh -c "$(cat <<'ZSH'
emulate -L zsh
autoload -U colors && colors
setopt PROMPT_SUBST
setopt EXTENDED_GLOB

typeset -g _PY_VERSION_CACHE _NODE_VERSION_CACHE _NPM_VERSION_CACHE
autoload -Uz add-zsh-hook
add-zsh-hook zshexit _shellrc_colima_cleanup

_ip_mask() {
  local ip
  ip="$(_shellrc_lan_ip 2>/dev/null || print -r -- "127.0.0.1")"
  print -r -- "$ip"
}
_git_branch() { git rev-parse --abbrev-ref HEAD 2>/dev/null }
_venv_seg()   { [[ -n ${VIRTUAL_ENV-} ]] && print -rn -- "[%F{226}${VIRTUAL_ENV:t}%f]-"; }
_git_seg()    { local b; b="$(_git_branch)"; [[ -n $b ]] && print -rn -- "[%F{69}$b%f]-"; }
_py_seg() {
  emulate -L zsh
  setopt EXTENDED_GLOB
  local -a _py=( *.py(#qN) )
  (( ${#_py} )) || return
  if [[ -z ${_PY_VERSION_CACHE-} ]]; then
    _PY_VERSION_CACHE=$(python3 -V 2>/dev/null | awk '{print $2}')
  fi
  [[ -n $_PY_VERSION_CACHE ]] && print -rn -- "[%F{226}${_PY_VERSION_CACHE}%f]-"
}
_node_seg() {
  emulate -L zsh
  setopt EXTENDED_GLOB
  local -a _js=( *.js*(#qN) )
  (( ${#_js} )) || return
  if [[ -z ${_NODE_VERSION_CACHE-} ]]; then
    _NODE_VERSION_CACHE=$(node -v 2>/dev/null)
  fi
  [[ -n $_NODE_VERSION_CACHE ]] && print -rn -- "[%F{46}${_NODE_VERSION_CACHE}%f]-"
}
_npm_seg() {
  emulate -L zsh
  setopt EXTENDED_GLOB
  local -a _js=( *.js*(#qN) )
  (( ${#_js} )) || return
  if [[ -z ${_NPM_VERSION_CACHE-} ]]; then
    _NPM_VERSION_CACHE=$(npm -v 2>/dev/null)
  fi
  [[ -n $_NPM_VERSION_CACHE ]] && print -rn -- "[%F{167}${_NPM_VERSION_CACHE}%f]-"
}
_ip_seg()     { local color="${1:-196}"; print -rn -- "[%F{${color}}$(_ip_mask)%f]-"; }

__visible_len() {
  local expanded clean
  expanded=$(print -P -- "$1")
  clean=$(printf "%s" "$expanded" \
    | sed -E $'s/\x1B\\[[0-9;]*[ -\\/]*[@-~]//g; s/\x1B\\][^\a]*\a//g')
  print ${#clean}
}

: ${PROMPT_MAX:=$(( COLUMNS - 2 ))}

_build_prompt() {
  local previous_status="${1:-$?}"
  emulate -L zsh
  setopt EXTENDED_GLOB
  local show_ip=1 show_npm=1 show_node=1 show_py=1 first len
  local -a prompt_colors
  local prompt_color_text
  prompt_color_text="$(_shellrc_prompt_color_codes)"
  prompt_colors=(${=prompt_color_text})
  local user_color="${prompt_colors[1]:-178}"
  local time_color="${prompt_colors[2]:-33}"
  local ip_color="${prompt_colors[3]:-196}"

  _shellrc_colima_update
  local error_segment=""
  (( previous_status == 0 )) || error_segment='%F{196}[✗]%f-'
  local colima_segment=""
  [[ -z ${_SHELLRC_COLIMA_VISIBLE-} ]] || colima_segment="[%F{${_SHELLRC_COLIMA_COLOR}}${_SHELLRC_COLIMA_VISIBLE}%f]-"
  local prefix="%F{250}┌%f${error_segment}$(_venv_seg)[%F{${user_color}}%n%f]-${colima_segment}[%F{${time_color}}%*%f]-"
  local suffix="[%F{70}%~%f]"
  local middle all

  local _assemble
  _assemble() {
    middle=""
    (( show_ip   )) && middle+="$(_ip_seg "$ip_color")"
    middle+="$(_git_seg)"
    (( show_py   )) && middle+="$(_py_seg)"
    (( show_node )) && middle+="$(_node_seg)"
    (( show_npm  )) && middle+="$(_npm_seg)"
    print -r -- "${prefix}${middle}${suffix}"
  }

  first=$(_assemble)
  len=$(__visible_len "$first")

  # drop in priority until within cap
  while (( len > PROMPT_MAX )); do
    if   (( show_ip   )); then show_ip=0
    elif (( show_npm  )); then show_npm=0
    elif (( show_node )); then show_node=0
    elif (( show_py   )); then show_py=0
    else break
    fi
    first=$(_assemble)
    len=$(__visible_len "$first")
  done

  PROMPT="${first}"$'\n'"%F{250}└%f[%F{213}$%f]-%F{178}🐈%f "
}

precmd() {
  local previous_status=$?
  unset _PY_VERSION_CACHE 2>/dev/null || true
  PROMPT_MAX=${PROMPT_MAX:-$(( COLUMNS - 2 ))}
  _build_prompt "$previous_status"
}

ZSH
)"
  _shellrc_colima_update --sync
  return 0
fi

# ---------------------------
# bash prompt (original)
# ---------------------------
if [ -n "${BASH_VERSION-}" ]; then
  # Append cleanup to an existing exit trap without discarding its command.
  if [ "${_SHELLRC_COLIMA_TRAP_INSTALLED-}" != 1 ]; then
    colima_exit_trap="$(trap -p EXIT)"
    colima_exit_trap="${colima_exit_trap#trap -- }"
    colima_exit_trap="${colima_exit_trap% EXIT}"
    [ -z "$colima_exit_trap" ] || eval "colima_exit_trap=$colima_exit_trap"
    trap "$colima_exit_trap
_shellrc_colima_cleanup" EXIT
    _SHELLRC_COLIMA_TRAP_INSTALLED=1
  fi
  case ";${PROMPT_COMMAND-};" in
    *';_shellrc_colima_prompt_tick;'*) ;;
    *) PROMPT_COMMAND="_shellrc_colima_prompt_tick${PROMPT_COMMAND:+;$PROMPT_COMMAND}" ;;
  esac
  prompt_colors="$(_shellrc_prompt_color_codes)"
  prompt_user_color="${prompt_colors%% *}"
  prompt_colors_rest="${prompt_colors#* }"
  prompt_time_color="${prompt_colors_rest%% *}"
  prompt_ip_color="${prompt_colors_rest##* }"

  white="\[\e[0;37m\]"; color_red="\[\e[0;1;38;5;196m\]"
  lightGreen="\[\e[0;32m\]"
  usernameColor="\[\e[0;1;38;5;${prompt_user_color:-178}m\]"
  timeColor="\[\e[0;1;38;5;${prompt_time_color:-33}m\]"
  ipColor="\[\e[0;1;38;5;${prompt_ip_color:-196}m\]"
  npmRed="\[\e[0;1;38;5;167m\]"; nodeGreen="\[\e[0;1;32m\]"
  pythonYellow="\[\e[0;1;38;5;226m\]"; gitColor="\[\e[0;1;94m\]"
  firstLineChar=$white"\342\224\214"; secondLineChar="\342\224\224"; new_line="\n"; Xmark="\342\234\227"

  xMark='$([[ ${_SHELLRC_PROMPT_EXIT_STATUS:-$?} != 0 ]] && echo "['$color_red$Xmark$white']-")'
  usrPrompt="[\[\e[0;5;38;5;197m\]\$"$white"]-"
  [ ${EUID} != 0 ] && username="["$usernameColor"\u"$white"]-"
  colima='${_SHELLRC_COLIMA_VISIBLE+[}\[\e[38;5;${_SHELLRC_COLIMA_COLOR:-244}m\]${_SHELLRC_COLIMA_VISIBLE-}'$white'${_SHELLRC_COLIMA_VISIBLE+]-}'
  time="["$timeColor"\A"$white"]-"
  ip="[$ipColor$(_shellrc_lan_ip)$white]-"
  node='$(find -maxdepth 1 -type f -name "*.js*" 2>/dev/null | grep -q . && node -v | awk '"'"'{print"\033[0m['$nodeGreen'"$1"\033[0m]-"}'"'"')'$white
  npm='$(find -maxdepth 1 -type f -name "*.js*" 2>/dev/null | grep -q . && npm --loglevel=silent -v | awk '"'"'{print"\033[0m['$npmRed'"$1"\033[0m]-"}'"'"')'$white
  python='$(find -maxdepth 1 -type f -name "*.py" 2>/dev/null | grep -q . && python3 -V | awk '"'"'{print"\033[0m['$pythonYellow'"$2"\033[0m]-"}'"'"')'$white
  gitBranch='$(git branch 2>/dev/null | grep ^* | awk '"'"'{print"\033[0m['$gitColor'"$2"\033[0m]-"}'"'"')'$white
  workDir="["$lightGreen"\w"$white"]"
  virtualEnv='$([[ -n ${VIRTUAL_ENV-} ]] && echo -e "[${pythonYellow}${VIRTUAL_ENV##*/}${white}]-")'
  firstLine=$firstLineChar$xMark$virtualEnv$username$colima$time$ip$gitBranch$python$node$npm$workDir
  secondLine=$new_line$white$secondLineChar$usrPrompt"\[\e[0;33m\]🐈"$white
  PS1=$firstLine$secondLine
  _shellrc_colima_update --sync
fi
