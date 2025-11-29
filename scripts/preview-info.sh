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
        domain=$(get_domain "$service")
        echo "   • https://$domain"
    done
    echo ""
    echo "💾 Database names:"
    for service in "${SERVICES[@]}"; do
        db_name=$(get_database_name "$service")
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
