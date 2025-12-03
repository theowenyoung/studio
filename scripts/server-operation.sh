#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/build-lib.sh"

# Parse arguments
OPERATION="${1:-}"
PLAYBOOK="${2:-}"
EXTRA_VARS="${3:-}"

if [ -z "$OPERATION" ] || [ -z "$PLAYBOOK" ]; then
    echo "❌ Error: Missing arguments"
    echo "Usage: $0 <operation-name> <playbook-name> [extra-vars]"
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

# Build ansible command
ANSIBLE_CMD="ansible-playbook -i ansible/inventory.yml ansible/playbooks/$PLAYBOOK -l $ANSIBLE_TARGET"

if [ -n "$EXTRA_VARS" ]; then
    ANSIBLE_CMD="$ANSIBLE_CMD -e $EXTRA_VARS"
fi

# Run ansible playbook
$ANSIBLE_CMD

echo ""
echo "✅ Operation completed: $OPERATION"
