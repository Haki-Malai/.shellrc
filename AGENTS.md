# AGENTS.md

## Purpose And Scope
This file is the repo-local operating contract for agents working in this repository (`.shellrc`).
It is focused on correctness, traceability, minimal diffs, and test discipline.

Precedence for repo work:
1. Explicit user instruction in the current conversation.
2. This `AGENTS.md`.
3. Shared/global agent guidance (including `.codex` defaults).
4. Tool defaults.

If instructions conflict, stop and ask for direction.

## Non-Negotiables
- Do not fabricate. If not verified by command output or file content, state `unknown`.
- Prefer minimal diffs. Change the fewest files/lines needed.
- Do not stage/commit/push/merge unless the user explicitly asks.
- For any non-read-only remote command, present exact command(s), scope/risk/rollback, and get explicit user verification before running.
- Keep behavior and docs aligned: if command behavior/output changes, update `SPECIFICATIONS.md` in the same change.

## Required Workflow (Every Task)
### 1) Discovery (must run and summarize)
- `git status --short --branch`
- `git rev-parse --abbrev-ref HEAD`
- `git diff`
- If current branch is not `main`: `git diff main`

### 2) Plan Before Editing
- State the intended approach in 3-6 bullets.
- List files expected to change and why.
- If any high-impact ambiguity remains, ask before editing.

### 3) Execute
- Keep edits small and direct; avoid opportunistic refactors.
- Preserve existing comments/docstrings unless explicitly asked to change them.
- After edits, run `git diff` and summarize what changed and why.

### 4) Validate And Report
- Run relevant local checks.
- For this repo, use `./tests/run.sh` when shell behavior may be affected.
- Report results with concrete evidence (command output summary and/or file references).

## Testing Policy (Required)
- Every behavior change must be testable and tested.
- Every affected behavior must be validated in both:
  - automated tests, and
  - manual checks.
- New command/feature/behavior requires new automated tests in `tests/suite.sh` (and `tests/run.sh` harness updates if needed).
- Agents must run tests for commands they changed, plus broader regression for cross-cutting changes.
- If a command has no automated coverage and behavior is changed, add coverage as part of the same change.

## Change-To-Test Mapping
Use this minimum mapping when files are modified.

| File(s) changed | Automated checks | Manual checks |
| --- | --- | --- |
| `shell/functions/clip_backend.sh` | `test_clip_backend` | `printf 'x\n' \| clip` |
| `shell/functions/lsclip.sh` | `test_lsclip_tree`, `test_lsclip_max_depth`, `test_lsclip_dir_arg`, `test_lsclip_non_git` | `lsclip -h`, `lsclip` in a git repo |
| `shell/functions/lscatclip.sh` | All `test_lscatclip_*` tests | `lscatclip -h`, `lscatclip --git ...`, `lscatclip --diff ...` |
| `shell/functions/lstype.sh` | `test_lstype_lines`, `test_lstype_bytes`, `test_lstype_dir_arg` | `lstype -h`, `lstype --bytes` |
| `shell/functions/gdc.sh` or `shell/rc/70-git.sh` | Add/extend suite coverage if behavior changes | `gdc` in a git repo |
| `shell/rc/init.sh`, `shell/rc/20-aliases.sh` | `test_env_loads`, `test_aliases_exist` | `source shell/rc/init.sh`, `type <command>` |
| `shell/rc/50-prompt.sh` | `test_prompt_contains_cat` | open interactive shell and verify prompt |
| `shell/functions/00-ignore-common.sh`, `shell/functions/_tree_helpers.sh` | Re-run affected `lsclip`/`lscatclip`/`lstype` tests | Run affected commands manually |
| `tests/run.sh`, `tests/suite.sh` | `./tests/run.sh` | targeted manual command checks for changed areas |

For broad or uncertain impact, run the full suite: `./tests/run.sh`.

## Manual Validation Expectations
Manual checks must match changed behavior and include:
- command invocation used,
- observed output pattern,
- pass/fail result.

## Reporting Requirements
- Any factual claim must cite one of:
  - command output summary, or
  - file reference(s) with relevant lines.
- Separate observed facts from assumptions.
- If blocked, report what was tried, what was observed, and what is needed next.

