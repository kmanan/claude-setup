---
description: Review current changes for bugs, security issues, and convention violations before committing
---

## Current Branch

!`git branch --show-current`

## Files Changed

!`git diff --name-only`

## Staged Changes

!`git diff --cached --stat`

## Full Diff

!`git diff`

!`git diff --cached`

Review the above changes for:

1. **Bugs** — None handling, truthiness checks, race conditions, type mismatches
2. **Security** — SQL injection, input validation, credential exposure, unguarded external data
3. **Convention violations** — Does the code match patterns in nearby files? Wrong import style? Wrong pagination pattern?
4. **Protected files** — Were notification_manager.py, firebase_scheduler.py, main.py, or stable pipeline files modified?
5. **Database safety** — Any INSERT/UPDATE/DELETE without explicit approval?

Give specific, actionable feedback per file. If everything looks clean, say so.
