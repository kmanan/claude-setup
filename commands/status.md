---
description: Quick overview of git status, server health, and recent pipeline runs
---

## Git Status

!`git status --short`

## Server

!`systemctl status vulntracker --no-pager -l 2>&1 | head -5`

## Pipeline Timers (last fired)

!`systemctl list-timers --all 2>/dev/null | grep -E 'vuln|breach|ransom|threat|news|watchlist|product|logo|digest|briefing|mitre|enrich|vendor|backup'`

## Failed Services

!`systemctl is-failed vuln-pipeline breach-pipeline ransomware-pipeline threat-intel-pipeline news-pipeline watchlist-notifier product-resolver threat-actor-update mitre-sync threat-actor-enrich vendor-stats-refresh database-backup briefing-generator logo-scan 2>/dev/null | grep -v active || echo "All services OK"`

Summarize: what's the current state of the project? Any uncommitted work? Any failed or stale pipelines? Keep it brief.
