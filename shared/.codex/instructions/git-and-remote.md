# Git and Remote Work

Read before edits, Git mutations, PR/CI work, or remote operations.

## Protect the working tree

- Before editing tracked files or running a Git command that may mutate the working tree, index, branches, or history, run `git status --short --branch`, `git diff`, and `git diff --cached`. Summarize the relevant state and distinguish existing staged/unstaged work from your changes.
- Do this once before the edit sequence, then refresh when the branch/worktree changes, another actor may have changed files, or a later mutation depends on fresh state. Do not repeat full diffs before every patch.
- Read-only inspection, explanations, and planning do not require that preflight. A diff requested by the user or needed to answer the question is still appropriate.
- Mutation examples include `restore`, `reset`, `checkout`, `switch`, `stash`, `merge`, `rebase`, `cherry-pick`, and `clean`, as well as `add`, `commit`, and `push`.
- When staging changes, show the command and use exact pathspecs; never use `git add .` as a convenience. Do not include unrelated changes.
- Read configured pre-commit/pre-push hooks and follow them. Do not bypass hooks to complete publication.

## PRs and CI

- When the task concerns GitHub PRs, reviews, or CI, use `gh` to gather the relevant context before proposing changes. Do not fetch every field or every PR when a narrower query answers the question.
- Useful read-only commands: `gh pr view <id> --json title,body,state,url,baseRefName,headRefName,author,labels,reviewRequests,reviews,comments,statusCheckRollup`, `gh pr diff <id>`, `gh pr checks <id>`, and `gh pr status`.
- Inspect the intended branch/PR and its existing stack before publication or restacking. Follow the repository's deployment path; do not substitute a local deployment for a required pipeline.

## Remote operations

- Classify operations by their actual effects, target, and cost, not verbs such as `run`, `execute`, or `invoke`.
- For Databricks, inspect SQL, jobs, and notebooks for writes and compute costs before execution.
