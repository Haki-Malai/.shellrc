# Use repo-managed Bash on both OSes

# Linux
echo 'source "$HOME/path/to/<repo>/shell/rc/bootstrap.sh"' >> ~/.bashrc

# macOS (Bash users)
grep -q 'source ~/.bashrc' ~/.bash_profile 2>/dev/null || echo '[ -f ~/.bashrc ] && . ~/.bashrc' >> ~/.bash_profile
echo 'source "$HOME/path/to/<repo>/shell/rc/bootstrap.sh"' >> ~/.bashrc

# Hooks
git config core.hooksPath hooks
chmod +x hooks/pre-commit hooks/pre-push

# Env
cp -n env/env.example.sh env/env.sh
