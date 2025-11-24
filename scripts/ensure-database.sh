#!/bin/bash
set -e

# ==========================================
# Ensure Database Exists
# ==========================================
# This script ensures a database exists before running migrations.
# It extracts the database name from DATABASE_URL and creates it if needed.
#
# Usage:
#   ensure-database.sh [DATABASE_URL]
#
# If DATABASE_URL is not provided, it reads from environment variable.
# ==========================================

DATABASE_URL="${1:-${DATABASE_URL}}"

if [ -z "$DATABASE_URL" ]; then
    echo "❌ Error: DATABASE_URL is required"
    echo "Usage: $0 <DATABASE_URL>"
    echo "   Or: DATABASE_URL=xxx $0"
    exit 1
fi

# Parse DATABASE_URL
# Format: postgresql://user:password@host:port/database
# Extract components using parameter expansion and sed

# Extract everything after postgresql://
URL_WITHOUT_PROTOCOL="${DATABASE_URL#postgresql://}"
URL_WITHOUT_PROTOCOL="${URL_WITHOUT_PROTOCOL#postgres://}"

# Extract user:password
USER_PASS="${URL_WITHOUT_PROTOCOL%%@*}"
DB_USER="${USER_PASS%%:*}"
DB_PASSWORD="${USER_PASS#*:}"

# Extract host:port/database
HOST_DB="${URL_WITHOUT_PROTOCOL#*@}"
HOST_PORT="${HOST_DB%%/*}"
DB_HOST="${HOST_PORT%%:*}"
DB_PORT="${HOST_PORT#*:}"
# If port is same as host, default to 5432
if [ "$DB_PORT" = "$DB_HOST" ]; then
    DB_PORT="5432"
fi

# Extract database name
DB_NAME="${HOST_DB#*/}"
# Remove query parameters if any
DB_NAME="${DB_NAME%%\?*}"

echo "🔍 Checking database: $DB_NAME"
echo "   Host: $DB_HOST:$DB_PORT"
echo "   User: $DB_USER"

# Check if database exists
PGPASSWORD="$DB_PASSWORD" psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -lqt 2>/dev/null | cut -d \| -f 1 | grep -qw "$DB_NAME" && DB_EXISTS=1 || DB_EXISTS=0

if [ $DB_EXISTS -eq 1 ]; then
    echo "✅ Database $DB_NAME already exists"
    exit 0
fi

echo "📦 Database $DB_NAME does not exist, creating..."

# Create database with postgres superuser (all environments)
psql -h "$DB_HOST" -p "$DB_PORT" -U postgres -d postgres -c "
CREATE DATABASE $DB_NAME OWNER $DB_USER;
REVOKE CONNECT ON DATABASE $DB_NAME FROM PUBLIC;
GRANT CONNECT ON DATABASE $DB_NAME TO $DB_USER;
" 2>/dev/null && {
    echo "✅ Database $DB_NAME created successfully"
    echo "   Owner: $DB_USER"
    echo "   Access: Only $DB_USER can connect"
    exit 0
}

# If that fails, show error
echo "❌ Error: Failed to create database $DB_NAME"
echo ""
echo "Please ensure:"
echo "  1. PostgreSQL is running"
echo "  2. postgres user is accessible (local development: no password needed)"
echo ""
echo "Manual creation:"
echo "  psql -U postgres -c \"CREATE DATABASE $DB_NAME OWNER $DB_USER\""
exit 1
