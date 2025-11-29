#!/bin/bash
set -e

# Load common functions
source "$(dirname "$0")/build-lib.sh"

# Detect environment
detect_environment

# Safety check: cannot destroy prod
if [ "$DEPLOY_ENV" = "prod" ]; then
    echo "❌ Error: Cannot destroy prod environment!"
    echo "   You are on branch: $CURRENT_BRANCH"
    exit 1
fi

# Parse command line options
DESTROY_MODE="all"
SKIP_CONFIRM=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --db-only)
            DESTROY_MODE="db-only"
            shift
            ;;
        --containers-only)
            DESTROY_MODE="containers-only"
            shift
            ;;
        -y|--yes)
            SKIP_CONFIRM=true
            shift
            ;;
        *)
            echo "Unknown option: $1"
            echo "Usage: $0 [--db-only|--containers-only] [-y|--yes]"
            exit 1
            ;;
    esac
done

# Display what will be destroyed
echo "🗑️  Preview Environment Cleanup"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "   Branch:     $CURRENT_BRANCH"
echo "   Clean name: $BRANCH_CLEAN"
echo "   Mode:       $DESTROY_MODE"
echo ""
echo "This will remove:"

if [ "$DESTROY_MODE" = "all" ] || [ "$DESTROY_MODE" = "containers-only" ]; then
    echo "   • All containers (hono-demo-$BRANCH_CLEAN, blog-$BRANCH_CLEAN, etc.)"
    echo "   • Docker images (preview-$BRANCH_CLEAN tags)"
    echo "   • Caddy configurations"
fi

if [ "$DESTROY_MODE" = "all" ] || [ "$DESTROY_MODE" = "db-only" ]; then
    echo "   • All databases (hono_demo_${BRANCH_CLEAN//-/_}, etc.)"
fi

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

if [ "$SKIP_CONFIRM" = false ]; then
    read -p "Continue? (yes/no): " confirm
    if [ "$confirm" != "yes" ]; then
        echo "Aborted."
        exit 0
    fi
fi

# Run Ansible playbook (if it exists)
if [ -f "ansible/playbooks/destroy-preview.yml" ]; then
    ansible-playbook -i ansible/inventory.yml \
      ansible/playbooks/destroy-preview.yml \
      -e branch_name=$BRANCH_CLEAN \
      -e destroy_mode=$DESTROY_MODE \
      -l preview
else
    echo "⚠️  Playbook destroy-preview.yml not found yet"
    echo "💡 Manual cleanup instructions:"
    echo ""

    if [ "$DESTROY_MODE" = "all" ] || [ "$DESTROY_MODE" = "db-only" ]; then
        echo "📊 Databases to delete:"
        SERVICES=("hono-demo" "blog" "storefront" "proxy")
        for service in "${SERVICES[@]}"; do
            db_name=$(get_database_name "$service")
            echo "   docker exec postgres psql -U postgres -c \"DROP DATABASE IF EXISTS $db_name;\""
        done
        echo ""
    fi

    if [ "$DESTROY_MODE" = "all" ] || [ "$DESTROY_MODE" = "containers-only" ]; then
        echo "🐳 Containers to stop:"
        echo "   ssh preview \"cd /srv/studio && docker compose -f js-apps/*/docker-compose.yml ps --filter name=*-$BRANCH_CLEAN down\""
        echo ""
    fi
fi

echo ""
echo "✅ Preview environment cleanup completed: $BRANCH_CLEAN"
echo ""
echo "💡 Usage examples:"
echo "   mise run preview-destroy              # Destroy everything (with confirmation)"
echo "   mise run preview-destroy --db-only    # Only delete databases"
echo "   mise run preview-destroy -y           # Skip confirmation"
