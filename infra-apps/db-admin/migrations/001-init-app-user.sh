#!/bin/sh
set -e

# Source the functions library
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
. "$SCRIPT_DIR/../scripts/common.sh"

# ==========================================
# Unified Database Initialization
# ==========================================
# Works for all environments: local, preview, production
# Password source: POSTGRES_APP_USER_PASSWORD env var (with fallback to 'dev' for local)
# ==========================================

echo "🔧 Setting up database infrastructure..."

# Get password from environment variable, fallback to 'dev' for local development
APP_USER_PASSWORD="${POSTGRES_APP_USER_PASSWORD:-dev}"

# Detect environment for logging
if [ "$APP_USER_PASSWORD" = "dev" ]; then
    ENVIRONMENT="local development"
else
    ENVIRONMENT="preview/production"
fi

echo "   Environment: $ENVIRONMENT"

# ==========================================
# Create Shared Application User
# ==========================================

echo "📦 Creating shared application user: app_user"

psql -v ON_ERROR_STOP=1 <<-EOSQL
    -- Create user (no CREATEDB privilege)
    DO \$\$
    BEGIN
        IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'app_user') THEN
            CREATE USER app_user WITH PASSWORD '$APP_USER_PASSWORD';
            RAISE NOTICE 'User app_user created';
        ELSE
            RAISE NOTICE 'User app_user already exists';
        END IF;
    END
    \$\$;

    -- Grant app_user to postgres (allows postgres to create databases owned by app_user)
    GRANT app_user TO postgres;
EOSQL

echo "✅ Database infrastructure ready!"
echo ""
echo "📋 Summary:"
echo "   User:     app_user (no CREATEDB privilege)"
echo "   Password: $([ "$APP_USER_PASSWORD" = "dev" ] && echo "dev (hardcoded for local)" || echo "from POSTGRES_APP_USER_PASSWORD")"
echo "   Note:     Databases created by postgres automatically"
echo ""
echo "💡 Usage:"
if [ "$APP_USER_PASSWORD" = "dev" ]; then
    echo "   DATABASE_URL=postgresql://app_user:dev@localhost:5432/<db_name>"
    echo ""
    echo "🚀 Run migrations with:"
    echo "   pnpm migrate  # or mise run db-migrate-<app>"
else
    echo "   DATABASE_URL=postgresql://app_user:<password>@<host>:5432/<db_name>"
    echo ""
    echo "🚀 Databases created automatically during deployment"
fi
echo ""
