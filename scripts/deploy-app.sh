#!/bin/bash
set -e

# Load common functions
source "$(dirname "$0")/build-lib.sh"

# Detect environment
detect_environment

# Get service name from argument
SERVICE_BASE=$1
if [ -z "$SERVICE_BASE" ]; then
    echo "❌ Error: Service name is required"
    echo "Usage: $0 <service-name>"
    exit 1
fi

# Generate resource names
SERVICE_NAME=$(get_service_name "$SERVICE_BASE")
DATABASE_NAME=$(get_database_name "$SERVICE_BASE")
DOMAIN=$(get_domain "$SERVICE_BASE")

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
