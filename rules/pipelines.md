---
globs: scripts/**, systemd/**, app/services/**, checkpoints/**
description: Pipeline architecture, systemd schedules, and protected files
---

# Pipeline Rules

## Protected Files — Do NOT Modify Without Permission
- `app/services/feed_fetcher.py` — CISA KEV feed ingestion
- `app/services/deepseek_processor.py` — AI analysis for CVEs
- `app/services/data_sanitizer.py` — HTML/SQL sanitization
- `app/services/trends_processor.py` — Vulnerability trend aggregation
- `app/services/threat_intel/ti_collector.py` — Threat intel feed fetcher
- `app/services/threat_intel/ti_processor.py` — AI-powered TI processing
- `app/services/threat_intel/threat_intel_pipeline.py` — TI orchestrator
- `app/services/notification_manager.py` — DO NOT EDIT (email + push)
- `app/services/firebase_scheduler.py` — DO NOT EDIT (token cleanup)
- `app/main.py` — Router registration (ask before modifying)

## Pipeline Flows

**Vulnerability** (hourly): CISA KEV → FeedFetcher → DB upsert → DeepSeekProcessor (5/batch, 1s rate limit) → 6 JSONB fields → Push
**Product Resolver** (hourly :10): "Multiple Products" → NVD CPE API → product_resolved column
**Breach** (hourly): RSS → BreachCollector → breach_feed_entries → BreachProcessor/BreachDeepSeekProcessor → breach_normalized_entries → Push
**Ransomware** (every 2h): ransomware.live API → RansomwareCollector → ransomware table → Push
**Threat Intel** (~47min): RSS → TICollector → ti_feed_entries → TIProcessor (DeepSeek) → ti_normalized_entries → Push
**Threat Actor Update** (every 6h): Resolve actors from ti_normalized_entries via aliases → Create identity_id-based mappings
**MITRE Sync** (weekly Sun 05:00 UTC): MITRE ATT&CK STIX → Update identities + aliases
**Threat Actor Enrichment** (daily 05:30 UTC): Malpedia API → DeepSeek fallback → 20 actors/run
**News** (3x daily): RSS → NewsCollector → NewsProcessor (DeepSeek vendor tagging) → news_articles
**Watchlist Notifier** (hourly :15): Match watchlist vs new KEVs/TI/breaches → Push
**Weekly Briefing** (Monday 06:00 UTC): Assemble 7-day payload → GPT-4o → briefings table → Push Pro users
**Logo Scan** (twice daily 19:00/02:00 UTC): Fetch vendor/company logos → warm Redis cache

## Systemd Schedule

### Hourly Execution Order
```
:00  vuln-pipeline, breach-pipeline, threat-intel-pipeline
:10  product-resolver
:15  watchlist-notifier
```

### Scheduled
| Service | Schedule | Script |
|---------|----------|--------|
| database-backup | Daily 03:00 UTC | backup_database.py |
| vendor-stats-refresh | Daily 03:30 UTC | refresh_vendor_stats.py |
| threat-actor-enrich | Daily 05:30 UTC | enrich_threat_actors.py |
| news-pipeline | 04:00, 12:00, 20:00 UTC | run_news_pipeline.py |
| logo-scan | 19:00 and 02:00 UTC | fetch_logos.py --seed --scan |
| daily-digest | 20:00 UTC (1 PM PT) | run_daily_digest.py |
| mitre-sync | Sunday 05:00 UTC | sync_mitre_threat_actors.py |
| briefing-generator | Monday 06:00 UTC | run_briefing_generator.py |

### Key Facts
- `daily-digest` timer fires at 20:00 UTC / 1 PM PT
- Logo scan runs 1h before daily digest (19:00 UTC) and at 7 PM PT (02:00 UTC)
- `PYTHONPATH=/home/manan/vuln-tracker` required for all scripts
- Checkpoint files in `checkpoints/` track last run timestamps
