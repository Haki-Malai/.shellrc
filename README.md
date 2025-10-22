# Shell RC (bash + zsh)

Modular shell config that runs on **macOS zsh** and **Linux bash**. Secrets are kept local (`env/env.sh`) and blocked by Git hooks.

## Contents
- `shell/rc/init.sh` — one loader for both shells
- `shell/rc/*.sh` — numbered modules (aliases, prompt, tools, OS overrides)
- `env/env.example.sh` — template you commit
- `env/env.sh` — your local secrets (ignored)
- `hooks/` — pre-commit / pre-push secret guards

## 0) Prereqs
- macOS: zsh (default), `pbcopy`
- Linux: bash, and one of `wl-copy` or `xclip` or `xsel`
- Optional: `gitleaks` for stronger secret scanning
- Common: `git`

## 1) Clone
```bash
git clone https://github.com/Haki-Malai/.shellrc.git
cd ~/.shellrc

2) Wire the shell
macOS (zsh)

Append to ~/.zshrc:

# Shell RC
[ -f "$HOME/.shellrc/shell/rc/init.sh" ] && source "$HOME/.shellrc/shell/rc/init.sh"

Linux (bash)

Append to ~/.bashrc:

# Shell RC
[ -f "$HOME/.shellrc/shell/rc/init.sh" ] && . "$HOME/.shellrc/shell/rc/init.sh"

    If macOS doesn't read ~/.zshrc for login shells, also ensure ~/.zprofile sources it:

grep -q 'source ~/.zshrc' ~/.zprofile 2>/dev/null || echo 'source ~/.zshrc' >> ~/.zprofile

3) Secrets file

cp -n env/env.example.sh env/env.sh
# edit env/env.sh with local values

4) Enable Git hooks

git config core.hooksPath hooks
chmod +x hooks/pre-commit hooks/pre-push

5) Verify

Open a new terminal, then check:

echo "$DOTS_OS"          # mac or linux
type clip                # should resolve to pbcopy/wl-copy/xclip/xsel/clip.exe
lscatclip -h             # helper usage
gdc                      # copies staged diff to clipboard (if in a repo)

## Tests

Run the cross-shell test suite (bash + zsh):

```bash
./tests/run.sh
```

The harness stubs clipboard and network calls so it can run on both Linux and macOS.
