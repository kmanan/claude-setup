---
name: pipeline-status
description: Check health of all CyberPrism systemd pipelines and report issues
user_invocable: true
---

Check the health of all CyberPrism pipelines and report a summary. Do ALL of the following:

1. Run `systemctl list-timers --all 2>/dev/null | grep -E 'vuln|breach|ransom|threat|news|watchlist|product|logo|digest|briefing|mitre|enrich|vendor|backup'` to see all timer schedules and when they last fired.

2. Run `systemctl is-failed vuln-pipeline breach-pipeline ransomware-pipeline threat-intel-pipeline news-pipeline watchlist-notifier product-resolver threat-actor-update mitre-sync threat-actor-enrich vendor-stats-refresh database-backup briefing-generator logo-scan daily-digest 2>/dev/null` to check for failed services.

3. For any services that show as failed, run `journalctl -u <service-name>.service --since "1 hour ago" --no-pager -n 30` to get error details.

4. Check checkpoint files: `ls -la /home/manan/vuln-tracker/checkpoints/` and `cat` each one to see last run timestamps.

5. Check the service_status table: `PGPASSWORD=$DB_PASSWORD psql -h localhost -U postgres -d cisa_kev -c "SELECT service_name, status, last_run, last_error FROM service_status ORDER BY last_run DESC NULLS LAST"`

Present a summary table showing:
- Service name
- Status (OK / FAILED / STALE)
- Last run time
- Any errors

Flag any service that hasn't run in longer than its expected interval as STALE.
