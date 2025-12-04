#!/bin/bash
set -e

# Preview environment deletion script
# Deletes all resources for a specific preview branch:
# - Docker containers
# - Databases
# - Caddy config files
# - App directories

usage() {
  echo "Usage: $0 <branch-name> [-y|--yes]"
  echo ""
  echo "Examples:"
  echo "  $0 feat-test"
  echo "  $0 feat-test -y"
  exit 1
}

# Parse arguments
BRANCH=""
SKIP_CONFIRM=false

while [[ $# -gt 0 ]]; do
  case $1 in
    -y|--yes) SKIP_CONFIRM=true; shift ;;
    -h|--help) usage ;;
    -*) echo "Unknown option: $1"; usage ;;
    *) [ -z "$BRANCH" ] && BRANCH="$1" || { echo "Error: Multiple branch names"; usage; }; shift ;;
  esac
done

[ -z "$BRANCH" ] && { echo "Error: Branch name required"; usage; }

SERVER="preview"
INVENTORY="ansible/inventory.yml"

# Normalize branch name
BRANCH="${BRANCH//_/-}"
BRANCH_UNDERSCORE="${BRANCH//-/_}"

echo "🗑️  Preview Environment Deletion"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "   Branch: $BRANCH"
echo ""
echo "🔍 Finding resources..."

# Find all resources on server
resources=$(ansible $SERVER -i $INVENTORY -m shell -a "
BRANCH='$BRANCH'
BRANCH_UNDERSCORE='$BRANCH_UNDERSCORE'

echo '=== CONTAINERS ==='
docker ps -a --format '{% raw %}{{.Names}}{% endraw %}' | grep -E \"[-]\${BRANCH}[-]\" || true

echo '=== DATABASES ==='
cd /srv/studio/infra-apps/postgres && docker compose exec -T postgres psql -U postgres -t -A -c \"SELECT datname FROM pg_database WHERE datname LIKE '%_\${BRANCH_UNDERSCORE}'\" || true

echo '=== CADDY_CONFIGS ==='
for f in /srv/studio/infra-apps/caddy/config/sites/*\${BRANCH}*.caddy; do [ -f \"\$f\" ] && basename \"\$f\"; done 2>/dev/null || true

echo '=== APP_DIRS ==='
for d in /srv/studio/js-apps/*-\${BRANCH}; do [ -d \"\$d\" ] && basename \"\$d\"; done 2>/dev/null || true
" 2>/dev/null | grep -v "^$SERVER |" || true)

# Parse resources
containers=$(echo "$resources" | sed -n '/=== CONTAINERS ===/,/=== DATABASES ===/p' | grep -v "===" | grep -v "^$" || true)
databases=$(echo "$resources" | sed -n '/=== DATABASES ===/,/=== CADDY_CONFIGS ===/p' | grep -v "===" | grep -v "^$" || true)
caddy_configs=$(echo "$resources" | sed -n '/=== CADDY_CONFIGS ===/,/=== APP_DIRS ===/p' | grep -v "===" | grep -v "^$" || true)
app_dirs=$(echo "$resources" | sed -n '/=== APP_DIRS ===/,$p' | grep -v "===" | grep -v "^$" || true)

# Display
echo ""
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
  echo "📭 No resources found for branch: $BRANCH"
  exit 0
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Confirm
if [ "$SKIP_CONFIRM" = false ]; then
  read -p "⚠️  Delete all these resources? (yes/no): " confirm
  [ "$confirm" != "yes" ] && { echo "Aborted."; exit 0; }
fi

echo ""
echo "🗑️  Deleting..."

# Execute deletion on server
ansible $SERVER -i $INVENTORY -m shell -a "
BRANCH='$BRANCH'
BRANCH_UNDERSCORE='$BRANCH_UNDERSCORE'

# 1. Stop and remove containers
echo '>>> Removing containers...'
docker ps -a --format '{% raw %}{{.Names}}{% endraw %}' | grep -E \"[-]\${BRANCH}[-]\" | xargs -r docker rm -f || true

# 2. Drop databases
echo '>>> Dropping databases...'
cd /srv/studio/infra-apps/postgres
for db in \$(docker compose exec -T postgres psql -U postgres -t -A -c \"SELECT datname FROM pg_database WHERE datname LIKE '%_\${BRANCH_UNDERSCORE}'\"); do
  echo \"   Dropping: \$db\"
  docker compose exec -T postgres psql -U postgres -c \"DROP DATABASE IF EXISTS \\\"\$db\\\"\" || true
done

# 3. Remove Caddy configs
echo '>>> Removing Caddy configs...'
rm -fv /srv/studio/infra-apps/caddy/config/sites/*\${BRANCH}*.caddy || true

# 4. Remove app directories
echo '>>> Removing app directories...'
rm -rfv /srv/studio/js-apps/*-\${BRANCH} || true

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
echo "✅ Preview environment deleted: $BRANCH"
echo ""
echo "💡 Verify with: mise run preview-list"
