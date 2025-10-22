eval "$(ssh-agent -s)" >/dev/null
if [ -f "$HOME/.ssh/id_rsa_adastra" ]; then
  ssh-add -q "$HOME/.ssh/id_rsa_adastra"
fi
