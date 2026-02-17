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

## 3) User-Facing Function Contracts

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
  - Optional tree prelude via `--tree`.
- Stdout pattern:
  - On success: `copied <N> lines, <M> bytes to clipboard`.
  - Output payload in clipboard includes section markers:
    - `=== <cwd> ===`
    - `----- <relative-file> -----`
  - On help: starts with `Usage: lscatclip`.
- Stderr pattern:
  - Argument errors: `missing pattern for --glob`, `missing CSV for --in`, `missing CSV for --out`, `missing CSV for --includes`, `unknown arg: <arg>`.
  - Context/filter errors: `no such directory: <path>`, `not a git repo`, `cannot use --diff on main branch`, `no main branch`, `no files matched`.
  - Optional warning: `warning: <N> lines exceed <limit> (max <M>)`.
- Exit behavior:
  - `0` success.
  - `2` argument parsing errors.
  - `1` runtime/context/no-match errors.
- Side effects:
  - Clipboard write.
- Manual verification:
  - `lscatclip -h`
  - `lscatclip --git --in '*.sh'`
  - `lscatclip --tree --glob '*.md'`

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
  - Delegate all other subcommands to upstream `git`.
- Output pattern:
  - Mirrors upstream `git` for the delegated command.
- Exit behavior:
  - Mirrors upstream `git` for the delegated command.
- Side effects:
  - Same as upstream `git` for the delegated command.
  - `git stash` default behavior includes untracked files in created stashes.
- Manual verification:
  - `type git` (or `typeset -f git`) and confirm wrapper includes `--no-pager`.
  - In a git repo with tracked + untracked changes, run `git stash -m "check"` and confirm untracked files are removed from working tree and present in `git stash show --name-only --include-untracked stash@{0}`.

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
  - First call lazy-loads NVM and delegates arguments to real `nvm`.
- Output pattern:
  - No project-specific stable output; delegated to upstream `nvm`.
- Exit behavior:
  - Mirrors upstream `nvm` behavior after load.
- Side effects:
  - Loads NVM functions into current shell session.
- Manual verification:
  - `type nvm` and `nvm --version` (when installed).

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

## 4) Alias Contracts

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
| `nmr` (Linux) | Restart NetworkManager service. | No stable output guaranteed. | Mirrors `systemctl`. | Network interruption/restart. | `alias nmr` |
| `webunblocker` (Linux) | Remove `/etc/hosts`, then run `nmr`. | No stable output guaranteed. | Mirrors underlying commands. | Deletes `/etc/hosts`, restarts network. | `alias webunblocker` |

## 5) Repo Script Contracts

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

## 6) Internal Loaded Helpers (No Stable User Output Contract)
The following are implementation helpers, not direct user contracts:
- `_shellrc_should_ignore`, `_shellrc_find_prune_set`, `_shellrc_render_tree`, `_clip_cmd`
- `_dots_now`, `_dots_tmpdir`, `_dots_autoupdate_run`, `_dots_autoupdate_start`
- `_shellrc_source_env_file`, `_shellrc_auto_env`
- `_shellrc_lan_ip`, `_ip_mask`, `_git_branch`, `_venv_seg`, `_git_seg`, `_py_seg`, `_node_seg`, `_npm_seg`, `_ip_seg`, `__visible_len`, `_build_prompt`, `precmd`
- `_shellrc_restore_keys`, `_load_glob`, `_load_funcs`

Agents should not assert stable output contracts for these helpers unless they are intentionally promoted to user-facing commands.

## 7) Current Observed Gaps (Traceability)
- Observation date: February 17, 2026.
- `./tests/run.sh` has a confirmed `zsh` failure with:
  - parse error near `(` from `shell/rc/12-safety-keys.sh:6`.
- In some environments, `bash` may also fail early before test execution because:
  - `shell/rc/20-autoupdate.sh` reads a timestamp file via `read -r last < "$ts"` under `set -e`.
  - If the timestamp file has no trailing newline, `read` can return non-zero and abort shell init.
- This is an observed implementation gap relative to intended cross-shell compatibility; this document remains normative for expected user behavior.

## 8) Source Traceability
Contracts in this document are grounded in:
- `shell/functions/clip_backend.sh`
- `shell/functions/lsclip.sh`
- `shell/functions/lscatclip.sh`
- `shell/functions/lstype.sh`
- `shell/functions/gdc.sh`
- `shell/rc/20-aliases.sh`
- `shell/rc/90-os-linux.sh`
- `shell/rc/init.sh`
- `tests/run.sh`
- `tests/suite.sh`
- `shell/shared-sync.sh`

## 9) Agent Specification Maintenance Rules
- If an agent believes behavior may have changed from this specification (or is ambiguous), the agent must explicitly notify the user and request user verification/check before finalizing claims about expected behavior.
- For any user-requested functionality change (adding, refactoring, or removing behavior), updating `SPECIFICATIONS.md` in the same change is mandatory.
- "Spec updated" means the affected command/alias/script contract sections are revised to reflect the new expected user-facing behavior and output patterns.
- This update requirement is always-on and has no optional path for behavior changes requested by the user.
