# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

This is a multi-language monorepo for deploying containerized applications to Hetzner servers using Docker, Ansible, and mise for task orchestration. The project supports both production and preview environments with automated deployments.

**Key Technologies:**
- **Task Runner**: mise (replaces package.json scripts at root level)
- **Package Manager**: pnpm with workspaces
- **Deployment**: Ansible + Docker Compose + AWS ECR
- **Infrastructure**: PostgreSQL, Redis, Caddy (reverse proxy)
- **Languages**: TypeScript/Node.js (primary), Rust (tooling), Python (Ansible)

## Repository Structure

```
studio-new/
├── js-apps/           # Node.js applications (hono-demo, proxy, blog, storefront, api, admin)
├── js-packages/       # Shared TypeScript packages (workspace packages)
├── infra-apps/        # Infrastructure services (postgres, redis, caddy, backup, db-admin)
├── external-apps/     # External third-party services (meilisearch, owen-blog)
├── rust-packages/     # Rust utilities (psenv - AWS Parameter Store sync tool)
├── ansible/           # Deployment playbooks and inventory
├── docker/            # Shared Dockerfiles (nodejs, nodejs-ssg, static-site)
├── scripts/           # Build and deployment scripts
└── mise.toml          # Root task definitions (USE THIS, not package.json scripts)
```

### Application Types

1. **JS Apps** (`js-apps/`):
   - Backend apps (hono-demo, proxy, api): Vite + Hono + PostgreSQL/Redis
   - SSG apps (blog, storefront): Next.js/Remix static site generation
   - Each has its own `build.sh`, `package.json`, and `docker-compose.prod.yml`

2. **Infrastructure** (`infra-apps/`):
   - PostgreSQL, Redis, Caddy (reverse proxy), Backup service, DB admin migrations
   - Each service has `docker-compose.yml` for local dev and production

3. **External Apps** (`external-apps/`):
   - Third-party services like Meilisearch, external blogs
   - Deployed similarly to infra services

## Development Workflow

### Essential Commands

**IMPORTANT**: Always use `mise run` (or alias `mr`) at the root level, NOT `npm`/`pnpm` scripts from package.json. Root package.json is minimal; all tasks are in mise.toml.

```bash
# Local development setup (first time only)
mise run init              # Create Docker network
mise run env               # Fetch .env files from AWS Parameter Store
mise run up                # Start postgres, redis, caddy, meilisearch
mise run dev-db-admin           # Initialize database users and permissions
mise run db-migrate-hono   # Run application migrations

# Start development servers
mise run dev-hono          # Start hono-demo (http://localhost:8001)
mise run dev-proxy         # Start proxy
mise run dev               # Start ALL js-apps in parallel

# Stop all dev servers (use if Ctrl+C doesn't clean up properly)
mise run dev-kill

# Database operations
mise run db                # Connect to PostgreSQL CLI
mise run db-migrate        # Run all app migrations
mise run db-migrate-hono   # Run specific app migrations

# View infrastructure logs
mise run logs              # Tail all infrastructure logs
mise run dev-logs-postgres # PostgreSQL logs only
mise run dev-logs-redis    # Redis logs only
mise run dev-logs-caddy    # Caddy logs only

# Code quality
mise run lint              # Lint all projects
mise run format            # Format with Prettier
mise run test              # Run tests
```

### Working with Specific Apps

```bash
# Add dependencies to a specific app
mise run addjs hono-demo express zod

# Run custom commands in an app
mise run buildjs hono-demo build
mise run buildjs hono-demo migrate:create add-users-table
```

### Environment Variables

本项目使用 **两阶段模板渲染** 来管理环境变量配置。详细文档请参考：[ENV_TEMPLATE_GUIDE.md](docs/ENV_TEMPLATE_GUIDE.md)

**核心概念：**
- **源变量**: 从 AWS Parameter Store、环境变量或文件默认值获取
- **计算变量**: 使用 `${VAR:-default}` 语法在运行时动态组合
- **上下文变量**: `build-lib.sh` 根据环境自动注入 `CTX_*` 变量

**快速使用：**
```bash
# 本地开发 - 自动使用 localhost
export POSTGRES_USER="app_user"
export POSTGRES_PASSWORD="dev"
mise run dev-env-hono  # 生成 js-apps/hono-demo/.env

# Preview/Prod - 从 AWS 获取凭证，自动拼接分支后缀
mise run env            # 生成所有应用的 .env
```

**配置文件示例：** (`js-apps/*/.env.example`)
```bash
# 源变量（从 AWS 或环境变量获取）
POSTGRES_USER=
POSTGRES_PASSWORD=
POSTGRES_DB_NAME=
APP_SUBDOMAIN=hono-demo

# 计算变量（模板渲染）
DB_HOST=${CTX_PG_HOST:-localhost}
POSTGRES_DB=${POSTGRES_DB_NAME}${CTX_DB_SUFFIX:-}
APP_URL=https://${APP_SUBDOMAIN}${CTX_DNS_SUFFIX:-}.${CTX_ROOT_DOMAIN:-studio.localhost}
DATABASE_URL=postgresql://${POSTGRES_USER}:${POSTGRES_PASSWORD}@${DB_HOST}:5432/${POSTGRES_DB}
```

## Deployment

### Architecture

- **Environments**:
  - `prod`: main branch → production server (5.78.126.18)
  - `preview`: feature branches → preview server (138.199.157.194)
  - Auto-detected based on git branch in `scripts/build-lib.sh`

- **Docker Images**: Stored in AWS ECR (`912951144733.dkr.ecr.us-west-2.amazonaws.com`)
  - Production tags: `prod-latest`, `prod-YYYYMMDDHHMMSS`
  - Preview tags: `preview-{branch}`, `preview-{branch}-YYYYMMDDHHMMSS`
  - Lifecycle policies: keep 5 prod images, delete preview >3 days old

### Deployment Commands

```bash
# Infrastructure (run once, or when config changes)
mise run deploy-postgres   # Deploy PostgreSQL
mise run deploy-redis      # Deploy Redis
mise run deploy-caddy      # Deploy Caddy (auto-reloads config if changed)
mise run deploy-infra      # Deploy all infrastructure at once
mise run deploy-db-admin   # Run database initialization migrations

# Applications (builds Docker image + deploys)
mise run deploy-hono       # Build + deploy hono-demo (auto-detects prod/preview)
mise run deploy-proxy      # Build + deploy proxy
mise run deploy-storefront # Build + deploy storefront (SSG)
mise run deploy-blog       # Build + deploy blog (SSG)

# External services
mise run deploy-meilisearch
mise run deploy-owen-blog

# Migrations (run separately if needed)
mise run deploy-migrate-hono
```

### Build Process

Each app has a `build.sh` that:
1. Detects environment (prod vs preview) based on git branch
2. Builds Docker image using shared Dockerfile from `docker/` directory
3. Pushes to AWS ECR with version tag (UTC timestamp: YYYYMMDDHHMMSS)
4. Generates `deploy-dist/` folder with:
   - `docker-compose.yml` (with image tag substituted)
   - `.env` (fetched from AWS Parameter Store for prod)
   - `version.txt` (deployment version)

### Deployment Process

Ansible playbooks (in `ansible/playbooks/`):
1. Sync `deploy-dist/` to server at `/srv/studio/{app-type}/{app-name}/{version}/`
2. Update symlink: `current → {version}`
3. Run migrations if applicable (for apps with databases)
4. Execute `docker compose up -d --remove-orphans`
5. Health check: wait for container to be `running` or `healthy`
6. Clean up: keep only 3 most recent versions

### Server Operations

```bash
# SSH to servers
mise run ssh               # Production server
mise run ssh-preview       # Preview server

# On server (uses server-mise.toml)
mr db-restore-s3           # Restore from S3 backup
mr db-backup-now           # Create backup immediately
mr logs                    # View app logs
mr ps                      # Show running containers
```

### Preview Environments

- Each git branch gets its own preview deployment
- Resources are namespaced: `preview-{branch-slug}-{service}`
- Databases are separate per branch
- Clean up old previews: `mise run preview-destroy` (destroys current branch's resources)

## Database Architecture

### Development (Local)

- Single PostgreSQL instance with shared `postgres` superuser
- All apps connect to same database with same credentials
- Simple for local development
- Initialize: `mise run db-init` (creates databases and basic users)

### Production

- Individual database users per application with least-privilege permissions
- Read-only users for analytics/reporting
- Proper permission isolation
- Initialize: Run `mise run deploy-db-admin` (executes SQL migrations from `infra-apps/db-admin/`)

### Migrations

- **Infrastructure migrations** (`infra-apps/db-admin/`): Create users, databases, permissions
  - Uses plain SQL files with conditional logic based on `DEPLOY_ENV` variable
  - Run via Docker: `docker compose run --rm db-admin`

- **Application migrations** (`js-apps/*/migrations/`): Schema changes for each app
  - Uses `node-pg-migrate` library
  - Run: `mise run db-migrate-hono` or `pnpm --filter hono-demo migrate`
  - Create new: `pnpm --filter hono-demo migrate:create table-name`

### Backups

- Automated daily backups via `infra-apps/backup/` service
- Stored locally in `/data/backups/` and synced to S3
- Restore: `mr db-restore-s3` (on server) or `mr db-restore-local`

## Server Management

### Server Initialization (First Time)

```bash
# 1. Create deploy user on new server(s)
mise run server-init-user <server-ip> [<server-ip>...]

# 2. Update ansible/inventory.yml with server details

# 3. Initialize server (security, Docker, directories, mise)
mise run server-init       # All servers
mise run server-init-prod  # Production only
mise run server-init-preview # Preview only
```

### Server Updates

```bash
# Update server configuration (skip system updates)
mise run server-update     # All servers
mise run sync-config       # Sync mise.toml and bash aliases only

# Configure AWS credentials (for ECR access)
mise run server-configure-aws
```

### Server Directory Structure

```
/srv/studio/
├── infra-apps/{service}/current/     # Symlink to latest version
├── js-apps/{app}/current/            # Symlink to latest version
└── external-apps/{service}/current/  # Symlink to latest version

/data/
├── docker/          # Docker volumes (postgres, redis data)
└── backups/         # Database backups (local + S3)
```

## Key Concepts

### mise Task Orchestration

- **All root-level commands use mise**, not package.json scripts
- Task naming conventions:
  - `dev-*`: Local development tasks
  - `build-*`: Build Docker images
  - `deploy-*`: Deploy to production/preview
  - `db-*`: Database operations
  - `server-*`: Server management

- Task dependencies: Some tasks auto-run prerequisites (e.g., `deploy-hono` depends on `build-hono-demo`)

### Environment Detection

The build system auto-detects environment:
- **main branch** → `prod` environment → production server
- **other branches** → `preview` environment → preview server
- Override: Set `DEPLOY_ENV=prod` or `ANSIBLE_LIMIT=preview` env vars

### Zero-Downtime Deployments

- Docker Compose recreates containers with new images
- Health checks ensure container is ready before marking deployment successful
- Caddy automatically routes traffic without downtime
- Old versions kept (3 most recent) for quick rollback

### Rollback Strategy

**Preferred**: Redeploy old version via CI/CD
```bash
# Option 1: Use old commit
git checkout <old-commit>
mise run deploy-hono

# Option 2: Specify old version (if VERSION env var supported)
VERSION=20250101120000 mise run deploy-hono
```

**Server-side** (emergency only): Update `current` symlink to previous version
```bash
ssh deploy@server
cd /srv/studio/js-apps/hono-demo
ln -sfn 20250101120000 current
cd current && docker compose up -d
```

## Common Development Tasks

### Adding a New JavaScript App

1. Create directory in `js-apps/new-app/`
2. Add `package.json` with standard scripts: `dev`, `build`, `start`, `migrate`
3. Create `build.sh` (copy from existing app, update SERVICE_NAME)
4. Create `docker-compose.prod.yml` for deployment
5. Add mise tasks in `mise.toml`:
   - `dev-new-app`
   - `build-new-app`
   - `deploy-new-app`
6. Update pnpm workspace (auto-detected via `pnpm-workspace.yaml`)

### Modifying Infrastructure

- **Caddy config changes**: Edit `infra-apps/caddy/Caddyfile`, deploy with `mise run deploy-caddy` (auto-reloads)
- **PostgreSQL changes**: Edit `infra-apps/postgres/docker-compose.yml`, redeploy
- **New infrastructure service**: Follow pattern in `infra-apps/`, create Ansible playbook

### Database Schema Changes

1. Create migration: `pnpm --filter hono-demo migrate:create description`
2. Edit generated file in `js-apps/hono-demo/migrations/`
3. Test locally: `mise run db-migrate-hono`
4. Deploy: Migrations run automatically during `mise run deploy-hono`

## Troubleshooting

### Build Failures

- Check Docker build logs: `docker build` output in `build.sh`
- Verify ECR login: `aws ecr get-login-password` must succeed
- Check .env.example exists for production env var fetching

### Deployment Failures

- Check Ansible output for specific errors
- Verify server connectivity: `ansible all -i ansible/inventory.yml -m ping`
- Check container logs on server: `ssh deploy@server "cd /srv/studio/js-apps/hono-demo/current && docker compose logs"`

### Database Issues

- Connection failures: Verify PostgreSQL is running: `mise run dev-logs-postgres`
- Migration errors: Check migration files for syntax errors, test locally first
- Permission issues: Re-run `mise run db-init` (dev) or `mise run deploy-db-admin` (prod)

### Development Server Issues

- Port conflicts: Check if ports are in use with `lsof -i :8001`
- Cleanup zombie processes: `mise run dev-kill`
- Docker network issues: Recreate network: `docker network rm shared && mise run init`

### Preview Environment Cleanup

- List active previews: `mise run preview-list`
- Destroy current branch: `mise run preview-destroy`
- List old preview databases: `mise run preview-list-old`

## Important Files

- `mise.toml`: All root-level task definitions (READ THIS for available commands)
- `server-mise.toml`: Tasks available on production servers (synced via Ansible)
- `ansible/inventory.yml`: Server IP addresses and configuration
- `scripts/build-lib.sh`: Shared build functions (versioning, ECR, environment detection)
- `DEPLOYMENT.md`: Detailed deployment guide and architecture
- `README.md`: Chinese documentation with setup instructions
