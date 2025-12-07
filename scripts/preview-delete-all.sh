#!/bin/bash
set -e

# Delete ALL preview environments at once
# Finds all unique branches from containers/databases/directories and deletes them

usage() {
  echo "Usage: $0 [-y|--yes]"
  echo ""
  echo "Options:"
  echo "  -y, --yes    Skip confirmation"
  exit 1
}

# Parse arguments
SKIP_CONFIRM=false
while [[ $# -gt 0 ]]; do
  case $1 in
    -y|--yes) SKIP_CONFIRM=true; shift ;;
    -h|--help) usage ;;
    -*) echo "Unknown option: $1"; usage ;;
    *) echo "Error: Unexpected argument: $1"; usage ;;
  esac
done

SERVER="preview"
INVENTORY="ansible/inventory.yml"

echo "🗑️  Delete ALL Preview Environments"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "🔍 Finding all preview resources..."

# Find all resources on server
resources=$(ansible $SERVER -i $INVENTORY -m shell -a "
echo '=== CONTAINERS ==='
docker ps -a --format '{{\"{{\"}}.Names{{\"}}\"}}' | grep -E -- '--' || true

echo '=== DATABASES ==='
cd /srv/studio/infra-apps/postgres && docker compose exec -T postgres psql -U postgres -t -A -c \"SELECT datname FROM pg_database WHERE datname LIKE '%\\_\\_%' ESCAPE '\\\\'\" 2>/dev/null || true

echo '=== CADDY_CONFIGS ==='
ls -1 /srv/studio/infra-apps/caddy/config/preview/*.caddy 2>/dev/null | xargs -n1 basename | grep -E -- '--' || true

echo '=== APP_DIRS ==='
ls -1 /srv/studio/js-apps/ 2>/dev/null | grep -E -- '--' || true
" 2>/dev/null | grep -v "^$SERVER |" || true)

# Parse resources
containers=$(echo "$resources" | sed -n '/=== CONTAINERS ===/,/=== DATABASES ===/p' | grep -v "===" | grep -v "^$" || true)
databases=$(echo "$resources" | sed -n '/=== DATABASES ===/,/=== CADDY_CONFIGS ===/p' | grep -v "===" | grep -v "^$" || true)
caddy_configs=$(echo "$resources" | sed -n '/=== CADDY_CONFIGS ===/,/=== APP_DIRS ===/p' | grep -v "===" | grep -v "^$" || true)
app_dirs=$(echo "$resources" | sed -n '/=== APP_DIRS ===/,$p' | grep -v "===" | grep -v "^$" || true)

# Display
echo "📦 Containers:"
[ -n "$containers" ] && echo "$containers" | sed 's/^/   • /' || echo "   (none)"

echo ""
echo "💾 Databases:"
[ -n "$databases" ] && echo "$databases" | sed 's/^/   • /' || echo "   (none)"

echo ""
echo "🌐 Caddy configs:"
[ -n "$caddy_configs" ] && echo "$caddy_configs" | sed 's/^/   • /' || echo "   (none)"

echo ""
echo "📁 App directories:"
[ -n "$app_dirs" ] && echo "$app_dirs" | sed 's/^/   • /' || echo "   (none)"

# Check if anything to delete
if [ -z "$containers" ] && [ -z "$databases" ] && [ -z "$caddy_configs" ] && [ -z "$app_dirs" ]; then
  echo ""
  echo "📭 No preview environments found"
  exit 0
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Confirm
if [ "$SKIP_CONFIRM" = false ]; then
  echo "⚠️  This will DELETE ALL preview environments!"
  read -p "Type 'delete all' to confirm: " confirm
  [ "$confirm" != "delete all" ] && { echo "Aborted."; exit 0; }
fi

echo ""
echo "🗑️  Deleting all preview environments..."

# Execute deletion on server
ansible $SERVER -i $INVENTORY -m shell -a "
# 1. Stop and remove all preview containers (matching --)
echo '>>> Removing all preview containers...'
docker ps -a --format '{{\"{{\"}}.Names{{\"}}\"}}' | grep -E -- '--' | xargs -r docker rm -f || true

# 2. Drop all preview databases (matching __)
echo '>>> Dropping all preview databases...'
cd /srv/studio/infra-apps/postgres
for db in \$(docker compose exec -T postgres psql -U postgres -t -A -c \"SELECT datname FROM pg_database WHERE datname LIKE '%\\_\\_%' ESCAPE '\\\\'\"); do
  echo \"   Dropping: \$db\"
  docker compose exec -T postgres psql -U postgres -c \"DROP DATABASE IF EXISTS \\\"\$db\\\"\" || true
done

# 3. Remove all preview Caddy configs
echo '>>> Removing all preview Caddy configs...'
rm -fv /srv/studio/infra-apps/caddy/config/preview/*--*.caddy || true

# 4. Remove all preview app directories
echo '>>> Removing all preview app directories...'
rm -rfv /srv/studio/js-apps/*--* || true

# 5. Reload Caddy
echo '>>> Reloading Caddy...'
cd /srv/studio/infra-apps/caddy && docker compose exec -T caddy caddy reload --config /etc/caddy/Caddyfile || true

# 6. Prune images
echo '>>> Pruning unused images...'
docker image prune -f || true

echo '>>> Done'
" 2>/dev/null | grep -v "^$SERVER |" || true

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ All preview environments deleted!"
echo ""
echo "💡 Verify with: mise run preview-list"
