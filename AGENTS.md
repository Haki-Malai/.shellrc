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
### 1) Discovery
- Do enough file/command discovery to understand the task before editing.
- Do not run `git status`, `git diff`, `git diff --cached`, or branch comparisons as routine preflight for read-only tasks, planning, explanations, or file inspection.
- Before editing any tracked file, or before running any git command that may mutate the working tree, index/stage, branch, or history, run and summarize:
  - `git status --short --branch`
  - `git diff`
  - `git diff --cached`
- Mutating or potentially mutating git commands include `git add`, `git restore`, `git reset`, `git checkout`, `git switch`, `git stash`, `git commit`, `git merge`, `git rebase`, `git cherry-pick`, `git clean`, and similar commands.
- Never run `git add .` as an agent convenience command. Staging requires an explicit user request; when staging is requested, prefer exact pathspecs and show the command before running it.
- Read-only git commands such as `git status`, `git diff`, `git diff --cached`, `git log`, `git show`, `git branch --show-current`, and `git rev-parse` do not trigger this preflight.

### 2) Plan Before Editing
- State the intended approach in 3-6 bullets.
- List files expected to change and why.
- If any high-impact ambiguity remains, ask before editing.

### 3) Execute
- Keep edits small and direct; avoid opportunistic refactors.
- Preserve existing comments/docstrings unless explicitly asked to change them.
- After edits, run a targeted diff for the touched file(s) and summarize what changed and why.

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

Behavioral guidelines to reduce common LLM coding mistakes. Merge with project-specific instructions as needed.

**Tradeoff:** These guidelines bias toward caution over speed. For trivial tasks, use judgment.

## 1. Think Before Coding

**Don't assume. Don't hide confusion. Surface tradeoffs.**

Before implementing:
- State your assumptions explicitly. If uncertain, ask.
- If multiple interpretations exist, present them - don't pick silently.
- If a simpler approach exists, say so. Push back when warranted.
- If something is unclear, stop. Name what's confusing. Ask.

## 2. Simplicity First

**Minimum code that solves the problem. Nothing speculative.**

- No features beyond what was asked.
- No abstractions for single-use code.
- No "flexibility" or "configurability" that wasn't requested.
- No error handling for impossible scenarios.
- If you write 200 lines and it could be 50, rewrite it.

Ask yourself: "Would a senior engineer say this is overcomplicated?" If yes, simplify.

## 3. Surgical Changes

**Touch only what you must. Clean up only your own mess.**

When editing existing code:
- Don't "improve" adjacent code, comments, or formatting.
- Don't refactor things that aren't broken.
- Match existing style, even if you'd do it differently.
- If you notice unrelated dead code, mention it - don't delete it.

When your changes create orphans:
- Remove imports/variables/functions that YOUR changes made unused.
- Don't remove pre-existing dead code unless asked.

The test: Every changed line should trace directly to the user's request.

## 4. Goal-Driven Execution

**Define success criteria. Loop until verified.**

Transform tasks into verifiable goals:
- "Add validation" → "Write tests for invalid inputs, then make them pass"
- "Fix the bug" → "Write a test that reproduces it, then make it pass"
- "Refactor X" → "Ensure tests pass before and after"

For multi-step tasks, state a brief plan:
```
1. [Step] → verify: [check]
2. [Step] → verify: [check]
3. [Step] → verify: [check]
```

Strong success criteria let you loop independently. Weak criteria ("make it work") require constant clarification.

---

**These guidelines are working if:** fewer unnecessary changes in diffs, fewer rewrites due to overcomplication, and clarifying questions come before implementation rather than after mistakes.
