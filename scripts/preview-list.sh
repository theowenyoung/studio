#!/bin/bash
set -e

# Preview environment listing script
# Uses double separator (-- for DNS, __ for DB) to parse branch names
# Displays projects grouped by branch

SERVER="preview"
INVENTORY="ansible/inventory.yml"

echo "🔍 Fetching preview environments..."
echo ""

# Get containers (use -- separator)
containers=$(ansible $SERVER -i $INVENTORY -m shell -a 'docker ps --format "{{"{{"}}.Names{{"}}"}}" | grep -E -- "--" || true' 2>/dev/null | grep -v "|" | grep -v ">>" | grep -v "^$" || true)

# Get databases (use __ separator)
databases=$(ansible $SERVER -i $INVENTORY -m shell -a 'cd /srv/studio/infra-apps/postgres && docker compose exec -T postgres psql -U postgres -t -A -c "SELECT datname FROM pg_database WHERE datname LIKE '"'"'%___%'"'"'" || true' 2>/dev/null | grep -v "|" | grep -v ">>" | grep -v "^$" || true)

# Get app directories (use -- separator)
app_dirs=$(ansible $SERVER -i $INVENTORY -m shell -a 'ls -1 /srv/studio/js-apps/ 2>/dev/null | grep -E -- "--" || true' 2>/dev/null | grep -v "|" | grep -v ">>" | grep -v "^$" || true)

# Get caddy configs (use -- separator)
caddy_configs=$(ansible $SERVER -i $INVENTORY -m shell -a 'ls -1 /srv/studio/infra-apps/caddy/config/preview/*.caddy 2>/dev/null | xargs -r -n1 basename | grep -E -- "--" || true' 2>/dev/null | grep -v "|" | grep -v ">>" | grep -v "^$" | grep -v "basename:" || true)

# Store branch -> projects mapping
# Format: branch_projects["branch"]="project1 project2 project3"
declare -A branch_projects

# Helper to add project to branch
add_project() {
  local branch="$1"
  local project="$2"
  if [ -z "${branch_projects[$branch]}" ]; then
    branch_projects[$branch]="$project"
  elif [[ " ${branch_projects[$branch]} " != *" $project "* ]]; then
    branch_projects[$branch]="${branch_projects[$branch]} $project"
  fi
}

# From containers: pattern {service}--{branch}-{service}-1
while IFS= read -r name; do
  [ -z "$name" ] && continue
  if [[ "$name" == *"--"* ]]; then
    project="${name%%--*}"
    after_sep="${name#*--}"
    branch=$(echo "$after_sep" | sed 's/-[a-z]*-[0-9]*$//')
    [ -n "$branch" ] && [ -n "$project" ] && add_project "$branch" "$project"
  fi
done <<< "$containers"

# From databases: pattern {service}__{branch}
while IFS= read -r db; do
  [ -z "$db" ] && continue
  if [[ "$db" == *"__"* ]]; then
    project="${db%%__*}"
    project="${project//_/-}"  # Convert to hyphen format
    branch="${db#*__}"
    branch="${branch//_/-}"  # Convert to hyphen format
    [ -n "$branch" ] && [ -n "$project" ] && add_project "$branch" "$project"
  fi
done <<< "$databases"

# From app dirs: pattern {service}--{branch}
while IFS= read -r dir; do
  [ -z "$dir" ] && continue
  if [[ "$dir" == *"--"* ]]; then
    project="${dir%%--*}"
    branch="${dir#*--}"
    [ -n "$branch" ] && [ -n "$project" ] && add_project "$branch" "$project"
  fi
done <<< "$app_dirs"

# From caddy: pattern {service}--{branch}.caddy
while IFS= read -r conf; do
  [ -z "$conf" ] && continue
  name="${conf%.caddy}"
  if [[ "$name" == *"--"* ]]; then
    project="${name%%--*}"
    branch="${name#*--}"
    [ -n "$branch" ] && [ -n "$project" ] && add_project "$branch" "$project"
  fi
done <<< "$caddy_configs"

# Display
if [ ${#branch_projects[@]} -eq 0 ]; then
  echo "📭 No preview environments found"
  exit 0
fi

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Preview Environments"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Sort branches and display with projects
for branch in $(printf '%s\n' "${!branch_projects[@]}" | sort); do
  echo ""
  echo "📦 $branch"
  # Sort and display projects
  for project in $(echo "${branch_projects[$branch]}" | tr ' ' '\n' | sort); do
    echo "   └─ $project"
  done
done

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Total: ${#branch_projects[@]} preview environment(s)"
echo ""
echo "💡 To delete: mise run preview-delete <branch>"
