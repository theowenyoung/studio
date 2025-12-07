# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Monorepo for containerized applications deployed to Hetzner servers. Uses Docker-based deployments with automatic environment detection (main branch → production, other branches → preview).

## Essential Commands

All commands use `mise run` (alias `mr`):

### Development
```bash
mr env                  # Fetch env vars from AWS Parameter Store
mr up                   # Start local infrastructure (postgres, redis, caddy, meilisearch)
mr down                 # Stop local infrastructure
mr dev                  # Start all JS app dev servers
mr dev-hono             # Start specific app dev server
mr dev-db-prepare       # Initialize database (run admin migrations)
mr dev-db-migrate       # Run all application migrations
mr db                   # Connect to PostgreSQL
```

### Build & Test
```bash
mr lint                 # Lint all projects
mr test                 # Run tests
mr format               # Format code with Prettier
mr build                # Build all projects
```

### Deployment (auto-detects environment from git branch)
```bash
mr deploy-hono          # Deploy hono-demo
mr deploy-infra         # Deploy all infrastructure
mr deploy-db-prepare    # Run database migrations on server
mr reload-caddy         # Rebuild and reload Caddy config
```

### Server Operations
```bash
mr ssh                  # SSH to prod server
mr ssh-preview          # SSH to preview server
mr server-init          # Initialize server(s)
mr backup               # Run backup on prod servers
```

## Architecture

```
studio/
├── js-apps/           # Node.js apps (Hono, Next.js, Remix, Express)
├── js-packages/       # Shared TypeScript packages (ui, config-*)
├── infra-apps/        # Infrastructure (postgres, redis, caddy, backup, db-prepare)
├── external-apps/     # Third-party services (meilisearch, owen-blog)
├── rust-packages/     # Rust tools (psenv - AWS Parameter Store sync)
├── ansible/           # Deployment playbooks
├── docker/            # Shared Dockerfiles
└── scripts/           # Build and deployment scripts
```

## Key Patterns

### Single Source of Truth
- All task logic lives in `mise.toml`, not duplicated in CI workflows
- CI workflows should call `mise run <task>` instead of reimplementing commands
- If CI needs special flags (e.g., `--become` for sudo), add them to the mise task definition

### Environment Variables
- Sensitive values stored in AWS Parameter Store, fetched via `psenv`
- `.env.example` files use template syntax: `${VAR:-default}` and `${CTX_*}` context variables
- Context variables (`CTX_*`) are injected by build scripts for server-specific values

### Preview Environment Isolation
Each feature branch gets isolated resources (double separator convention):
- Database: `hono_demo__feat_auth` (double underscore)
- Domain: `hono-demo--feat-auth.preview.owenyoung.com` (double hyphen)
- Container/directory names follow the same pattern

### Multi-Server Production
- Apps specify target server via `DEPLOY_SERVER=prod2` in `.env.example`
- Database migrations separated by server in `infra-apps/db-prepare/migrations-prodN/`

### Build Process
Each app has a `build.sh` that:
1. Detects environment from git branch
2. Builds Docker image with ECR tagging
3. Pushes to AWS ECR

## Tools & Versions
- Package manager: pnpm
- Task runner: mise (see `mise.toml` for all tasks)
- Node: LTS (≥22)
- Rust: 1.83
- Python: 3.14
