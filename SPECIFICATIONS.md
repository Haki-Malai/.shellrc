# User-Facing Command Specifications

## 1) Scope And Assumptions
- This specification describes expected behavior from a user perspective.
- It applies when `shell/rc/init.sh` is sourced in an interactive shell.
- Output checks are pattern-based (stable markers), not strict byte-for-byte snapshots.
- OS-specific commands are marked where behavior differs on macOS vs Linux.
- Internal helper functions are loaded at runtime but are not user-facing contracts.

## 2) Output Matching Rules
- "Pattern" means required text fragments and semantic shape (for example, `copied <N> lines, <M> bytes to clipboard`).
- Dynamic values (paths, counts, bytes, branch names, versions, timestamps) are variable and not exact-match fields.
- For commands without stable output, behavior and side effects are the contract.

## 3) Startup Behavior

### User switch safety
- Expected behavior:
  - During interactive startup, if the current directory is inside another user's home path (`/Users/<user>/...` on macOS or `/home/<user>/...` on Linux), change directory to the current user's home directory when it can be resolved.
  - If the current user, current directory owner segment, or current user's home cannot be resolved, leave the directory unchanged.
- Output pattern:
  - No stdout or stderr expected.
- Exit behavior:
  - Startup continues even if the directory cannot be changed.
- Side effects:
  - Current shell directory may change to the current user's home after a user switch.
- Manual verification:
  - Switch to another user from a path under the previous user's home and confirm `pwd` is the new user's home after shell startup.

### `pyenv` initialization (conditional)
- Expected behavior:
  - Initializes `pyenv` only when `pyenv` is on `PATH` and `$PYENV_ROOT` is safe for the current user.
  - Skips initialization when `$PYENV_ROOT` or `$PYENV_ROOT/shims` exists but is not writable, or when `$PYENV_ROOT` points into another user's `/Users/<user>` or `/home/<user>` tree.
- Output pattern:
  - No project-specific stable output; delegated to upstream `pyenv` when initialized.
- Exit behavior:
  - Startup continues when `pyenv` is missing or skipped.
- Side effects:
  - When initialized, `$PYENV_ROOT/bin` and `$PYENV_ROOT/shims` are prepended to `PATH`.
  - When skipped, another user's shims are not prepended and no rehash is attempted.
- Manual verification:
  - Source `shell/rc/init.sh` as a different user with inherited `PYENV_ROOT` pointing at the previous user's pyenv and confirm there is no `pyenv: cannot rehash` error.

## 4) User-Facing Function Contracts

### `clip`
- Expected behavior:
  - Read stdin and write it to the first available clipboard backend.
  - Backend priority: `pbcopy`, `wl-copy`, `xclip`, `xsel`, `clip.exe`.
- Stdout pattern:
  - No stdout required.
- Stderr pattern:
  - On missing backend: contains `install pbcopy/wl-copy/xclip/xsel`.
- Exit behavior:
  - `0` on success.
  - non-zero on backend-unavailable error.
- Side effects:
  - System clipboard contents are replaced.
- Manual verification:
  - `printf 'hello\n' | clip` then paste and confirm `hello`.

### `lsclip`
- Expected behavior:
  - In a git repo, build a compact tree of tracked files (with ignore rules) and copy it to clipboard.
  - Supports `-n|--max-depth N` and optional directory argument.
- Stdout pattern:
  - On success: `copied <N> lines, <M> bytes to clipboard`.
  - On help: `Usage: lsclip [-n N|--max-depth N] [DIR]`.
- Stderr pattern:
  - `unknown arg: <arg>`, `no such directory: <path>`, or `not a git repo` for relevant failures.
- Exit behavior:
  - `0` success.
  - `2` argument parsing errors.
  - `1` runtime/context errors.
- Side effects:
  - Clipboard write.
- Manual verification:
  - `lsclip -h`
  - `lsclip` from a git repo.

### `lscatclip`
- Expected behavior:
  - Collect files by git mode (`--git`/`--diff`) or glob mode (`--in`/`--glob`), apply excludes (`--out`), optional content filter (`--includes`), then copy concatenated file blocks to clipboard.
  - In `--diff` mode, select files from `git diff --name-only main` plus untracked files, and append `git diff --no-color main` output at the end.
  - Optional tree prelude via `--tree`.
  - `--dry` prints would-copy counts instead of writing to the clipboard.
- Stdout pattern:
  - On success: `copied <N> lines, <M> bytes to clipboard`.
  - With `--dry`: `would copy <N> lines, <M> bytes to clipboard`.
  - Output payload in clipboard includes section markers:
    - `=== <cwd> ===`
    - `----- <relative-file> -----`
    - `=== GIT DIFF: main ===` (for `--diff`)
  - On help: starts with `Usage: lscatclip`.
- Stderr pattern:
  - Argument errors: `missing pattern for --glob`, `missing CSV for --in`, `missing CSV for --out`, `missing CSV for --includes`, `unknown arg: <arg>`.
  - Context/filter errors: `no such directory: <path>`, `not a git repo`, `no main branch`, `no files matched`.
  - Optional warning: `warning: <N> lines exceed <limit> (max <M>)`.
- Exit behavior:
  - `0` success.
  - `2` argument parsing errors.
  - `1` runtime/context/no-match errors.
- Side effects:
  - Clipboard write.
  - No clipboard write with `--dry`.
- Manual verification:
  - `lscatclip -h`
  - `lscatclip --git --in '*.sh'`
  - `lscatclip --diff --in '*.sh'`
  - `lscatclip --tree --glob '*.md'`
  - `lscatclip --dry --glob '*.md'`

### `lstype`
- Expected behavior:
  - Recursively rank file extensions by total lines (default) or bytes.
  - Supports limit with `-n|--limit`.
- Stdout pattern:
  - Header lines:
    - `# top <N|all> file types by <lines|bytes>`
    - `# total <lines|bytes>: <number>`
    - `count<TAB>type`
  - Data lines: `<count><TAB>.<ext>` or `<count><TAB>[noext]`.
  - Help starts with `Usage: lstype`.
- Stderr pattern:
  - `missing value for --limit`, `limit must be an integer >= 0`, `unknown arg: <arg>`, `no such directory: <path>`, `python is required for lstype`, `no files found`.
- Exit behavior:
  - `0` success.
  - `2` argument parsing/validation errors.
  - `1` runtime/context/no-file errors.
- Side effects:
  - None expected.
- Manual verification:
  - `lstype -h`
  - `lstype --bytes --limit 5`

### `git` (wrapper)
- Expected behavior:
  - Invoke `git` with `--no-pager` by default.
  - For stash push flows (`git stash`, `git stash -...`, `git stash push`, `git stash save`), include `--include-untracked` by default.
  - For `git push -f` and `git push --force`, include `--no-verify` and replace the force flag with `--force-with-lease` before delegating to upstream `git`.
  - `git lc` counts added and removed lines in the current staged changes; when there are no staged changes, it counts all uncommitted tracked changes plus untracked text file lines. `git lc -v [branch]` also prints current per-file counts, branch diff counts against `origin/main` by default (or `origin/<branch>`/`<branch>` when provided), and a branch-plus-current total.
  - `git yolo` finds the newest author/committer identity in local commit history whose name contains `malai`, runs `git add .` only when there are no staged changes, amends with that identity when found, and when `-f` or `--force` is passed amends with `--no-verify` before pushing with `--no-verify --force-with-lease`.
  - After successful `git commit` commands, print the resulting `HEAD` author account.
  - After successful `git checkout` commands that switch away from a named branch, set `previousBranch` to the branch name from before the checkout.
  - `git ri [branch]` defaults `branch` to `main`; it fetches the selected branch from `origin`, checks out the local branch, fast-forwards it to `origin/<branch>`, checks out the original branch, sets `previousBranch` to the selected branch, then starts `git rebase -i <branch>`.
  - Delegate all other subcommands to upstream `git`.
- Output pattern:
  - Mirrors upstream `git` for the delegated command.
  - `git lc` prints one line as green `+<added>` then red `-<removed>`, for example `+4 -12`. `git lc -v [branch]` prints `current`, `branch (<ref>)`, and `branch + current` sections. Per-file rows are `+<added> -<removed> <path>`, and each section ends with or contains a `+<added> -<removed> total` row.
  - `git yolo` mirrors upstream output for the add command when it runs, the amend commit command, plus the `--no-verify --force-with-lease` push command when `-f` or `--force` is passed; the forced amend commit runs with `--no-verify`.
  - `git ri` mirrors upstream output for fetch, checkout, fast-forward merge, and interactive rebase commands against the selected base branch.
  - On successful commit, prints `Commiter identity: <name> <email>` using the resulting `HEAD` author, with `<name>` colored using the same 256-color code as the prompt username.
- Exit behavior:
  - Mirrors upstream `git` for the delegated command.
  - `git yolo` stops at the first failing command and returns that non-zero exit status.
- Side effects:
  - Same as upstream `git` for the delegated command.
  - `git checkout` may update the current shell variable `previousBranch` after a successful branch switch.
  - `git ri` updates local refs from `origin`, may fast-forward the selected local base branch, and may rewrite the original branch through interactive rebase.
  - `git stash` default behavior includes untracked files in created stashes.
  - `git lc` has no intended side effects.
  - `git yolo` stages all working tree changes under the current directory only when there are no staged changes; when staged changes already exist, it amends only those staged changes and leaves other working tree changes unstaged. It may set the amended commit author/committer from local `malai` history, amends the current commit without editing the message, and when `-f` or `--force` is passed amends with `--no-verify` before pushing with `--no-verify --force-with-lease` to the configured upstream.
- Manual verification:
  - `type git` (or `typeset -f git`) and confirm wrapper includes `--no-pager`.
  - In a disposable git repo with `main` and `feature` branches, run `git checkout main` from `feature` and confirm `echo "$previousBranch"` prints `feature`; then run `git checkout "$previousBranch"` and confirm the current branch is `feature` and `previousBranch` is `main`.
  - In a disposable git repo where `origin/main` is ahead of local `main`, run `GIT_SEQUENCE_EDITOR=true git ri` from `feature` and confirm local `main` equals `origin/main`, current branch is still `feature`, `previousBranch` is `main`, and `git merge-base feature main` equals `main`.
  - In a disposable git repo where `origin/dev` is ahead of local `dev`, run `GIT_SEQUENCE_EDITOR=true git ri dev` from `feature` and confirm local `dev` equals `origin/dev`, current branch is still `feature`, `previousBranch` is `dev`, and `git merge-base feature dev` equals `dev`.
  - In a git repo with tracked + untracked changes, run `git stash -m "check"` and confirm untracked files are removed from working tree and present in `git stash show --name-only --include-untracked stash@{0}`.
  - In a git repo with a branch ahead of `origin/main`, unstaged tracked changes, and an untracked text file, run `git lc` and `git lc -v` and confirm current, branch, and branch-plus-current totals; then stage the tracked file, run `git lc` and `git lc -v`, and confirm only staged changes are included in the current and branch-plus-current totals. Run `git lc -v dev` and confirm the branch section uses `origin/dev` when it exists.
  - In a disposable git repo with a temporary local bare remote, change a tracked file, run `git yolo`, and confirm only the local branch points to the amended commit; stage one tracked file while leaving another tracked file unstaged, run `git yolo`, and confirm only the staged file is amended; then install failing pre-commit and pre-push hooks, run `git yolo -f`, and confirm the local and remote branch point to the amended commit.
  - In a disposable git repo with a stale remote-tracking branch, run `git push -f` and `git push --force` and confirm they do not overwrite the remote branch; then refresh the remote-tracking branch, install a failing pre-push hook, run `git push -f`, and confirm the push succeeds.

### `gdc`
- Expected behavior:
  - Fetch `origin` quietly.
  - Diff from `origin` default branch ref to `HEAD`.
  - Copy diff output to clipboard.
- Stdout pattern:
  - `Copied git diff: <changed> lines (+<added> / -<removed>)`.
- Stderr pattern:
  - Clipboard backend errors may surface from `clip`.
- Exit behavior:
  - `0` success.
  - non-zero if clipboard write fails (or git operation fails before copy).
- Side effects:
  - Network read via `git fetch`.
  - Clipboard write.
- Manual verification:
  - `gdc` in a git repo with local diff vs remote default branch.

### `dots_diag`
- Expected behavior:
  - Print runtime shell config diagnostics.
- Stdout pattern:
  - Contains:
    - `DOTS_ROOT=<path>`
    - `DOTS_OS=<mac|linux|other>`
    - `shell=<zsh|bash>`
  - May also contain `clip=<path>` when `clip` resolves.
- Exit behavior:
  - `0` expected.
- Side effects:
  - None.
- Manual verification:
  - `dots_diag`

### `nvm` (conditional)
- Expected behavior:
  - Available only if `$NVM_DIR/nvm.sh` exists.
  - First call lazy-loads NVM without auto-selecting a Node version, then delegates arguments to real `nvm`.
- Output pattern:
  - No project-specific stable output; delegated to upstream `nvm`.
- Exit behavior:
  - Mirrors upstream `nvm` behavior after load.
- Side effects:
  - Loads NVM functions into current shell session.
  - Does not run NVM's default `use` behavior during lazy-load.
- Manual verification:
  - `type nvm` and `nvm --version` (when installed).
  - In a clean shell without Node already on `PATH`, source `shell/rc/init.sh`, run `nvm current`, and confirm the loader does not switch to the NVM default alias before the explicit command.

### `sdk` (conditional)
- Expected behavior:
  - Available only if `$SDKMAN_DIR/bin/sdkman-init.sh` exists.
  - First call lazy-loads SDKMAN and delegates to real `sdk`.
- Output pattern:
  - No project-specific stable output; delegated to upstream SDKMAN.
- Exit behavior:
  - Mirrors upstream `sdk` behavior after load.
- Side effects:
  - Loads SDKMAN functions into current shell session.
- Manual verification:
  - `type sdk` and `sdk version` (when installed).

## 5) Alias Contracts

| Alias | Expected behavior | Output pattern | Exit behavior | Side effects | Manual verification |
| --- | --- | --- | --- | --- | --- |
| `ls` | Colorized `ls` variant based on platform/tools. | Underlying `ls` output, color enabled when supported. | Mirrors underlying `ls`. | None. | `alias ls`; `ls` |
| `vi` | Runs `vim`. | Mirrors `vim`. | Mirrors `vim`. | Opens editor. | `alias vi`; `vi --version` |
| `oc` | Runs `opencommit`. | Mirrors `opencommit`. | Mirrors `opencommit`. | Depends on tool. | `alias oc`; `type opencommit` |
| `grep` | Runs `grep` with excluded dirs (`__pycache__`, `node_modules`, `.git`). | Mirrors `grep` results minus excluded dirs. | Mirrors `grep`. | None. | `alias grep` |
| `bb` | Shutdown shortcut (`sudo shutdown -h now` on macOS, `shutdown 0` otherwise). | No stable output guaranteed. | Mirrors underlying shutdown command. | Host shutdown/halt. | `alias bb` (do not execute casually) |
| `bbr` | Restart shortcut (`sudo shutdown -r now` on macOS, `shutdown -r 0` otherwise). | No stable output guaranteed. | Mirrors underlying shutdown command. | Host restart. | `alias bbr` (do not execute casually) |
| `python` | Maps to `python3`. | Mirrors `python3`. | Mirrors `python3`. | None. | `alias python`; `python --version` |
| `pip` | Maps to `pip3`. | Mirrors `pip3`. | Mirrors `pip3`. | Package management side effects depend on command. | `alias pip`; `pip --version` |
| `nmr` | On Linux, restart NetworkManager. On macOS, flush DNS caches, restart `mDNSResponder`, and set `Wi-Fi` DNS servers to `1.1.1.1` and `8.8.8.8`. | No stable output guaranteed. | Mirrors underlying commands. | Network interruption/restart; on macOS also updates Wi-Fi DNS servers. | `alias nmr` |
| `webunblocker` (Linux) | Remove `/etc/hosts`, then run `nmr`. | No stable output guaranteed. | Mirrors underlying commands. | Deletes `/etc/hosts`, restarts network. | `alias webunblocker` |

## 6) Repo Script Contracts

### `tests/run.sh`
- Expected behavior:
  - Run the suite for `bash` and `zsh` when installed.
  - Uses isolated temp home/bin and stubs external clipboard/network commands.
- Stdout pattern:
  - `running <shell> ... ok|fail`
  - or `skip <shell> (not installed)` if unavailable.
- Exit behavior:
  - `0` when all executed shell suites pass.
  - `1` when any executed shell suite fails.
- Side effects:
  - Creates and removes temporary files/dirs under temp path.
- Manual verification:
  - `./tests/run.sh`

### `tests/suite.sh`
- Expected behavior:
  - Runs named tests via `tests_suite_main`.
  - Requires `DOTS_REPO_ROOT` and `SHELLRC_TEST_CLIP_OUTPUT` in environment.
- Stdout pattern:
  - Per-test lines: `  [pass/fail marker] <test name>`
  - Summary: `<shell>: <N> run, <M> failed`.
- Stderr pattern:
  - If required env is missing: `missing DOTS_REPO_ROOT or SHELLRC_TEST_CLIP_OUTPUT`.
- Exit behavior:
  - `0` when failed count is `0`.
  - `1` otherwise.
- Side effects:
  - Writes to configured clip output fixture path.
- Manual verification:
  - Usually via `./tests/run.sh` (direct invocation is harness-oriented).

### `shell/shared-sync.sh`
- Expected behavior:
  - Copy files from `shared/` to `$HOME`, preserving relative paths.
  - `--quiet` suppresses informational stderr messages.
- Output pattern:
  - Non-quiet mode may emit:
    - `shared-sync: <rel> -> <dest>`
    - `shared-sync: cannot create <dir>`
    - `shared-sync: failed to copy <src> -> <dest>`
- Exit behavior:
  - Expected `0` in normal operation paths (including no-op when prerequisites are missing).
- Side effects:
  - Writes/updates files under `$HOME`.
- Manual verification:
  - `shell/shared-sync.sh --quiet`

## 7) Internal Loaded Helpers (No Stable User Output Contract)
The following are implementation helpers, not direct user contracts:
- `_shellrc_should_ignore`, `_shellrc_find_prune_set`, `_shellrc_render_tree`, `_clip_cmd`
- `_dots_tmpdir`, `_dots_autoupdate_run`, `_dots_autoupdate_start`
- `_shellrc_source_env_file`, `_shellrc_auto_env`
- `_shellrc_current_user`, `_shellrc_user_home`, `_shellrc_path_home_user`, `_shellrc_home_for_current_user`, `_shellrc_cd_home_if_foreign_pwd`, `_shellrc_pyenv_root_is_safe`
- `_shellrc_lan_ip`, `_shellrc_prompt_username`, `_shellrc_prompt_user_hex`, `_shellrc_prompt_color_codes`, `_ip_mask`, `_git_branch`, `_venv_seg`, `_git_seg`, `_py_seg`, `_node_seg`, `_npm_seg`, `_ip_seg`, `__visible_len`, `_build_prompt`, `precmd`
- `_shellrc_restore_keys`, `_load_glob`, `_load_funcs`

Agents should not assert stable output contracts for these helpers unless they are intentionally promoted to user-facing commands.

## 8) Current Observed Gaps (Traceability)
- Observation date: May 13, 2026.
- No current observed gaps after `./tests/run.sh` passes in bash and zsh.

## 9) Source Traceability
Contracts in this document are grounded in:
- `shell/functions/clip_backend.sh`
- `shell/functions/lsclip.sh`
- `shell/functions/lscatclip.sh`
- `shell/functions/lstype.sh`
- `shell/functions/gdc.sh`
- `shell/rc/01-user-context.sh`
- `shell/rc/05-pyenv.sh`
- `shell/rc/12-safety-keys.sh`
- `shell/rc/20-aliases.sh`
- `shell/rc/50-prompt.sh`
- `shell/rc/90-os-linux.sh`
- `shell/rc/init.sh`
- `tests/run.sh`
- `tests/suite.sh`
- `shell/shared-sync.sh`

## 10) Agent Specification Maintenance Rules
- If an agent believes behavior may have changed from this specification (or is ambiguous), the agent must explicitly notify the user and request user verification/check before finalizing claims about expected behavior.
- For any user-requested functionality change (adding, refactoring, or removing behavior), updating `SPECIFICATIONS.md` in the same change is mandatory.
- "Spec updated" means the affected command/alias/script contract sections are revised to reflect the new expected user-facing behavior and output patterns.
- This update requirement is always-on and has no optional path for behavior changes requested by the user.
