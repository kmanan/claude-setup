# 🤖 Claude Code Setup — How I Run 20+ Projects With Zero Friction

My battle-tested Claude Code configuration for managing a portfolio of production apps from a single VPS. Built up over months of real-world usage running [Kryton Labs](https://krytonlabs.com) — a cybersecurity platform, mobile apps, landing pages, and internal tools.

**The problem:** Claude Code asks permission for *everything*. Every `ls`, every file edit, every `git push`. When you're shipping across 20 projects, that's hundreds of interruptions per day.

**The solution:** A layered permission system with smart guardrails that lets Claude Code run autonomously while still blocking the stuff that actually matters.

---

## 🏗️ Architecture

```
~/.claude/settings.json          ← 🌍 Global: applies to ALL projects
project/.claude/settings.local.json  ← 📁 Project: overrides for this repo only
project/.claude/rules/*.md       ← 📏 Context rules: auto-load when touching related files
project/.claude/hooks/*.sh       ← 🛡️ Guardrails: deterministic blocks on dangerous ops
project/.claude/skills/*/SKILL.md    ← ⚡ Slash commands: /deploy, /push, /pipeline-status
```

### How It Layers

1. **Global settings** say "allow all bash, all edits, all web access"
2. **Project deny rules** say "except notification_manager.py and .env files"
3. **Hooks** enforce the hard rules — even if Claude tries, the hook blocks it
4. **Skills** give you one-word commands for complex workflows

The result: **zero permission prompts** for routine work, **hard blocks** on dangerous operations.

---

## 📂 What's In This Repo

```
global/
  settings.json          # Global permissions — copy to ~/.claude/settings.json
  sudoers-example.txt    # Passwordless sudo for systemctl/journalctl

hooks/
  check-bash.sh          # Blocks Alembic autogenerate, destructive SQL
  protect-files.sh       # Blocks edits to protected/stable files

rules/
  database.md            # Schema, migration safety, ORM gotchas (auto-loads for alembic/**)
  pipelines.md           # Pipeline flows, systemd schedules (auto-loads for scripts/**)
  api-routes.md          # Route map, pagination patterns (auto-loads for endpoints/**)

skills/
  deploy/                # 🚀 /deploy — build + restart PM2 in one command
  push/                  # 📤 /push — stage, commit, push in one command
  pipeline-status/       # 📊 /pipeline-status — health check all systemd services
  verify-migration/      # 🔍 /verify-migration — audit Alembic migrations for danger
  pre-deploy/            # ✅ /pre-deploy — pre-deployment safety checklist
  cyberprism-app-marketing/  # 📱 15 ASO & app marketing skills

sync.sh                  # Backup script — syncs config to this repo
```

---

## ⚡ Quick Start

### 1. Global Permissions (stop the permission prompts)

Copy `global/settings.json` to `~/.claude/settings.json`:

```bash
cp global/settings.json ~/.claude/settings.json
```

This allows all common operations without prompting:

| Category | What's Allowed |
|----------|---------------|
| 🐚 Shell | `git`, `ls`, `find`, `grep`, `cat`, `tail`, `mkdir`, `cp`, `mv`, ... |
| 🐍 Python | `python3`, `pip`, `PYTHONPATH=*`, `venv/bin/*` |
| 📦 Node | `node`, `npm`, `npx`, `yarn`, `pnpm`, `pm2` |
| 🗄️ Database | `psql`, `sqlite3` |
| 🌐 Web | `curl`, `wget`, `WebSearch`, `WebFetch(*)` |
| 🔧 System | `systemctl`, `journalctl`, `sudo systemctl`, `sudo journalctl` |
| 📝 Files | `Read(*)`, `Edit(*)`, `Write(*)` |

**What's blocked:**

| Blocked | Why |
|---------|-----|
| `rm -rf *` | ☠️ Obviously |
| `git push --force *` | 💀 Can destroy remote history |
| `git reset --hard *` | 💀 Can destroy local work |
| `Edit(*.env)` | 🔐 Don't touch secrets |
| `Edit(*/credentials/*)` | 🔐 Don't touch secrets |

### 2. Passwordless Sudo (stop the password prompts)

```bash
sudo visudo -f /etc/sudoers.d/claude-code
```

Paste this as **one line**:

```
YOUR_USERNAME ALL=(ALL) NOPASSWD: /usr/bin/systemctl, /usr/bin/journalctl, /usr/bin/tail, /usr/bin/cat, /usr/bin/ls
```

Now Claude can `sudo systemctl restart myapp` without a password — but can't `sudo rm` or `sudo bash`.

### 3. Add Project Hooks (optional, per-project guardrails)

Copy the hooks to any project that needs them:

```bash
mkdir -p your-project/.claude/hooks
cp hooks/check-bash.sh your-project/.claude/hooks/
cp hooks/protect-files.sh your-project/.claude/hooks/
chmod +x your-project/.claude/hooks/*.sh
```

Register them in `your-project/.claude/settings.local.json`:

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [{ "type": "command", "command": "/path/to/hooks/check-bash.sh" }]
      },
      {
        "matcher": "Edit|Write",
        "hooks": [{ "type": "command", "command": "/path/to/hooks/protect-files.sh" }]
      }
    ]
  }
}
```

### 4. Add Skills (one-word commands)

Copy any skill folder to `.claude/skills/` in your project:

```bash
mkdir -p your-project/.claude/skills
cp -r skills/deploy your-project/.claude/skills/
```

Then just type `/deploy` in Claude Code. That's it.

---

## 🚀 Skills Reference

### `/deploy` — Build & Ship

```
> /deploy
```

Runs `npm install` → `npm run build` → `pm2 restart` → verifies it's online → shows logs. Customize the SKILL.md with your project's build command and process name.

### `/push` — Stage, Commit, Push

```
> /push
```

Checks `git status`, stages changes, writes a commit message from the diff, pushes to remote. Won't force push.

### `/pipeline-status` — Health Dashboard

```
> /pipeline-status
```

Checks all systemd timers, flags failed or stale services, reads checkpoint files, queries service status table. Great for monitoring a fleet of background jobs.

### `/verify-migration` — Migration Safety Audit

```
> /verify-migration
```

Reads the latest Alembic migration and flags destructive operations (DROP INDEX, DROP COLUMN, etc.) before you apply it. Catches the stuff `autogenerate` sneaks in.

### `/pre-deploy` — Pre-Deployment Checklist

```
> /pre-deploy
```

Checks git status, server health, syntax errors in modified files, migration state, and whether any protected files were accidentally modified.

---

## 🛡️ Hooks: How They Work

Hooks run **before** Claude executes a tool. They receive the tool input as JSON on stdin and exit with a code:

| Exit Code | Meaning |
|-----------|---------|
| `0` | ✅ Allow |
| `2` | 🚫 Block (with message) |

### `check-bash.sh`

Blocks two things:
- **`alembic revision --autogenerate`** — This generates destructive migrations if your ORM models drift from the live DB. Run it yourself and review the output manually.
- **Destructive SQL** — `DROP TABLE`, `TRUNCATE`, `DELETE FROM` in bash commands.

### `protect-files.sh`

Blocks edits to files you mark as stable:
- Notification system files (tested, do not touch)
- Pipeline files (stable data ingestion)
- App entrypoint (router registration)
- Credential files

**Customize it:** Edit the `case` statements in `protect-files.sh` to protect whatever files matter in your project.

---

## 📏 Path-Scoped Rules

Rules in `.claude/rules/` auto-load based on which files you're working on:

```markdown
---
globs: alembic/**, app/models/**
description: Database schema and migration safety
---

# Database Rules
- NEVER apply autogenerated migrations without manual review
- ...
```

When Claude touches `alembic/versions/v21_new_column.py`, it automatically sees the database rules. When it's editing an API endpoint, it sees the API route map. No manual context-loading needed.

---

## 📱 Bonus: App Store Marketing Skills

15 skills for mobile app marketing and ASO (App Store Optimization), used for [CyberPrism](https://cyberprism.app):

| Skill | What It Does |
|-------|-------------|
| `/aso-audit` | Full App Store Optimization health audit |
| `/keyword-research` | Keyword opportunity analysis |
| `/metadata-optimization` | Write optimized titles, subtitles, descriptions |
| `/competitor-analysis` | Analyze competitor listings and strategies |
| `/screenshot-optimization` | Screenshot and preview video recommendations |
| `/ab-test-store-listing` | Design A/B tests for store listings |
| `/app-analytics` | Interpret analytics data and trends |
| `/app-launch` | Launch strategy and timeline planning |
| `/app-store-featured` | Get featured on the App Store |
| `/localization` | Localization strategy for target markets |
| `/monetization-strategy` | Pricing and monetization optimization |
| `/retention-optimization` | User retention and engagement tactics |
| `/review-management` | Review response and rating improvement |
| `/ua-campaign` | User acquisition campaign planning |
| `/app-marketing-context` | Load full marketing context for other skills |

---

## 🔄 Backup Script

`sync.sh` copies your Claude config (global settings, project skills/hooks/rules, memory files) into a backup repo:

```bash
# Manual sync
./sync.sh

# Sync and push to GitHub
./sync.sh --push
```

Run it periodically or after making config changes. If your machine dies, clone the backup and restore.

---

## 💡 Tips From Production Usage

**🎯 The #1 rule for CLAUDE.md:** Put behavioral rules there, not just documentation. "Before suggesting a library, search the codebase first" is more useful than a list of what libraries you use.

**🪝 Hooks > CLAUDE.md warnings:** If a rule matters enough to write "NEVER do X", enforce it with a hook. CLAUDE.md rules are suggestions. Hooks are walls.

**📏 Path-scoped rules > one giant CLAUDE.md:** A 400-line CLAUDE.md means Claude loads database schema docs when editing CSS. Split it into scoped rules that load only when relevant.

**🔑 Permission wildcards:** `Bash(git *)` beats 20 individual `Bash(git add *)`, `Bash(git commit *)`, `Bash(git log *)` rules. Start broad, deny the dangerous stuff.

**⚡ Skills for repeated workflows:** If you've typed the same 3-step process more than twice, make it a skill. `/deploy` saves more time than you think.

**🧠 Memory ≠ documentation:** Claude's memory files should store *decisions and lessons*, not code structure. "We use aiohttp, not requests" is a good memory. "Here's our directory tree" is not — Claude can just look.

---

## 🏢 About

Built by [Manan](https://github.com/kmanan) at [Kryton Labs LLC](https://krytonlabs.com) while managing:
- 🛡️ [CyberPrism](https://cyberprism.app) — Cybersecurity threat intelligence platform (FastAPI + PostgreSQL + 13 systemd pipelines)
- 🎮 [ArtFall](https://artfall.app) — Mobile puzzle game
- 🌐 Multiple Node.js sites running on PM2
- ...and about 15 other projects, all from one VPS

## 📄 License

MIT — use it however you want.
