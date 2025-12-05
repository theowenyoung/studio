# PostgreSQL Disaster Recovery Guide

This guide covers the complete disaster recovery workflow for PostgreSQL databases.

## Overview

Our backup system uses `pg_dumpall --no-role-passwords` which:
- ✅ Backs up all databases, tables, and data
- ✅ Backs up user definitions (without passwords)
- ✅ Backs up all permissions and ownership
- ❌ Does NOT back up passwords (for security)

After restoring from backup, user passwords must be reset using the `db-admin` migrations.

## Recovery Scenarios

### Scenario 1: Full System Recovery (Complete Data Loss)

**When to use:**
- Server failure with complete data loss
- Corrupted database that cannot be repaired
- Need to recover to a clean state

**Steps:**

```bash
# 1. Start PostgreSQL container
mise run up:postgres

# 2. Restore data from S3 (latest backup)
mise run restore:postgres:s3:latest

# Or restore from specific backup file
mise run restore:postgres:s3:file
# When prompted, enter: 20251116/postgres-all-20251116-095831.sql.gz

# 3. Reset user passwords from Parameter Store
mise run env:admin                # Fetch passwords from Parameter Store
mise run db:init                  # Run migrations to reset passwords

# 4. Verify the restoration
mise run migrate:hono             # Test with hono-demo migrations
```

**Expected Output:**
```
✅ Database restored successfully
✅ User passwords reset
✅ Application can connect
```

### Scenario 2: Local Recovery (Development Environment)

**When to use:**
- Testing restore process locally
- Accidentally dropped important data
- Need to reset development environment

**Steps:**

```bash
# 1. Restore from latest local backup
mise run restore:postgres:latest

# 2. Reset passwords
mise run env:admin
mise run db:init

# 3. Verify
mise run migrate:hono
```

### Scenario 3: Soft Clean + Recovery (Keep Container)

**When to use:**
- Want to clean database but keep container running
- Testing restore process without full rebuild

**Steps:**

```bash
# 1. Clean all user databases (keeps postgres system database)
mise run clean:postgres:soft

# 2. Restore data
mise run restore:postgres:s3:latest

# 3. Reset passwords
mise run env:admin
mise run db:init
```

### Scenario 4: Hard Clean + Recovery (Complete Reset)

**When to use:**
- Complete environment reset
- Container issues
- Want fresh PostgreSQL installation

**Steps:**

```bash
# 1. Stop and remove everything (container + volumes)
mise run clean:postgres:hard

# 2. Start fresh PostgreSQL
mise run up:postgres

# 3. Restore data
mise run restore:postgres:s3:latest

# 4. Reset passwords
mise run env:admin
mise run db:init
```

## Why Passwords Need to Be Reset

### Backup Behavior

When we backup with `--no-role-passwords`:

```sql
-- ✅ This is backed up
CREATE USER demo_user WITH CONNECTION LIMIT 50;
GRANT demo_readwrite TO demo_user;

-- ❌ This is NOT backed up (for security)
ALTER USER demo_user WITH PASSWORD 'secret123';
```

### Restore Result

After restoration:
```sql
-- Users exist, but cannot login
demo_user          | 50 connections | (no password set)
demo_readonly_user | 20 connections | (no password set)
```

### Password Reset Process

`mise run db:init` executes `001-create-demo-db.sh` which:

1. **Checks if database exists** → Skips creation (already restored)
2. **Checks if roles exist** → Skips creation (already restored)
3. **Checks if users exist** → Updates passwords ✅

```sql
-- The migration runs this:
ALTER USER demo_user WITH PASSWORD '${POSTGRES_DEMO_USER_PASSWORD}';
ALTER USER demo_readonly_user WITH PASSWORD '${POSTGRES_DEMO_READONLY_PASSWORD}';
```

Passwords come from AWS Parameter Store via `psenv`.

## Best Practices

### 1. Regular Testing

Test your recovery process monthly:

```bash
# Test in non-production environment
mise run clean:postgres:hard
mise run up:postgres
mise run restore:postgres:s3:latest
mise run db:init
# Verify application works
```

### 2. Verify Backups

Check that backups are running and being uploaded to S3:

```bash
# List recent backups
mise run backup:list

# List S3 backups with details
mise run restore:postgres:s3:list
```

Expected output shows:
- Recent backup dates
- File sizes (should be > 1MB for real data)
- Creation timestamps

### 3. Document Changes

When adding new databases:

1. Create migration script: `infra-apps/db-admin/migrations/00X-create-xxx-db.sh`
2. Add password reset to this guide
3. Test full recovery workflow
4. Update `.env.example` with new password variables

### 4. Password Security

- ✅ Never commit passwords to git
- ✅ Store passwords in AWS Parameter Store
- ✅ Use `psenv` to fetch passwords
- ✅ Keep backups secure (S3 access control)
- ✅ Never use `pg_dumpall` without `--no-role-passwords` in production

## Troubleshooting

### Problem: "password authentication failed"

**Cause:** Passwords were not reset after restoration.

**Solution:**
```bash
mise run env:admin
mise run db:init
```

### Problem: "database does not exist"

**Cause:** Database was not restored or manually created.

**Solution:**
```bash
# If restore failed, try again
mise run restore:postgres:s3:latest

# Or create database manually
docker compose exec postgres psql -U postgres -c "CREATE DATABASE demo;"
```

### Problem: "role does not exist"

**Cause:** Restore did not complete successfully.

**Solution:**
```bash
# Re-run restore
mise run restore:postgres:s3:latest

# If still failing, check backup file integrity
mise run restore:postgres:s3:list
```

### Problem: Connection refused

**Cause:** PostgreSQL container is not running.

**Solution:**
```bash
cd infra-apps/postgres
docker compose ps                # Check status
docker compose logs postgres     # Check logs
mise run up:postgres            # Start if stopped
```

## Recovery Time Objective (RTO)

Expected recovery times:

| Scenario | Time | Steps |
|----------|------|-------|
| Local restore | 2-5 min | 3 commands |
| S3 restore (small DB < 100MB) | 5-10 min | 4 commands |
| S3 restore (large DB > 1GB) | 15-30 min | 4 commands |
| Complete rebuild | 10-20 min | 5 commands |

## Quick Reference

```bash
# Backup
mise run dev:backup              # Manual backup now
mise run backup:list             # List all backups

# Restore - Local
mise run restore:postgres:latest # From latest local backup
mise run restore:postgres:file   # From specific local file

# Restore - S3
mise run restore:postgres:s3:list   # List S3 backups
mise run restore:postgres:s3:latest # From latest S3 backup
mise run restore:postgres:s3:file   # From specific S3 file

# Password Management
mise run env:admin               # Fetch passwords from Parameter Store
mise run db:init                 # Run migrations (reset passwords)

# Clean
mise run clean:postgres:soft     # Delete all user databases
mise run clean:postgres:hard     # Delete container + volumes

# Verification
mise run migrate:hono            # Test hono-demo database
mise run db                      # Open psql shell
```

## Production vs Development

This workflow is **identical** for both production and development:

**Development:**
```bash
restore:postgres:latest          # Uses local backups
```

**Production:**
```bash
restore:postgres:s3:latest       # Uses S3 backups
```

Both follow the same password reset process, ensuring consistency.
