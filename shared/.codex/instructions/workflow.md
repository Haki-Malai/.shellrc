# Editing and Validation

Read before editing code or documentation. Read-only explanations do not require an editing plan or Git preflight.

## Before editing

- Inspect the relevant implementation, callers, tests, and applicable instructions. Use the Git preflight in [Git and remote work](git-and-remote.md) before edits.
- State the intended change, expected files, and verification. One sentence is enough for a small edit; use 3–6 steps for work with multiple dependencies or meaningful risk. A plan is not a request for permission to do already-authorized work.
- For UI/layout work, distinguish presentation changes from changes to saving, rerunning, validation, persistence, or other product behavior. Preserve the existing behavior unless the user requests a change; surface a necessary behavior change before implementing it.
- When a design needs new persisted state, configuration, compatibility logic, or a helper script, first check the existing owner and explain why it cannot satisfy the requirement. Prefer direct commands for one-off work; add a maintained script only for a recurring workflow that benefits from it.
- Ask a focused question only when unresolved information affects the result or authorization. Continue independent investigation while waiting; do not treat an unanswered question as agreement.

## During editing

- Keep changes within scope; match existing style and preserve comments/docstrings unless the change requires updating them.
- Remove imports, variables, and functions made unused by this change. Mention unrelated dead code without deleting it.
- Document new or changed non-JSX JavaScript/TypeScript functions with `/** ... */` JSDoc: a useful description and applicable `@param` and `@returns` tags. Use the language's native documentation format elsewhere; do not add unrelated comment churn.
- Keep one-off tools, logs, and audit artifacts in task-owned temporary storage or the repository's documented scratch location. Do not add permanent task directories to the repository without a recurring purpose.
- When isolation needs a worktree, prefer an established dedicated worktree location over a new sibling checkout in the workspace root. Preserve existing worktrees and other agents' work.

## Validation and handoff

- Run the relevant local checks and required repository checks. Test changed behavior; avoid tests that only restate the implementation or unrelated suites without a reason.
- After a failure, inspect the actual failing boundary and environment before adding more code. Distinguish local test success from deployed behavior and an end-to-end result.
- Broaden or repeat checks when dependencies, new changes, or unresolved failures justify it. Ask before unexpectedly heavy or costly checks; reuse prior authorization for checks already in scope.
- Run a targeted diff for touched files and check for accidental edits. Summarize what changed, why, what passed, and any remaining verification gap using [Reporting](reporting.md).
