#!/bin/sh
set -e

# Source the functions library
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
. "$SCRIPT_DIR/../scripts/common.sh"

# ==========================================
# Unified Database Initialization
# ==========================================
# Works for all environments: local, preview, production
# Password source: POSTGRES_APP_USER_PASSWORD env var (required)
# ==========================================

log "🔧 Setting up database infrastructure..."

# Require password from environment variable
if [ -z "${POSTGRES_APP_USER_PASSWORD}" ]; then
    echo "❌ Error: POSTGRES_APP_USER_PASSWORD environment variable is required"
    echo "Please set it before running this script:"
    echo "  export POSTGRES_APP_USER_PASSWORD='your-secure-password'"
    exit 1
fi

APP_USER_PASSWORD="${POSTGRES_APP_USER_PASSWORD}"

# ==========================================
# Create Shared Application User
# ==========================================

log "📦 Creating shared application user: app_user"

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

log_success "Database infrastructure ready!"
log ""
log "📋 Summary:"
log "   User:     app_user (no CREATEDB privilege)"
log "   Password: from POSTGRES_APP_USER_PASSWORD"
log "   Note:     Databases created by postgres automatically"
log ""
log "💡 Usage:"
log "   DATABASE_URL=postgresql://app_user:<password>@<host>:5432/<db_name>"
log ""
log "🚀 Databases created automatically during deployment"
log ""
