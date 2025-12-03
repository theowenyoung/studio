#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/build-lib.sh"

# Parse arguments
OPERATION="${1:-}"
PLAYBOOK="${2:-}"

if [ -z "$OPERATION" ] || [ -z "$PLAYBOOK" ]; then
    echo "❌ Error: Missing arguments"
    echo "Usage: $0 <operation-name> <playbook-name>"
    exit 1
fi

# Detect environment
detect_environment

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🔧 Server Operation: $OPERATION"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "   Environment:  $DEPLOY_ENV"
echo "   Branch:       $CURRENT_BRANCH"
echo "   Target:       $ANSIBLE_TARGET"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Run ansible playbook
ansible-playbook -i ansible/inventory.yml "ansible/playbooks/$PLAYBOOK" -l "$ANSIBLE_TARGET"

echo ""
echo "✅ Operation completed: $OPERATION"
