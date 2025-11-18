#!/bin/sh
# ==========================================
# PostgreSQL Database Setup Functions
# ==========================================
# This file provides reusable functions for database setup.
# It should be sourced by other scripts.

set -e

# ==========================================
# Logging
# ==========================================
log() {
  echo "[$(date +'%Y-%m-%d %H:%M:%S')] $1"
}

log_error() {
  echo "[$(date +'%Y-%m-%d %H:%M:%S')] ERROR: $1" >&2
}

log_success() {
  echo "[$(date +'%Y-%m-%d %H:%M:%S')] ✓ $1"
}

# ==========================================
# Main Function: Create Database with Users
# ==========================================
# Usage: create_database_with_users DB_NAME RW_PASSWORD RO_PASSWORD [DESCRIPTION]
create_database_with_users() {
  local db_name="$1"
  local rw_password="$2"
  local ro_password="$3"
  local description="${4:-$db_name database}"

  # Validate parameters
  if [ -z "$db_name" ]; then
    log_error "Database name is required"
    return 1
  fi

  if [ -z "$rw_password" ]; then
    log_error "Read-write password is required"
    return 1
  fi

  if [ -z "$ro_password" ]; then
    log_error "Read-only password is required"
    return 1
  fi

  log "=========================================="
  log "Setting up database: $db_name"
  log "Description: $description"
  log "=========================================="

  # Step 1: Create Database
  _create_database "$db_name" "$description"

  # Step 2: Setup Roles
  _create_roles "$db_name"

  # Step 3: Create Users
  _create_users "$db_name" "$rw_password" "$ro_password"

  # Step 4: Apply Security
  _apply_security "$db_name"

  log_success "Database '$db_name' setup completed!"
  log "  - ${db_name}_user (read-write)"
  log "  - ${db_name}_readonly_user (read-only)"
  log "=========================================="
}

# ==========================================
# Internal Functions
# ==========================================

_create_database() {
  local db_name="$1"
  local description="$2"

  log "Creating database..."

  # Check if database exists
  local db_exists=$(psql -t --username "$POSTGRES_USER" --dbname "postgres" -c \
    "SELECT 1 FROM pg_database WHERE datname = '$db_name';")

  if [ -z "$db_exists" ]; then
    # Database doesn't exist, create it
    psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "postgres" <<-EOSQL
        CREATE DATABASE $db_name
            WITH
            OWNER = postgres
            ENCODING = 'UTF8'
            LC_COLLATE = 'en_US.utf8'
            LC_CTYPE = 'en_US.utf8'
            TEMPLATE = template0
            CONNECTION LIMIT = -1;

        COMMENT ON DATABASE $db_name IS '$description';
EOSQL
    log_success "Database created"
  else
    log "Database $db_name already exists, skipping creation"
  fi
}

_create_roles() {
  local db_name="$1"

  log "Creating roles..."

  # Install extensions (continue on error for optional extensions)
  psql --username "$POSTGRES_USER" --dbname "$db_name" <<-EOSQL
        -- Install extensions (IF NOT EXISTS prevents errors if already installed)

        -- ULID generation (optional, may not be available)
        DO \$\$
        BEGIN
            CREATE EXTENSION IF NOT EXISTS "pg_ulid";
        EXCEPTION WHEN OTHERS THEN
            RAISE NOTICE 'pg_ulid extension not available, skipping';
        END
        \$\$;

        -- Advanced text search capabilities
        CREATE EXTENSION IF NOT EXISTS "pg_trgm";

        -- Better statistics for query planning
        CREATE EXTENSION IF NOT EXISTS "pg_stat_statements";
        
        -- Read-write role
        DO \$\$
        BEGIN
            IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = '${db_name}_readwrite') THEN
                CREATE ROLE ${db_name}_readwrite;
                
                -- Schema permissions
                GRANT USAGE, CREATE ON SCHEMA public TO ${db_name}_readwrite;
                
                -- Table permissions (current and future)
                GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO ${db_name}_readwrite;
                ALTER DEFAULT PRIVILEGES IN SCHEMA public 
                    GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO ${db_name}_readwrite;
                
                -- Sequence permissions (current and future)
                GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO ${db_name}_readwrite;
                ALTER DEFAULT PRIVILEGES IN SCHEMA public 
                    GRANT USAGE, SELECT ON SEQUENCES TO ${db_name}_readwrite;
                
                -- Function permissions (future)
                ALTER DEFAULT PRIVILEGES IN SCHEMA public 
                    GRANT EXECUTE ON FUNCTIONS TO ${db_name}_readwrite;
            END IF;
        END
        \$\$;
        
        -- Read-only role
        DO \$\$
        BEGIN
            IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = '${db_name}_readonly') THEN
                CREATE ROLE ${db_name}_readonly;
                
                -- Schema permissions
                GRANT USAGE ON SCHEMA public TO ${db_name}_readonly;
                
                -- Table permissions (current and future)
                GRANT SELECT ON ALL TABLES IN SCHEMA public TO ${db_name}_readonly;
                ALTER DEFAULT PRIVILEGES IN SCHEMA public 
                    GRANT SELECT ON TABLES TO ${db_name}_readonly;
            END IF;
        END
        \$\$;
EOSQL

  log_success "Roles created"
}

_create_users() {
  local db_name="$1"
  local rw_password="$2"
  local ro_password="$3"

  log "Creating/updating users..."

  psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$db_name" <<-EOSQL
        -- Read-write user
        DO \$\$
        BEGIN
            IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = '${db_name}_user') THEN
                -- User doesn't exist, create it
                CREATE USER ${db_name}_user WITH
                    PASSWORD '$rw_password'
                    CONNECTION LIMIT 50;

                GRANT ${db_name}_readwrite TO ${db_name}_user;
                GRANT CONNECT ON DATABASE $db_name TO ${db_name}_user;

                COMMENT ON ROLE ${db_name}_user IS 'Read-write user for $db_name database';
            ELSE
                -- User exists (from restore), update password
                ALTER USER ${db_name}_user WITH PASSWORD '$rw_password';
            END IF;
        END
        \$\$;

        -- Read-only user
        DO \$\$
        BEGIN
            IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = '${db_name}_readonly_user') THEN
                -- User doesn't exist, create it
                CREATE USER ${db_name}_readonly_user WITH
                    PASSWORD '$ro_password'
                    CONNECTION LIMIT 20;

                GRANT ${db_name}_readonly TO ${db_name}_readonly_user;
                GRANT CONNECT ON DATABASE $db_name TO ${db_name}_readonly_user;

                COMMENT ON ROLE ${db_name}_readonly_user IS 'Read-only user for $db_name database';
            ELSE
                -- User exists (from restore), update password
                ALTER USER ${db_name}_readonly_user WITH PASSWORD '$ro_password';
            END IF;
        END
        \$\$;
EOSQL

  log_success "Users created/updated"
}

_apply_security() {
  local db_name="$1"

  log "Applying security policies..."

  psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$db_name" <<-EOSQL
        -- Revoke public permissions
        REVOKE CREATE ON SCHEMA public FROM PUBLIC;
        REVOKE ALL ON DATABASE $db_name FROM PUBLIC;
EOSQL

  log_success "Security applied"
}

# Note: Functions are available when this file is sourced
# No need to export since we're sourcing in the same shell
