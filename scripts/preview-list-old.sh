#!/bin/bash
set -e

# Parse command line arguments
AGE_DAYS=${1:-7}

echo "🔍 Listing Preview Databases"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "   Threshold: ${AGE_DAYS} days"
echo "   Server:    prod (5.78.126.18)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Run Ansible playbook
ansible-playbook -i ansible/inventory.yml \
  ansible/playbooks/list-preview-dbs.yml \
  -e age_days=$AGE_DAYS \
  -l prod

echo ""
echo "💡 Tip: To change age threshold, run:"
echo "   mise run preview-list-old 14  # List databases older than 14 days"
echo ""
echo "💡 To clean up old databases:"
echo "   git checkout <branch-name>"
echo "   mise run preview-destroy"
