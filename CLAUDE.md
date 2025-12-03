# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

Multi-language monorepo for deploying containerized applications to Hetzner servers using Docker, Ansible, and mise for task orchestration. Supports production and preview environments with automated deployments.

**Stack:** mise (task runner), pnpm (workspaces), Ansible + Docker Compose + AWS ECR (deployment), PostgreSQL, Redis, Caddy, TypeScript/Node.js, Rust (psenv tool)

## Repository Structure

```
studio-new/
├── js-apps/           # Node.js apps (hono-demo, proxy, blog, storefront, api, admin)
├── js-packages/       # Shared TypeScript packages
├── infra-apps/        # Infrastructure (postgres, redis, caddy, backup, db-admin)
├── external-apps/     # Third-party services (meilisearch, owen-blog)
├── rust-packages/     # psenv - AWS Parameter Store sync tool
├── ansible/           # Deployment playbooks and inventory
├── docker/            # Shared Dockerfiles (nodejs, nodejs-ssg, static-site)
└── scripts/           # Build and deployment scripts
```

## Essential Commands

**Use `mise run` (or `mr` alias) at root level, NOT npm/pnpm scripts.**

### Local Development

```bash
# First-time setup
mise run init              # Create Docker network
mise run env               # Fetch .env files from AWS Parameter Store
mise run up                # Start postgres, redis, caddy, meilisearch
mise run dev-db-admin      # Initialize database users/permissions
mise run db-migrate-hono   # Run application migrations

# Development servers
mise run dev-hono          # Start hono-demo (http://localhost:8001)
mise run dev-proxy         # Start proxy
mise run dev               # Start ALL js-apps in parallel
mise run dev-kill          # Kill zombie dev processes

# Database
mise run db                # PostgreSQL CLI
mise run db-migrate-hono   # Run hono-demo migrations
```

### Working with JS Apps

```bash
# Add dependencies
mise run addjs hono-demo express zod

# Run custom commands
mise run buildjs hono-demo build
mise run buildjs hono-demo migrate:create add-users-table
```

### Deployment

Environment auto-detected from git branch: `main` → prod, other branches → preview.

```bash
# Infrastructure
mise run deploy-infra      # Deploy all (postgres, redis, caddy, backup)
mise run deploy-db-admin   # Run database migrations

# Applications
mise run deploy-hono       # Build + deploy hono-demo
mise run deploy-proxy
mise run deploy-storefront
mise run deploy-blog
```

### Server Operations

```bash
mise run ssh               # SSH to production
mise run ssh-preview       # SSH to preview

# On server (uses server-mise.toml)
mr db-restore-s3           # Restore from S3 backup
mr logs                    # View app logs
```

## Architecture

### Environment Detection (`scripts/build-lib.sh`)

- Auto-detects `DEPLOY_ENV` from git branch
- Injects `CTX_*` context variables for template rendering
- Preview branches get: `CTX_DB_SUFFIX`, `CTX_DNS_SUFFIX` for resource namespacing

### Two-Phase Environment Variable Rendering

Uses `psenv` (Rust tool) with `.env.example` templates:

1. **Source variables**: Fetched from AWS Parameter Store or shell environment
2. **Computed variables**: Use `${VAR:-default}` syntax, rendered by psenv

```bash
# .env.example example
POSTGRES_USER=                    # From AWS
DB_HOST=${CTX_PG_HOST:-localhost} # Computed with context
DATABASE_URL=postgresql://${POSTGRES_USER}@${DB_HOST}/${POSTGRES_DB}
```

### Build Process

Each app's `build.sh`:
1. Detects environment from git branch
2. Builds Docker image using shared Dockerfile from `docker/`
3. Pushes to AWS ECR with version tag (UTC timestamp: YYYYMMDDHHMMSS)
4. Generates `deploy-dist/` with docker-compose.yml, .env, version.txt

### Deployment Process

Ansible playbooks:
1. Sync `deploy-dist/` to `/srv/studio/{app-type}/{app-name}/{version}/`
2. Update `current` symlink
3. Run migrations if applicable
4. Execute `docker compose up -d`
5. Health check, cleanup old versions (keep 3)

### Server Directory Structure

```
/srv/studio/
├── infra-apps/{service}/current/
├── js-apps/{app}/current/
└── external-apps/{service}/current/

/data/
├── docker/          # Docker volumes
└── backups/         # Database backups
```

## Database

- **Local dev**: Single PostgreSQL with shared credentials, `mise run dev-db-admin` to initialize
- **Production**: Individual users per app with least-privilege, managed via `infra-apps/db-admin/` SQL migrations
- **App migrations**: Use `node-pg-migrate` in each js-app, run with `mise run db-migrate-hono`

## Key Files

- `mise.toml`: All root-level task definitions
- `server-mise.toml`: Server-side tasks (synced via Ansible)
- `ansible/inventory.yml`: Server IPs and configuration
- `scripts/build-lib.sh`: Shared build functions, environment detection
- `docs/ENV_TEMPLATE_GUIDE.md`: Detailed env var template documentation
