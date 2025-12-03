#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
source "$SCRIPT_DIR/build-lib.sh"

# Parse arguments
FORCE_ENV="${1:-auto}"

# Determine environment
if [ "$FORCE_ENV" = "prod" ]; then
  # Force production environment
  export DEPLOY_ENV="prod"
  export AWS_PARAM_PATH="/studio-prod/"
  export CTX_DB_SUFFIX=""
  export CTX_DNS_SUFFIX=""
  export CTX_ROOT_DOMAIN="owenyoung.com"
  echo "🚀 Deploying db-admin to PRODUCTION (forced)..."

elif [ "$FORCE_ENV" = "preview" ]; then
  # Force preview environment
  CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD)
  BRANCH_CLEAN=$(echo "$CURRENT_BRANCH" | sed 's/[^a-zA-Z0-9-]/-/g' | tr '[:upper:]' '[:lower:]' | cut -c1-30)

  export DEPLOY_ENV="preview"
  export AWS_PARAM_PATH="/studio-dev/"
  export CTX_DB_SUFFIX="_${BRANCH_CLEAN//-/_}"
  export CTX_DNS_SUFFIX="-${BRANCH_CLEAN}"
  export CTX_ROOT_DOMAIN="preview.owenyoung.com"

  echo "🚀 Deploying db-admin to PREVIEW (forced)..."
  echo "   Branch: $CURRENT_BRANCH (clean: $BRANCH_CLEAN)"
  echo "   DB Suffix: $CTX_DB_SUFFIX"

else
  # Auto-detect from git branch
  detect_environment
  echo "🚀 Deploying db-admin to $DEPLOY_ENV environment (auto-detected)..."
fi

# Build with environment context
echo "📦 Building db-admin for $DEPLOY_ENV..."
bash "$REPO_ROOT/infra-apps/db-admin/build.sh"

# Deploy to target environment
if [ "$DEPLOY_ENV" = "prod" ]; then
  ansible-playbook -i ansible/inventory.yml ansible/playbooks/deploy-db-admin.yml \
    -l prod -e deploy_env=prod
else
  ansible-playbook -i ansible/inventory.yml ansible/playbooks/deploy-db-admin.yml \
    -l preview -e deploy_env=preview
fi

echo "✅ Database migrations completed for $DEPLOY_ENV environment"
