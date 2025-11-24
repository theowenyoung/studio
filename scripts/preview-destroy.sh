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

# Display what will be destroyed
echo "🗑️  Preview Environment Cleanup"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "   Branch:     $CURRENT_BRANCH"
echo "   Clean name: $BRANCH_CLEAN"
echo ""
echo "This will remove:"
echo "   • All containers (hono-demo-$BRANCH_CLEAN, blog-$BRANCH_CLEAN, etc.)"
echo "   • All databases (hono_demo_${BRANCH_CLEAN//-/_}, etc.)"
echo "   • Docker images (preview-$BRANCH_CLEAN tags)"
echo "   • Caddy configurations"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
read -p "Continue? (yes/no): " confirm

if [ "$confirm" != "yes" ]; then
    echo "Aborted."
    exit 0
fi

# Run Ansible playbook
ansible-playbook -i ansible/inventory.yml \
  ansible/playbooks/destroy-preview.yml \
  -e branch_name=$BRANCH_CLEAN \
  -l preview

echo ""
echo "✅ Preview environment destroyed: $BRANCH_CLEAN"
