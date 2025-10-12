# Your prompt, split out
white="\[\e[0;37m\]"; color_red="\[\e[0;1;38;5;196m\]"
lightGreen="\[\e[0;32m\]"; orange="\[\e[0;33m\]"; lightBlue="\[\e[0;94m\]"
npmRed="\[\e[0;1;38;5;167m\]"; nodeGreen="\[\e[0;1;32m\]"
pythonYellow="\[\e[0;1;38;5;226m\]"; gitColor="\[\e[0;1;94m\]"
firstLineChar=$white"\342\224\214"; secondLineChar="\342\224\224"; new_line="\n"
Xmark="\342\234\227"; cute_cat=$orange"🐈"
xMark='$([[ $? != 0 ]] && echo "['$color_red$Xmark$white']-")'
usrPrompt="[\[\e[0;5;38;5;197m\]\$"$white"]-"
if [ ${EUID} != 0 ]; then username="["$orange"\u"$white"]-"; fi
time="["$lightBlue"\A"$white"]-"
ip='['$color_red$((curl -s --max-time 1 icanhazip.com || echo localhost) | sed -E -e "s/[(1-3)(8-9)]/*/g")$white']-'
node='$(find -maxdepth 1 -type f -name "*.js*" 2>/dev/null | grep -q . && node -v | awk '"'"'{print"\033[0m['$nodeGreen'"$1"\033[0m]-"}'"'"')'$white
npm='$(find -maxdepth 1 -type f -name "*.js*" 2>/dev/null | grep -q . && npm -v | awk '"'"'{print"\033[0m['$npmRed'"$1"\033[0m]-"}'"'"')'$white
python='$(find -maxdepth 1 -type f -name "*.py" 2>/dev/null | grep -q . && python3 -V | awk '"'"'{print"\033[0m['$pythonYellow'"$2"\033[0m]-"}'"'"')'$white
gitBranch='$(git branch 2>/dev/null | grep ^* | awk '"'"'{print"\033[0m['$gitColor'"$2"\033[0m]-"}'"'"')'$white
workDir="["$lightGreen"\w"$white"]"
virtualEnv='$([[ -n ${VIRTUAL_ENV-} ]] && echo -e "[${pythonYellow}${VIRTUAL_ENV##*/}${white}]-")'
firstLine=$firstLineChar$xMark$virtualEnv$username$time$ip$gitBranch$python$node$npm$workDir
secondLine=$new_line$white$secondLineChar$usrPrompt$cute_cat$white
cursor_style_full_block_blinking=6
PS1=$firstLine$secondLine
