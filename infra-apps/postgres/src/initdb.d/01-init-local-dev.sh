#!/bin/bash
set -e

# ==========================================
# PostgreSQL Initialization (Local Development)
# ==========================================
# This script delegates to db-admin for centralized management
# All database initialization logic is in infra-apps/db-admin/migrations/
# ==========================================

echo "=============================================="
echo "🐘 PostgreSQL Initialization"
echo "=============================================="
echo ""

# Check if db-admin migrations are available
DB_ADMIN_MIGRATIONS="/docker-entrypoint-initdb.d/db-admin-migrations"

if [ -f "$DB_ADMIN_MIGRATIONS/001-init-app-user.sh" ]; then
    echo "📂 Running unified initialization from db-admin..."
    echo ""

    # Run the unified initialization script
    bash "$DB_ADMIN_MIGRATIONS/001-init-app-user.sh"

    echo "✅ Initialization completed!"
else
    echo "⚠️  Warning: db-admin migrations not found at $DB_ADMIN_MIGRATIONS"
    echo "   Make sure to mount db-admin/migrations in docker-compose.yml"
    echo ""
    echo "   Expected volume mount:"
    echo "   - ../db-admin/migrations:/docker-entrypoint-initdb.d/db-admin-migrations:ro"
fi

echo ""
