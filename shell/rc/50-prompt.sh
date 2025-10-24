# shell/rc/50-prompt.sh

# ---------------------------
# zsh prompt (native, pretty)
# ---------------------------
if [ -n "${ZSH_VERSION-}" ]; then
  eval "$(cat <<'ZSH'
autoload -U colors && colors
setopt PROMPT_SUBST
setopt EXTENDED_GLOB

_git_branch() { git rev-parse --abbrev-ref HEAD 2>/dev/null }
_venv_seg()   { [[ -n ${VIRTUAL_ENV-} ]] && print -rn -- "[%F{226}${VIRTUAL_ENV:t}%f]-"; }
_git_seg()    { local b; b="$(_git_branch)"; [[ -n $b ]] && print -rn -- "[%F{69}$b%f]-"; }
_py_seg()     { local -a _py=( *.py(#qN) ); (( ${#_py} )) || return; local v; v=$(python3 -V 2>/dev/null | awk '{print $2}'); [[ -n $v ]] && print -rn -- "[%F{226}$v%f]-"; }
_node_seg()   { local -a _js=( *.js*(#qN) ); (( ${#_js} )) || return; local v; v=$(node -v 2>/dev/null); [[ -n $v ]] && print -rn -- "[%F{46}$v%f]-"; }
_npm_seg()    { local -a _js=( *.js*(#qN) ); (( ${#_js} )) || return; local v; v=$(npm -v 2>/dev/null);  [[ -n $v ]] && print -rn -- "[%F{167}$v%f]-"; }

PROMPT=$'%F{250}┌%f%(?..%F{196}[✗]%f-)$(_venv_seg)[%F{178}%n%f]-[%F{33}%*%f]-$(_git_seg)$(_py_seg)$(_node_seg)$(_npm_seg)[%F{70}%~%f]\n%F{250}└%f[%F{213}$%f]-%F{178}🐈%f '
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
  ip='['$color_red$((curl -s --max-time 1 icanhazip.com || echo localhost) | sed -E -e "s/[(1-3)(8-9)]/*/g")$white']-'
  node='$(find -maxdepth 1 -type f -name "*.js*" 2>/dev/null | grep -q . && node -v | awk '"'"'{print"\033[0m['$nodeGreen'"$1"\033[0m]-"}'"'"')'$white
  npm='$(find -maxdepth 1 -type f -name "*.js*" 2>/dev/null | grep -q . && npm -v | awk '"'"'{print"\033[0m['$npmRed'"$1"\033[0m]-"}'"'"')'$white
  python='$(find -maxdepth 1 -type f -name "*.py" 2>/dev/null | grep -q . && python3 -V | awk '"'"'{print"\033[0m['$pythonYellow'"$2"\033[0m]-"}'"'"')'$white
  gitBranch='$(git branch 2>/dev/null | grep ^* | awk '"'"'{print"\033[0m['$gitColor'"$2"\033[0m]-"}'"'"')'$white
  workDir="["$lightGreen"\w"$white"]"
  virtualEnv='$([[ -n ${VIRTUAL_ENV-} ]] && echo -e "[${pythonYellow}${VIRTUAL_ENV##*/}${white}]-")'
  firstLine=$firstLineChar$xMark$virtualEnv$username$time$ip$gitBranch$python$node$npm$workDir
  secondLine=$new_line$white$secondLineChar$usrPrompt"\[\e[0;33m\]🐈"$white
  PS1=$firstLine$secondLine
fi

