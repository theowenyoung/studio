#!/bin/bash
set -e

# Load common functions
source "$(dirname "$0")/build-lib.sh"

# Get service name from argument
SERVICE_BASE=$1
if [ -z "$SERVICE_BASE" ]; then
    echo "❌ Error: Service name is required"
    echo "Usage: $0 <service-name>"
    exit 1
fi

# Change to service directory and detect environment
# This sets CTX_SERVICE_NAME based on the directory
cd "js-apps/$SERVICE_BASE" || cd "infra-apps/$SERVICE_BASE" || cd "external-apps/$SERVICE_BASE" || {
    echo "❌ Error: Service directory not found: $SERVICE_BASE"
    exit 1
}

detect_environment

# Generate resource names using CTX_* variables (same logic as .env.example)
if [ "$DEPLOY_ENV" = "preview" ]; then
    SERVICE_NAME="${SERVICE_BASE}-${BRANCH_CLEAN}"
    DATABASE_NAME=$(echo "${SERVICE_BASE}" | tr '-' '_')"_${BRANCH_CLEAN//-/_}"
    DOMAIN="${BRANCH_CLEAN}-${SERVICE_BASE}-preview.owenyoung.com"
else
    SERVICE_NAME="${SERVICE_BASE}"
    DATABASE_NAME=$(echo "${SERVICE_BASE}" | tr '-' '_')
    DOMAIN="${SERVICE_BASE}.owenyoung.com"
fi

# Display deployment info
echo "🚀 Deploying $SERVICE_BASE"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "   Environment:  $DEPLOY_ENV"
echo "   Branch:       $CURRENT_BRANCH"
echo "   Service:      $SERVICE_NAME"
echo "   Database:     $DATABASE_NAME"
echo "   Domain:       https://$DOMAIN"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Return to repo root for ansible
cd "$(git rev-parse --show-toplevel)"

# Run Ansible playbook
# 使用 -l 限制目标主机（可被环境变量 ANSIBLE_LIMIT 覆盖）
LIMIT=${ANSIBLE_LIMIT:-$ANSIBLE_TARGET}

ansible-playbook -i ansible/inventory.yml \
  ansible/playbooks/deploy-app.yml \
  -e service_base=$SERVICE_BASE \
  -e service_name=$SERVICE_NAME \
  -e database_name=$DATABASE_NAME \
  -e domain=$DOMAIN \
  -e target_env=$DEPLOY_ENV \
  -e branch_name=$BRANCH_CLEAN \
  -l $LIMIT

echo ""
echo "✅ Deployed successfully!"
echo "🌐 Visit: https://$DOMAIN"
