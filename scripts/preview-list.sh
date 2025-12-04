#!/bin/bash
set -e

# Preview environment listing script
# Uses double separator (-- for DNS, __ for DB) to parse branch names

SERVER="preview"
INVENTORY="ansible/inventory.yml"

echo "🔍 Fetching preview environments..."
echo ""

# Get containers (use -- separator)
containers=$(ansible $SERVER -i $INVENTORY -m shell -a 'docker ps --format "{% raw %}{{.Names}}{% endraw %}" | grep -E -- "--" || true' 2>/dev/null | grep -v "|" | grep -v ">>" | grep -v "^$" || true)

# Get databases (use __ separator)
databases=$(ansible $SERVER -i $INVENTORY -m shell -a 'cd /srv/studio/infra-apps/postgres && docker compose exec -T postgres psql -U postgres -t -A -c "SELECT datname FROM pg_database WHERE datname LIKE '"'"'%___%'"'"'" || true' 2>/dev/null | grep -v "|" | grep -v ">>" | grep -v "^$" || true)

# Get app directories (use -- separator)
app_dirs=$(ansible $SERVER -i $INVENTORY -m shell -a 'ls -1 /srv/studio/js-apps/ 2>/dev/null | grep -E -- "--" || true' 2>/dev/null | grep -v "|" | grep -v ">>" | grep -v "^$" || true)

# Get caddy configs (use -- separator)
caddy_configs=$(ansible $SERVER -i $INVENTORY -m shell -a 'ls -1 /srv/studio/infra-apps/caddy/config/preview/*.caddy 2>/dev/null | xargs -n1 basename | grep -E -- "--" || true' 2>/dev/null | grep -v "|" | grep -v ">>" | grep -v "^$" || true)

# Extract unique branch names
declare -A branches

# From containers: pattern {service}--{branch}-{service}-1
# Split by -- and take the second part, then remove -service-N suffix
while IFS= read -r name; do
  [ -z "$name" ] && continue
  if [[ "$name" == *"--"* ]]; then
    # Extract part after --
    after_sep="${name#*--}"
    # Remove trailing -service-N (everything from the last hyphen-word-number)
    branch=$(echo "$after_sep" | sed 's/-[a-z]*-[0-9]*$//')
    [ -n "$branch" ] && branches["$branch"]=1
  fi
done <<< "$containers"

# From databases: pattern {service}__{branch}
# Split by __ and convert underscore to hyphen
while IFS= read -r db; do
  [ -z "$db" ] && continue
  if [[ "$db" == *"__"* ]]; then
    branch="${db#*__}"
    branch="${branch//_/-}"  # Convert to hyphen format
    [ -n "$branch" ] && branches["$branch"]=1
  fi
done <<< "$databases"

# From app dirs: pattern {service}--{branch}
while IFS= read -r dir; do
  [ -z "$dir" ] && continue
  if [[ "$dir" == *"--"* ]]; then
    branch="${dir#*--}"
    [ -n "$branch" ] && branches["$branch"]=1
  fi
done <<< "$app_dirs"

# From caddy: pattern {service}--{branch}.caddy
while IFS= read -r conf; do
  [ -z "$conf" ] && continue
  name="${conf%.caddy}"
  if [[ "$name" == *"--"* ]]; then
    branch="${name#*--}"
    [ -n "$branch" ] && branches["$branch"]=1
  fi
done <<< "$caddy_configs"

# Display
if [ ${#branches[@]} -eq 0 ]; then
  echo "📭 No preview environments found"
  exit 0
fi

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
printf "%-30s\n" "Branch"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

for branch in "${!branches[@]}"; do
  echo "$branch"
done | sort

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Total: ${#branches[@]} preview environment(s)"
echo ""
echo "💡 To delete: mise run preview-delete <branch>"
