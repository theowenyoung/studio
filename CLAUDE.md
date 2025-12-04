# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

Personal monorepo for deploying containerized applications to Hetzner servers. Uses mise for task management and pnpm for JS package management.

## Common Commands

All commands use `mise run` (alias `mr`):

### Development
```bash
mr dev              # Start all JS apps in parallel
mr dev-hono         # Start specific app (hono-demo, proxy, api)
mr up               # Start local infrastructure (postgres, redis, caddy, meilisearch)
mr down             # Stop local infrastructure
mr env              # Fetch all dev environment variables from AWS Parameter Store
mr db              # Connect to PostgreSQL
mr dev-db-admin    # Run database admin migrations
mr db-migrate-hono # Run hono-demo migrations
```

### Building & Testing
```bash
mr build           # Build all JS projects
mr lint            # Lint all projects
mr test            # Run tests
mr format          # Format code with Prettier
```

### Deployment (auto-detects environment from git branch)
```bash
mr deploy-hono     # Deploy hono-demo (main=prod, other=preview)
mr deploy-caddy    # Deploy Caddy
mr deploy-db-admin # Run database migrations on server
mr reload-caddy    # Quick reload Caddy config without rebuild
```

### Server Operations
```bash
mr ssh             # SSH to prod server
mr ssh-preview     # SSH to preview server
mr server-init     # Initialize servers (prod + preview)
mr sync-config     # Sync server config files
```

## Architecture

### Directory Structure
- `js-apps/` - Node.js applications (hono-demo, proxy, blog, storefront, api, admin)
- `js-packages/` - Shared TypeScript packages (config-eslint, config-typescript, jest-presets, logger, ui)
- `infra-apps/` - Infrastructure services (postgres, redis, caddy, backup, db-admin)
- `external-apps/` - Third-party services (meilisearch, owen-blog)
- `rust-packages/` - Rust tools (psenv for AWS Parameter Store sync)
- `ansible/` - Deployment playbooks
- `scripts/` - Build and deployment scripts

### Environment Detection
Git branch determines deployment target automatically:
- `main` branch -> production environment
- Other branches -> preview environment with isolated database/domain/container per branch

### Environment Variables
Uses `psenv` (Rust tool) for two-phase template rendering:
- Source variables: pulled from AWS Parameter Store at build time
- Computed variables: `${CTX_*}` prefixed vars injected by build scripts
- Local dev: omitted `CTX_*` vars use localhost defaults

### Preview Environment Isolation
Each feature branch gets isolated resources:
- Database: `feat-auth` -> `hono_demo_feat_auth`
- Domain: `feat-auth` -> `https://hono-demo-feat-auth.preview.owenyoung.com`
- Container: `feat-auth` -> `preview-feat-auth-hono-demo`

## Tech Stack
- **Runtime**: Node.js 22+, pnpm 8.15.6
- **Backend**: Hono
- **Frontend**: React, Next.js, Vite
- **Database**: PostgreSQL, Redis, Meilisearch
- **Infrastructure**: Docker, Ansible, Caddy (reverse proxy)
- **Version/Task Manager**: mise

## Local Setup (First Time)
```bash
brew install mkcert
mkcert -install
mkdir -p infra-apps/caddy/.local/certs
mkcert -cert-file infra-apps/caddy/.local/certs/_wildcard.studio.localhost.pem \
       -key-file infra-apps/caddy/.local/certs/_wildcard.studio.localhost-key.pem \
       "*.studio.localhost"
mr env
docker network create shared
mr up
mr dev-db-admin
mr db-migrate-hono
```
