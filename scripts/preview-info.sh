#!/bin/bash
set -e

# Load common functions
source "$(dirname "$0")/build-lib.sh"

# Detect environment
detect_environment

# Define all services
SERVICES=("hono-demo" "blog" "storefront" "proxy")

if [ "$DEPLOY_ENV" = "prod" ]; then
    echo "📍 Production Environment"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "   Branch: $CURRENT_BRANCH"
    echo ""
    echo "🌐 Domains:"
    for service in "${SERVICES[@]}"; do
        echo "   • https://$service.owenyoung.com"
    done
    echo ""
    echo "💾 Databases:"
    for service in "${SERVICES[@]}"; do
        db_name=$(echo "$service" | tr '-' '_')
        echo "   • $db_name"
    done
else
    echo "📍 Preview Environment"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "   Branch:     $CURRENT_BRANCH"
    echo "   Clean name: $BRANCH_CLEAN"
    echo ""
    echo "🌐 Domains (if deployed):"
    for service in "${SERVICES[@]}"; do
        # Generate domain: branch-service-preview.owenyoung.com
        domain="${BRANCH_CLEAN}-${service}-preview.owenyoung.com"
        echo "   • https://$domain"
    done
    echo ""
    echo "💾 Database names:"
    for service in "${SERVICES[@]}"; do
        # Generate database name: service_branch (e.g., hono_demo_feat_auth)
        db_base=$(echo "$service" | tr '-' '_')
        db_name="${db_base}_${BRANCH_CLEAN//-/_}"
        echo "   • $db_name"
    done
    echo ""
    echo "🐳 Docker tags:"
    for service in "${SERVICES[@]}"; do
        tag=$(get_image_tag "latest")
        echo "   • $service:$tag"
    done
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "Querying database status on prod server..."
    echo ""

    # Query database info using Ansible
    ansible-playbook -i ansible/inventory.yml \
      ansible/playbooks/list-preview-dbs.yml \
      -e branch_name=$BRANCH_CLEAN \
      -l prod 2>/dev/null || echo "⚠️  Could not query database information"
fi
