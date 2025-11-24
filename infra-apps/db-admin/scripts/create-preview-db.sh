#!/bin/sh
set -e

# ==========================================
# Create Preview Database Dynamically
# ==========================================
# Usage: create-preview-db.sh <database_name>
# Example: create-preview-db.sh feature_x_hono_demo

DB_NAME="${1:?Error: database name is required}"

echo "🔧 Creating preview database: $DB_NAME"

# Validate database name (alphanumeric and underscores only)
if ! echo "$DB_NAME" | grep -qE '^[a-zA-Z0-9_]+$'; then
    echo "❌ Error: Invalid database name. Only alphanumeric and underscores allowed."
    exit 1
fi

# Check if database already exists
DB_EXISTS=$(psql -tAc "SELECT 1 FROM pg_database WHERE datname='$DB_NAME'")

if [ "$DB_EXISTS" = "1" ]; then
    echo "ℹ️  Database $DB_NAME already exists, skipping creation"
    exit 0
fi

# Create database
psql -v ON_ERROR_STOP=1 <<-EOSQL
    CREATE DATABASE $DB_NAME
        WITH OWNER = preview_app_user
        TEMPLATE = template_preview
        ENCODING = 'UTF8'
        LC_COLLATE = 'en_US.UTF-8'
        LC_CTYPE = 'en_US.UTF-8';
EOSQL

echo "✅ Database $DB_NAME created successfully!"
echo ""
echo "📋 Connection info:"
echo "   Database: $DB_NAME"
echo "   User:     preview_app_user"
echo "   Owner:    preview_app_user"
