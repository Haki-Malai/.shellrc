# .shellrc Agent Instructions

This repository manages shared dotfiles and Bash/Zsh commands. These instructions apply to work on this repository.

## Scope

- Edit this file only for `.shellrc` behavior and workflow. Common/global agent guidance belongs in [shared/.codex/AGENTS.md](shared/.codex/AGENTS.md) and its linked files, which shared-file sync installs under `$HOME/.codex/`.
- An explicit user path wins; ask if the intended scope remains unclear after inspection. Do not edit the generated home copy when the shared source exists.
- Follow system/developer instructions, explicit user instructions, this repository's guidance, then shared defaults. Ask only about conflicts unresolved by that precedence.

## Before changing files

- Read [editing and validation](shared/.codex/instructions/workflow.md) and [Git and remote work](shared/.codex/instructions/git-and-remote.md). Preserve existing work and summarize the required Git preflight before editing tracked files.
- Staging, commits, pushes, merges, and remote writes require explicit user authorization. Reuse it within scope; ask again only for the risk or scope changes described in the remote guide.
- Read the configured hooks in `hooks/pre-commit` and `hooks/pre-push`; follow them without bypassing their checks.
- Keep changes small and direct. Update `SPECIFICATIONS.md` in the same change when command behavior or output changes.

## Validation

- For shell behavior changes, read [testing and manual checks](docs/agent-instructions/testing.md). Every affected behavior needs automated coverage and a matching manual check.
- New command behavior needs coverage in `tests/suite.sh`; change `tests/run.sh` only if the harness needs it. Run `./tests/run.sh` when shell behavior may be affected, including cross-cutting changes.
- For instruction/documentation-only edits, verify links, scope, and consistency. When shared files are added or moved, verify installation and relative links with shared-file sync in a disposable target directory.
- After editing, review the targeted diff and follow [reporting](shared/.codex/instructions/reporting.md). Give the manual command, observed result, and pass/fail status when manual checks apply.
