# Shell RC (bash + zsh)

Modular shell config that runs on **macOS zsh** and **Linux bash**. Secrets are kept local (`env/env.sh`) and blocked by Git hooks.

## Contents
- `shell/rc/init.sh` — one loader for both shells
- `shell/rc/*.sh` — numbered modules (aliases, prompt, tools, OS overrides)
- `env/env.example.sh` — template you commit
- `env/env.sh` — your local secrets (ignored)
- `hooks/` — pre-commit / pre-push secret guards
- `shared/.vimrc` — reusable Vim settings, with bundled Gruvbox under `shared/.vim/`

## 0) Prereqs
- macOS: zsh (default), `pbcopy`
- Linux: bash, and one of `wl-copy` or `xclip` or `xsel`
- Optional: `gitleaks` for stronger secret scanning
- Common: `git`

## 1) Clone
```bash
git clone https://github.com/Haki-Malai/.shellrc.git
cd ~/.shellrc
```

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

## Vim configuration

Interactive shell startup copies `shared/.vimrc` to `~/.vimrc` and the bundled
Gruvbox files to `~/.vim/`. To install or refresh them immediately from the
repository root:

```bash
shell/shared-sync.sh
```

The repository is the source of truth: customize `shared/.vimrc`, then sync it.
Later shell startups replace changes to the managed home copies, while unrelated
files under `~/.vim/` are preserved. Gruvbox is bundled at a fixed upstream revision
and requires no plugin manager or downloads during startup. Attribution, revision,
and license information are in `shared/.vim/gruvbox-source.txt`.

The defaults provide absolute line numbers, a highlighted current line, five lines
of scrolling context, syntax highlighting, and file-type-aware indentation with
four spaces as the fallback. Searches highlight matches as you type and ignore
case unless the query includes a capital letter. Backspace works across indentation
and line breaks; command completion shows a menu. Vim also shows editing mode,
partial commands, and cursor position. Mouse capture and saved undo history are off.

Gruvbox uses a dark background with medium contrast. True color is enabled when
Vim supports it and `COLORTERM` is `truecolor` or `24bit`; otherwise Vim retains
terminal color detection (Gruvbox supports 256 colors). If the theme file is absent,
Vim still opens with its default colors.

Quick reference (press `Esc` to return to normal mode first):

| Keys | Action |
| --- | --- |
| `i` | Start inserting text; `Esc` returns to normal mode |
| `/text` then Enter | Search forward; `n` / `N` move to the next / previous match |
| `Ctrl-L` | Clear search highlighting and redraw the screen |
| `:42` then Enter | Go to line 42 (use `:<number>` for any line) |
| `:number` then Enter | Print the current line with its line number |
| `:w` then Enter | Save |
| `:q` then Enter | Quit; Vim warns if changes have not been saved |
| `:wq` then Enter | Save and quit |

## Tests

Run the cross-shell test suite (bash + zsh):

```bash
./tests/run.sh
```

The harness stubs clipboard and network calls so it can run on both Linux and macOS.
