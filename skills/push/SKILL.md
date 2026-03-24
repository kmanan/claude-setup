---
name: push
description: Stage, commit, and push current changes to remote
user_invocable: true
---

Push current changes to the remote repository. Follow these steps:

1. Run `git status` to see what's changed
2. Run `git diff --stat` to summarize changes
3. If there are unstaged/untracked changes, stage them with `git add` (specific files, not `-A`)
4. If there are staged changes that need committing, draft a concise commit message based on the diff and create the commit
5. Push to the current branch's remote: `git push`
6. If the branch has no upstream, use `git push -u origin <branch-name>`
7. Report what was pushed

If there's nothing to push (working tree clean, branch up to date), just say so.
Do NOT force push. If push is rejected, report the error and ask the user how to proceed.
