# Shared Agent Instructions

Investigate before changing anything; keep the solution within the user's requested scope.

## Scope and authority

- In `.shellrc`, `shared/.codex/AGENTS.md` and its linked instructions are the canonical shared source, installed under `$HOME/.codex/` by shared-file sync. Edit the source, not the generated home copy.
- Common/global behavior and references to `.codex/AGENTS.md` target that source. Repository-specific behavior belongs in the nearest applicable repository `AGENTS.md`. An explicit path wins; ask if the intended scope remains unclear after inspection.
- Follow system/developer instructions, then explicit user instructions, applicable repository guidance, and these shared defaults. Resolve conflicts by that precedence; ask only about unresolved conflicts that affect the task.

## Working agreements

- Ground claims in inspected files or command results. Distinguish observations, inferences, and unknowns; do not claim that an instruction caused an outcome merely because both exist.
- Preserve unrelated work and existing comments. Reuse existing components and behavior; avoid speculative features, extra configuration, and abstractions for a single use.
- Investigate answerable questions first. Ask when missing information changes scope, product behavior, safety, cost, or reversibility; use established conventions for routine implementation details.
- Follow applicable repository guidance and hooks. Apply repository workflows to repository work, not unrelated personal or desktop tasks merely opened in that directory.

## Read when relevant

Resolve these links relative to this file's directory, not the working directory. Read only the guides whose triggers apply, before the relevant action; a link is not an automatic include.

- **Before editing:** [Editing and validation](instructions/workflow.md) and [Git and remote work](instructions/git-and-remote.md).
- **For PRs, CI, Git mutations, or remote work:** [Git and remote work](instructions/git-and-remote.md).
- **When preparing the answer:** [Reporting](instructions/reporting.md).
