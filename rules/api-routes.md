---
globs: app/api/endpoints/**
description: API route map, pagination patterns, and endpoint conventions
---

# API Routes

## Route Map

| Prefix | Description | Response |
|--------|-------------|----------|
| `/vulnerabilities/table` | Full vulnerability data (clears Redis) | JSON |
| `/vulnerabilities/view` | Paginated HTML table | HTML |
| `/vulnerabilities/update` | Update vuln status | JSON |
| `/vulnerabilities/trends` | 6-week rolling trends | JSON |
| `/api/mobile/latest` | Latest vulns (limit 1-20) | JSON |
| `/api/mobile/page` | Cursor+offset pagination | JSON |
| `/api/mobile/analysis/{cve_id}` | Full CVE analysis | JSON |
| `/api/mobile/threat-intel` | Paginated TI entries | JSON |
| `/api/mobile/threat-intel/{id}` | TI detail with IOCs | JSON |
| `/api/mobile/register-device` | Register push token | JSON |
| `/api/mobile/search` | Unified cross-entity search | JSON |
| `/api/mobile/breach-bot` | DeepSeek proxy for breach bot | JSON |
| `/api/threat-actor-metrics` | Actor analytics | JSON |
| `/threat-intel/view` | TI dashboard | HTML |
| `/threat-intel/manual` | Manual TI URL form | HTML |
| `/threat-actor-map/view` | Actor map page | HTML |
| `/threat-actor-map/api/actors` | Actor data API | JSON |
| `/breach-notifications/view` | Breach dashboard | HTML |
| `/breach-notifications/latest` | Latest breaches | JSON |
| `/breach-notifications/page` | Cursor pagination | JSON |
| `/breach-notifications/{id}` | Breach detail | JSON |
| `/breach-notifications/stats/overview` | Breach statistics | JSON |
| `/breach-notifications/manual` | Manual breach URL form | HTML |
| `/api/device/register` | Hub device registration (UUID) | JSON |
| `/api/device/preferences` | Update device preferences | JSON |
| `/api/onboarding/config` | Vendor catalog + onboarding grid | JSON |
| `/api/watchlist/sync` | Sync device watchlist | JSON |
| `/api/hub/feed` | Personalized Hub feed | JSON |
| `/api/hub/stats` | Hub dashboard stats | JSON |
| `/api/briefing/latest` | Latest briefing for device | JSON |
| `/api/briefing/generate` | On-demand briefing (POST) | JSON |
| `/api/briefing/preference` | Toggle briefing pref (PATCH) | JSON |
| `/api/ransomware/latest` | Latest ransomware incidents | JSON |
| `/api/ransomware/stats` | Ransomware statistics | JSON |
| `/status/status` | System status dashboard | HTML |
| `/status/feed-tracker` | Feed source tracker | HTML |

**No authentication on any endpoint.**

## Conventions
- Pagination: cursor-based (before_date) + offset. The `limit+1` trick determines `has_more`.
- Session management: endpoints use `db: Session = Depends(get_db)`
- Prefer `product_resolved` over `product` when displaying product names (falls back to `product` if NULL)
- Manual submission endpoints must set `processed=True` immediately to avoid pipeline race conditions
