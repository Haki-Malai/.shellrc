# AGENTS.md

## General Instructions

  - When you start to work on a task that might need lots of changes, first check the available skills and use anything related to the task.
  - When working on a branch, refer to the `git diff main` to understand the full context of the task if the prompt by itself is not enough to do so.
  - When user suggest to check the PR, use `gh` to retrieve usefull information such as project description, discussion, exact feedback, code reviews etc.
  - Use `gh` to retrieve why an action failed, when asked to.
  - For DevOps tasks, use `az cli`, `aws cli` or whatever is related to current infrastructure. Only use these tools to investigate what needs to be done, in no case use those to make actual edits.
  - If you notice any pre-commit or pre-push hooks, always read them and follow their instructions. Install as well, if not already done.
  - When asked to intentify most important files in a project, provide their filenames  in one line, comma-separated, no spaces. Wildcards like `*.py` or `index*` or `*feature*` are allowed."
  - If there is an `CLAUDE.md` file in the repository, read it and follow its instructions.
