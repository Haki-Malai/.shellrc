# Shell Testing and Manual Checks

Read when changing `.shellrc` shell behavior, test infrastructure, or command contracts. Documentation-only edits need link and consistency checks rather than shell regression tests unless they affect installation or loading.

## Requirements

- Every changed shell behavior must be testable and validated by both automated tests and manual checks.
- Add or extend coverage in `tests/suite.sh` for new behavior or changed behavior without existing coverage. Update `tests/run.sh` only when the harness needs it.
- Run `./tests/run.sh` when shell behavior may be affected. It runs the suite in Bash and Zsh when installed; report a skipped shell as a coverage gap.
- Test the changed commands and run broader regression for cross-cutting or uncertain impact.
- Manual checks must record the command invoked, observed output pattern, and pass/fail result. Keep command behavior/output documented in `SPECIFICATIONS.md`.

## Minimum change-to-test mapping

Paths below are relative to the repository root.

| Changed file(s) | Automated checks | Manual checks |
| --- | --- | --- |
| `shell/functions/clip_backend.sh` | `test_clip_backend` | `printf 'x\n' \| clip` |
| `shell/functions/lsclip.sh` | `test_lsclip_tree`, `test_lsclip_max_depth`, `test_lsclip_dir_arg`, `test_lsclip_non_git` | `lsclip -h`, `lsclip` in a Git repo |
| `shell/functions/lscatclip.sh` | All `test_lscatclip_*` tests | `lscatclip -h`, `lscatclip --git ...`, `lscatclip --diff ...` |
| `shell/functions/lstype.sh` | `test_lstype_lines`, `test_lstype_bytes`, `test_lstype_dir_arg` | `lstype -h`, `lstype --bytes` |
| `shell/functions/gdc.sh`, `shell/rc/70-git.sh` | Add/extend suite coverage for changed behavior | `gdc` in a Git repo, plus the changed Git command in a disposable fixture |
| `shell/rc/init.sh`, `shell/rc/20-aliases.sh` | `test_env_loads`, `test_aliases_exist` | `source shell/rc/init.sh`, `type <command>` |
| `shell/rc/50-prompt.sh` | `test_prompt_contains_cat` and affected prompt tests | Open an interactive shell and verify the prompt |
| `shell/functions/00-ignore-common.sh`, `shell/functions/_tree_helpers.sh` | Affected `lsclip`/`lscatclip`/`lstype` tests | Run affected commands manually |
| `tests/run.sh`, `tests/suite.sh` | `./tests/run.sh` | Targeted manual commands for the changed areas |

## Shared instruction installation

- Run `shell/shared-sync.sh` with a disposable target home; compare installed agent files with `shared/` and resolve their relative links from the installed file locations.
- Run sync again and verify identical files are left unchanged. Confirm unrelated destination files survive.
- Do not source the user's interactive shell or overwrite unrelated home files solely to validate documentation.
