#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
source "$SCRIPT_DIR/build-lib.sh"

# Parse arguments
SERVICE="${1:-}"

if [ -z "$SERVICE" ]; then
    echo "❌ Error: Service name is required"
    echo "Usage: $0 <service-name>"
    exit 1
fi

# Detect environment
detect_environment

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🚀 Deploying External App: $SERVICE"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "   Environment:  $DEPLOY_ENV"
echo "   Branch:       $CURRENT_BRANCH"
echo "   Target:       $ANSIBLE_TARGET"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Build
echo "📦 Building $SERVICE for $DEPLOY_ENV..."
bash "$REPO_ROOT/external-apps/$SERVICE/build.sh"

# Deploy
echo "🚀 Deploying $SERVICE to $ANSIBLE_TARGET..."
ansible-playbook -i ansible/inventory.yml ansible/playbooks/deploy-external-app.yml \
  -e service_name="$SERVICE" \
  -l "$ANSIBLE_TARGET"

echo ""
echo "✅ $SERVICE deployed successfully to $DEPLOY_ENV environment"
