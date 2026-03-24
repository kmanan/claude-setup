---
globs: alembic/**, app/models/**, app/db/**, scripts/*migration*, scripts/*backfill*
description: Database schema, migration safety, and ORM conventions
---

# Database Rules

## Critical Safety Rules
- NEVER use Alembic autogenerate without manual review — it WILL generate DROP INDEX/COLUMN/CONSTRAINT for intentional drift
- NEVER write to the database without explicit user approval (INSERT/UPDATE/DELETE/DROP)
- Read-only SELECT queries are always fine
- Always use Alembic migrations for schema changes — never raw DDL in production

## Two Database Sessions (GOTCHA)
- `app/core/database.py` — Main session: pool_size=5, max_overflow=10, echo=True
- `app/db/session.py` — Secondary session: pool_size=10, max_overflow=20
- Both export `SessionLocal`. Most code uses `app.core.database.get_db()` via FastAPI Depends.

## ORM Model Drift — mobile_devices
- `MobileDevice` model does NOT declare: `persona`, `primary_industry`, `ransomware_sectors`, and other columns added via later migrations
- These columns exist in live DB but not in ORM — code touching them must use raw SQL (`text()`)
- Do NOT add them to ORM without reviewing Alembic autogenerate output — it will try to drop other columns/indexes

## Schema (PostgreSQL: `cisa_kev`)

| Table | PK Type | Key Columns | Notable Features |
|-------|---------|-------------|-----------------|
| `vulnerabilities` | UUID | cve_id, vendor_project, product, product_resolved, 6 JSONB analysis fields | search_vector (tsvector), custom types |
| `ti_feed_sources` | Serial | name, url, category, feed_type, polling_interval | is_active flag |
| `ti_feed_entries` | Serial | feed_source_id (FK), title, link, guid, processed | Raw feed data |
| `ti_normalized_entries` | Serial | feed_entry_id (FK), summary, analysis_json (JSONB), threat_actors[], malware_types[], iocs[], vulnerabilities[], vendor, product | search_vector, confidence_score |
| `breach_feed_sources` | Serial | name, url, category, feed_type | Same structure as ti_feed_sources |
| `breach_feed_entries` | Serial | feed_source_id (FK), title, link, guid, processed | Indexed on processed, published_at |
| `breach_normalized_entries` | Serial | feed_entry_id (FK), company_name, affected_accounts, severity_level, data_types[] | search_vector, indexed on company+severity |
| `threat_actor_mappings` | Serial | identity_id (FK), actor_name, cve_id, product, confidence_score, attack_types[] | Unique on (actor_name, cve_id), search_vector, identity_id NOT NULL |
| `threat_actor_identities` | Serial | canonical_name (unique), country, country_code, activity_group, description, known_tools[], target_industries[], actor_metadata (JSONB), source, confidence | Canonical identity store |
| `threat_actor_aliases` | Serial | identity_id (FK), alias, alias_lower (generated, UNIQUE), naming_authority | One alias per identity |
| `threat_actor_references` | Serial | primary_name (unique), aliases[], country, country_code | **LEGACY** — no longer queried |
| `vendor_catalog` | Serial | display_name, vendor_project (unique), kev_count, actor_count | Logo URL, enrichment stats |
| `watchlist_items` | Serial | device_uuid, vendor_id (FK), product_filter[] | Per-device vendor tracking |
| `hub_notifications_log` | Serial | device_uuid, notification_type, entity_id | Push dedup log |
| `news_articles` | Serial | title, url, source, vendor_tags[], published_at | AI-tagged vendor associations |
| `briefings` | Serial | device_uuid, watchlist_hash, content (TEXT), generated_at | Weekly AI briefings |
| `ransomware` | Serial | victim_name, group_name, published_at, description | ransomware.live incidents |
| `mobile_devices` | Serial | token (unique), platform, fcm_token, device_uuid, notification_pref, subscription_tier, free_briefing_used, briefing_enabled | Many columns NOT in ORM |
| `service_status` | String PK | service_name, status, last_run, last_error | CHECK constraints on valid names/statuses |

### PostgreSQL-Specific Features
- Custom types: `safe_text`, `vulnerability_status`
- Full-text search: `search_vector` (TSVECTOR) columns with GIN indexes on 4 tables, populated by DB triggers
- Trigram search: `pg_trgm` extension, similarity threshold 0.15
- JSONB, ARRAY, UUID extensions in use

## Known Bug Patterns
- Any field from DeepSeek AI analysis can be None — always guard before `.lower()`, `.strip()`, etc.
- Use `is not None` instead of truthiness checks for optional fields (`if x` fails on `[]`, `""`, `0`)
- `ti_normalized_entries.feed_entry_id` has no UNIQUE constraint — race conditions possible between manual submission and pipeline
- `::jsonb` and `::text` PostgreSQL casts conflict with SQLAlchemy `:param` syntax — use `CAST(:param AS jsonb)` instead
