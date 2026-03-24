---
name: pre-deploy
description: Pre-deployment checklist - verify server, git, and endpoint health before deploying
user_invocable: true
---

Run a pre-deployment checklist before the user deploys changes. Do ALL of the following:

1. **Git status**: Run `git status` and `git diff --stat` to show what's changed. Flag any uncommitted changes.

2. **Server check**: Run `systemctl status vulntracker` to verify the FastAPI server is running.

3. **Modified endpoint smoke test**: For each Python file in `app/api/endpoints/` that has been modified (from git status), do a syntax check: `python3 -c "import ast; ast.parse(open('FILE').read()); print('OK: FILE')"`. This catches syntax errors without importing (which would need the full app context).

4. **Migration check**: Run `cd /home/manan/vuln-tracker && venv/bin/alembic current` and `venv/bin/alembic heads` to verify migration state is clean (current == head).

5. **Protected file check**: Verify none of the following were modified (from git diff):
   - `app/services/notification_manager.py`
   - `app/services/firebase_scheduler.py`
   - `app/main.py`
   - Any stable pipeline files listed in CLAUDE.md
   If any were modified, flag with a WARNING.

6. **Summary**: Present a go/no-go recommendation based on findings.
