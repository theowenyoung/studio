#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
source "$SCRIPT_DIR/build-lib.sh"

# Parse arguments
SERVICE="${1:-all}"

# Detect environment
detect_environment

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🚀 Deploying Infrastructure"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "   Environment:  $DEPLOY_ENV"
echo "   Branch:       $CURRENT_BRANCH"
echo "   Target:       $ANSIBLE_TARGET"
echo "   Service:      $SERVICE"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Build and deploy based on service
deploy_service() {
  local service_name=$1
  local build_script="$REPO_ROOT/infra-apps/$service_name/build.sh"
  local playbook="ansible/playbooks/deploy-infra-${service_name}.yml"

  echo "📦 Building $service_name for $DEPLOY_ENV..."
  bash "$build_script"

  echo "🚀 Deploying $service_name to $ANSIBLE_TARGET..."
  ansible-playbook -i ansible/inventory.yml "$playbook" -l "$ANSIBLE_TARGET"
  echo ""
}

# Deploy services
if [ "$SERVICE" = "all" ]; then
  deploy_service "postgres"
  deploy_service "redis"
  deploy_service "caddy"

  # Backup only for production
  if [ "$DEPLOY_ENV" = "prod" ]; then
    deploy_service "backup"
  else
    echo "⏭️  Skipping backup service (preview environment)"
  fi
else
  deploy_service "$SERVICE"
fi

echo "✅ Infrastructure deployment completed for $DEPLOY_ENV environment"
