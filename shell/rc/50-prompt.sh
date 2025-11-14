# shell/rc/50-prompt.sh

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

# ---------------------------
# zsh prompt (native, pretty)
# ---------------------------
if [ -n "${ZSH_VERSION-}" ]; then
  eval "$(cat <<'ZSH'
autoload -U colors && colors
setopt PROMPT_SUBST
setopt EXTENDED_GLOB

typeset -g _PY_VERSION_CACHE _NODE_VERSION_CACHE _NPM_VERSION_CACHE

_ip_mask() {
  local ip
  ip="$(_shellrc_lan_ip 2>/dev/null || print -r -- "127.0.0.1")"
  print -r -- "$ip"
}
_git_branch() { git rev-parse --abbrev-ref HEAD 2>/dev/null }
_venv_seg()   { [[ -n ${VIRTUAL_ENV-} ]] && print -rn -- "[%F{226}${VIRTUAL_ENV:t}%f]-"; }
_git_seg()    { local b; b="$(_git_branch)"; [[ -n $b ]] && print -rn -- "[%F{69}$b%f]-"; }
_py_seg() {
  local -a _py=( *.py(#qN) )
  (( ${#_py} )) || return
  if [[ -z ${_PY_VERSION_CACHE-} ]]; then
    _PY_VERSION_CACHE=$(python3 -V 2>/dev/null | awk '{print $2}')
  fi
  [[ -n $_PY_VERSION_CACHE ]] && print -rn -- "[%F{226}${_PY_VERSION_CACHE}%f]-"
}
_node_seg() {
  local -a _js=( *.js*(#qN) )
  (( ${#_js} )) || return
  if [[ -z ${_NODE_VERSION_CACHE-} ]]; then
    _NODE_VERSION_CACHE=$(node -v 2>/dev/null)
  fi
  [[ -n $_NODE_VERSION_CACHE ]] && print -rn -- "[%F{46}${_NODE_VERSION_CACHE}%f]-"
}
_npm_seg() {
  local -a _js=( *.js*(#qN) )
  (( ${#_js} )) || return
  if [[ -z ${_NPM_VERSION_CACHE-} ]]; then
    _NPM_VERSION_CACHE=$(npm -v 2>/dev/null)
  fi
  [[ -n $_NPM_VERSION_CACHE ]] && print -rn -- "[%F{167}${_NPM_VERSION_CACHE}%f]-"
}
_ip_seg()     { print -rn -- "[%F{196}$(_ip_mask)%f]-"; }

__visible_len() {
  local expanded clean
  expanded=$(print -P -- "$1")
  clean=$(printf "%s" "$expanded" \
    | sed -E $'s/\x1B\\[[0-9;]*[ -\\/]*[@-~]//g; s/\x1B\\][^\a]*\a//g')
  print ${#clean}
}

: ${PROMPT_MAX:=$(( COLUMNS - 2 ))}

_build_prompt() {
  local show_ip=1 show_npm=1 show_node=1 show_py=1 first len

  local prefix="%F{250}┌%f%(?..%F{196}[✗]%f-)$(_venv_seg)[%F{178}%n%f]-[%F{33}%*%f]-"
  local suffix="[%F{70}%~%f]"
  local middle all

  local _assemble
  _assemble() {
    middle=""
    (( show_ip   )) && middle+="$(_ip_seg)"
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

precmd() { PROMPT_MAX=${PROMPT_MAX:-$(( COLUMNS - 2 ))}; _build_prompt }

_build_prompt

ZSH
)"
  return 0
fi

# ---------------------------
# bash prompt (original)
# ---------------------------
if [ -n "${BASH_VERSION-}" ]; then
  white="\[\e[0;37m\]"; color_red="\[\e[0;1;38;5;196m\]"
  lightGreen="\[\e[0;32m\]"; orange="\[\e[0;33m\]"; lightBlue="\[\e[0;94m\]"
  npmRed="\[\e[0;1;38;5;167m\]"; nodeGreen="\[\e[0;1;32m\]"
  pythonYellow="\[\e[0;1;38;5;226m\]"; gitColor="\[\e[0;1;94m\]"
  firstLineChar=$white"\342\224\214"; secondLineChar="\342\224\224"; new_line="\n"; Xmark="\342\234\227"

  xMark='$([[ $? != 0 ]] && echo "['$color_red$Xmark$white']-")'
  usrPrompt="[\[\e[0;5;38;5;197m\]\$"$white"]-"
  [ ${EUID} != 0 ] && username="["$orange"\u"$white"]-"
  time="["$lightBlue"\A"$white"]-"
  ip="[$color_red$(_shellrc_lan_ip)$white]-"
  node='$(find -maxdepth 1 -type f -name "*.js*" 2>/dev/null | grep -q . && node -v | awk '"'"'{print"\033[0m['$nodeGreen'"$1"\033[0m]-"}'"'"')'$white
  npm='$(find -maxdepth 1 -type f -name "*.js*" 2>/dev/null | grep -q . && npm --loglevel=silent -v | awk '"'"'{print"\033[0m['$npmRed'"$1"\033[0m]-"}'"'"')'$white
  python='$(find -maxdepth 1 -type f -name "*.py" 2>/dev/null | grep -q . && python3 -V | awk '"'"'{print"\033[0m['$pythonYellow'"$2"\033[0m]-"}'"'"')'$white
  gitBranch='$(git branch 2>/dev/null | grep ^* | awk '"'"'{print"\033[0m['$gitColor'"$2"\033[0m]-"}'"'"')'$white
  workDir="["$lightGreen"\w"$white"]"
  virtualEnv='$([[ -n ${VIRTUAL_ENV-} ]] && echo -e "[${pythonYellow}${VIRTUAL_ENV##*/}${white}]-")'
  firstLine=$firstLineChar$xMark$virtualEnv$username$time$ip$gitBranch$python$node$npm$workDir
  secondLine=$new_line$white$secondLineChar$usrPrompt"\[\e[0;33m\]🐈"$white
  PS1=$firstLine$secondLine
fi
