# shell/rc/50-prompt.sh

# ---------------------------
# zsh prompt (native, pretty)
# ---------------------------
if [ -n "${ZSH_VERSION-}" ]; then
  eval '
    autoload -U colors && colors
    setopt PROMPT_SUBST
    setopt EXTENDED_GLOB
    _ip_mask() {
      local ip
      ip=$(curl -fsS --max-time 1 icanhazip.com 2>/dev/null || print -r -- localhost)
      print -r -- "$ip" | sed -E "s/[18-9]/*/g"
    }
    _git_branch() { git rev-parse --abbrev-ref HEAD 2>/dev/null }
    _venv_seg()   { [[ -n ${VIRTUAL_ENV-} ]] && printf "[%%F{226}%s%%f]-" "${VIRTUAL_ENV:t}"; }
    _git_seg()    { local b; b="$(_git_branch)"; [[ -n $b ]] && printf "[%%F{69}%s%%f]-" "$b"; }
    _py_seg()     { [[ -n *.py(#qN) ]] || return; local v; v=$(python3 -V 2>/dev/null | awk "{print \$2}"); [[ -n $v ]] && printf "[%%F{226}%s%%f]-" "$v"; }
    _node_seg()   { [[ -n *.js*(#qN) ]] || return; local v; v=$(node -v 2>/dev/null); [[ -n $v ]] && printf "[%%F{46}%s%%f]-" "$v"; }
    _npm_seg()    { [[ -n *.js*(#qN) ]] || return; local v; v=$(npm -v 2>/dev/null);  [[ -n $v ]] && printf "[%%F{167}%s%%f]-" "$v"; }
    PROMPT=$"%F{250}┌%f%(?..%F{196}[✗]%f-)$(_venv_seg)[%F{178}%n%f]-[%F{33}%*%f]-[%F{196}$(_ip_mask)%f]-$(_git_seg)$(_py_seg)$(_node_seg)$(_npm_seg)[%F{70}%~%f]\n%F{250}└%f[%F{213}$%f]-%F{178}🐈%f "
  '
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

