eval "$(ssh-agent -s)" >/dev/null
[ -f "$HOME/.ssh/id_rsa_adastra" ] && ssh-add -q "$HOME/.ssh/id_rsa_adastra"
