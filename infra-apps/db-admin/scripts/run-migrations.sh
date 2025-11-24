#!/bin/sh
# ==========================================
# Database Migration Runner
# ==========================================
# This script waits for PostgreSQL to be ready,
# then executes all migration scripts in order.

set -e

echo "=========================================="
echo "Database Admin Migration Runner"
echo "=========================================="
echo ""

# ==========================================
# Wait for PostgreSQL
# ==========================================
echo "Waiting for PostgreSQL to be ready..."
until pg_isready -h "$PGHOST" -p "$PGPORT" -U "$PGUSER"; do
  echo "PostgreSQL is unavailable - sleeping"
  sleep 2
done

echo "PostgreSQL is ready!"
echo ""

# ==========================================
# Determine Environment
# ==========================================
# Check if DEPLOY_ENV is set for logging purposes
DEPLOY_ENV="${DEPLOY_ENV:-unknown}"

echo "Environment: $DEPLOY_ENV"
echo ""

# ==========================================
# Run Migrations
# ==========================================
echo "Running unified database initialization..."

# Use the unified migration script
MIGRATION_DIR="/migrations"

# Execute all .sh files in the migration directory
for script in "$MIGRATION_DIR"/*.sh; do
  # Check if file exists and is executable
  if [ -f "$script" ] && [ -x "$script" ]; then
    echo "----------------------------------------"
    echo "Executing: $(basename "$script")"
    echo "----------------------------------------"

    # Execute the script with sh (POSIX compatible)
    sh "$script" || {
      echo "ERROR: Migration failed: $(basename "$script")"
      exit 1
    }

    echo ""
  fi
done

echo "=========================================="
echo "All migrations completed successfully!"
echo "=========================================="

exit 0
