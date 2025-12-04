#!/bin/bash
set -e

SERVER="preview"
INVENTORY="ansible/inventory.yml"

echo "🔍 Fetching preview environments..."
echo ""

# Get containers
containers=$(ansible $SERVER -i $INVENTORY -m shell -a 'docker ps --format "{% raw %}{{.Names}}{% endraw %}" | grep -v -E "^(postgres|redis|caddy)-" || true' 2>/dev/null | grep -v "|" | grep -v ">>" | grep -v "^$" || true)

# Get databases
databases=$(ansible $SERVER -i $INVENTORY -m shell -a 'cd /srv/studio/infra-apps/postgres && docker compose exec -T postgres psql -U postgres -t -A -c "SELECT datname FROM pg_database WHERE datname NOT IN ('"'"'postgres'"'"','"'"'template0'"'"','"'"'template1'"'"')" || true' 2>/dev/null | grep -v "|" | grep -v ">>" | grep -v "^$" || true)

# Get app directories
app_dirs=$(ansible $SERVER -i $INVENTORY -m shell -a 'ls -1 /srv/studio/js-apps/ 2>/dev/null || true' 2>/dev/null | grep -v "|" | grep -v ">>" | grep -v "^$" || true)

# Get caddy configs
caddy_configs=$(ansible $SERVER -i $INVENTORY -m shell -a 'ls -1 /srv/studio/infra-apps/caddy/config/sites/*.caddy 2>/dev/null | xargs -n1 basename || true' 2>/dev/null | grep -v "|" | grep -v ">>" | grep -v "^$" || true)

# Extract branches
declare -A branches

# From containers: pattern {service}-{branch}-{service}-1
# e.g., hono-demo-feat-test-hono-demo-1 -> feat-test
while IFS= read -r name; do
  [ -z "$name" ] && continue
  name="${name%-[0-9]*}"  # Remove -1
  # Split by - and find where pattern repeats
  # hono-demo-feat-test-hono-demo -> service=hono-demo, branch=feat-test
  # Find the middle part between two identical service names
  IFS='-' read -ra parts <<< "$name"
  len=${#parts[@]}
  for ((i=1; i<len-1; i++)); do
    # Check if parts[0..i-1] == parts[i+k..end] for some k
    prefix="${parts[*]:0:$i}"
    prefix="${prefix// /-}"
    for ((j=i+1; j<len; j++)); do
      suffix="${parts[*]:$j}"
      suffix="${suffix// /-}"
      if [ "$prefix" = "$suffix" ]; then
        # Branch is parts[i..j-1]
        branch="${parts[*]:$i:$((j-i))}"
        branch="${branch// /-}"
        [ -n "$branch" ] && branches["$branch"]=1
        break 2
      fi
    done
  done
done <<< "$containers"

# From databases: pattern service_branch (2+ underscores = preview)
# e.g., hono_demo_feat_test -> feat-test
while IFS= read -r db; do
  [ -z "$db" ] && continue
  us="${db//[^_]}"
  if [ ${#us} -ge 2 ]; then
    # Remove service prefix (first two segments for compound names like hono_demo)
    branch=$(echo "$db" | sed 's/^[a-z]*_[a-z]*_//' | tr '_' '-')
    [ -n "$branch" ] && branches["$branch"]=1
  fi
done <<< "$databases"

# From app dirs: pattern service-branch
# e.g., hono-demo-feat-test -> feat-test
while IFS= read -r dir; do
  [ -z "$dir" ] && continue
  hs="${dir//[^-]}"
  if [ ${#hs} -ge 2 ]; then
    # Remove service prefix (first two segments for compound names like hono-demo)
    branch=$(echo "$dir" | sed 's/^[a-z]*-[a-z]*-//')
    [ -n "$branch" ] && branches["$branch"]=1
  fi
done <<< "$app_dirs"

# From caddy: pattern branch-service-preview.caddy
# e.g., feat-test-hono-demo-preview.caddy -> feat-test
while IFS= read -r conf; do
  [ -z "$conf" ] && continue
  name="${conf%.caddy}"
  if [[ "$name" =~ -preview$ ]]; then
    branch=$(echo "$name" | sed 's/-[a-z]*-preview$//')
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
