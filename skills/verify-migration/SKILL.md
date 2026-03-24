---
name: verify-migration
description: Audit an Alembic migration file for destructive operations before applying
user_invocable: true
---

Audit the most recent Alembic migration for safety. Follow these steps:

1. Find the latest migration file: `ls -t /home/manan/vuln-tracker/alembic/versions/*.py | head -1`

2. Read the entire migration file.

3. Check for these DANGEROUS operations and flag each one with a warning:
   - `DROP INDEX` — Will these indexes be needed? Were they created intentionally?
   - `DROP COLUMN` — Is data being lost? Was this column added by a migration not reflected in the ORM?
   - `DROP CONSTRAINT` — Will this break data integrity?
   - `DROP TABLE` — Is this table still in use?
   - `ALTER COLUMN ... TYPE` — Will this cause data loss or casting errors?
   - `ALTER COLUMN ... DROP NOT NULL` / `SET NOT NULL` — Could this break existing queries?

4. Check for ORM drift artifacts — operations that Alembic autogenerate adds because the ORM model doesn't match the live DB:
   - Any operation on `mobile_devices` columns not in the ORM (persona, primary_industry, ransomware_sectors)
   - Index operations on tables you didn't intend to change
   - Constraint changes on unrelated tables

5. Present:
   - **SAFE operations** — The changes that look intentional
   - **DANGEROUS operations** — Things that should probably be deleted from the migration
   - **Recommendation** — Whether to apply as-is, trim, or rewrite

If the user provides a specific migration filename as an argument, audit that file instead of the latest.
