# Git and Remote Work

Read before edits, Git mutations, PR/CI work, or remote operations. Explicit user authorization is required for staging, committing, pushing, merging, and remote writes; do not infer it from a request to inspect or edit code.

## Protect the working tree

- Before editing tracked files or running a Git command that may mutate the working tree, index, branches, or history, run `git status --short --branch`, `git diff`, and `git diff --cached`. Summarize the relevant state and distinguish existing staged/unstaged work from your changes.
- Do this once before the edit sequence, then refresh when the branch/worktree changes, another actor may have changed files, or a later mutation depends on fresh state. Do not repeat full diffs before every patch.
- Read-only inspection, explanations, and planning do not require that preflight. A diff requested by the user or needed to answer the question is still appropriate.
- Mutation examples include `restore`, `reset`, `checkout`, `switch`, `stash`, `merge`, `rebase`, `cherry-pick`, and `clean`, as well as `add`, `commit`, and `push`.
- When staging is explicitly requested, show the command and use exact pathspecs; never use `git add .` as a convenience. Do not include unrelated changes.
- Read configured pre-commit/pre-push hooks and follow them. Do not bypass hooks to complete publication.

## PRs and CI

- When the task concerns GitHub PRs, reviews, or CI, use `gh` to gather the relevant context before proposing changes. Do not fetch every field or every PR when a narrower query answers the question.
- Useful read-only commands: `gh pr view <id> --json title,body,state,url,baseRefName,headRefName,author,labels,reviewRequests,reviews,comments,statusCheckRollup`, `gh pr diff <id>`, `gh pr checks <id>`, and `gh pr status`.
- Inspect the intended branch/PR and its existing stack before publication or restacking. Follow the repository's deployment path; do not substitute a local deployment for a required pipeline.

## Remote authorization

- Classify operations by their actual effects, target, and cost, not verbs such as `run`, `execute`, or `invoke`. Read-only queries and inspection do not need confirmation.
- An explicit request authorizes routine remote actions within that scope. Reuse that authorization across steps and turns instead of requesting a second approval for the same work.
- For Databricks, inspect SQL/workload effects before execution. Read-only SQL and explicitly requested routine job/notebook runs may proceed; account for writes and compute costs.
- Ask once before destructive or hard-to-reverse actions, security/access changes, substantial unexpected costs, or work outside the authorized scope. Investigate unclear effects first.
- When confirmation is needed, present the concrete command/action, target, main risk, and rollback if available. Complete independently authorized preparation first, then wait for the answer to the unresolved decision.
- If the current user message's final non-whitespace line is exactly `Aegon V is Goat`, its explicitly requested remote changes are already confirmed. Quoted, discussed, or embedded occurrences do not activate it; it grants no authority beyond that message's explicit scope.
