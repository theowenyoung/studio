#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../scripts/build-lib.sh"

SERVICE_NAME="caddy"
VERSION="$(get_version)"

echo "🔨 Building $SERVICE_NAME (version: $VERSION)"

rm -rf "$SCRIPT_DIR/$DEPLOY_DIST"
mkdir -p "$SCRIPT_DIR/$DEPLOY_DIST"

# 1. 复制 Caddyfile
cp "$SCRIPT_DIR/src/Caddyfile.prod" "$SCRIPT_DIR/$DEPLOY_DIST/Caddyfile"

# 2. 复制 snippets 和 sites
cp -r "$SCRIPT_DIR/src/snippets" "$SCRIPT_DIR/$DEPLOY_DIST/"
cp -r "$SCRIPT_DIR/src/sites" "$SCRIPT_DIR/$DEPLOY_DIST/"

# 2.5. 复制管理脚本到服务器
cp "$SCRIPT_DIR/src/reload.sh" "$SCRIPT_DIR/$DEPLOY_DIST/reload.sh"
cp "$SCRIPT_DIR/src/restart.sh" "$SCRIPT_DIR/$DEPLOY_DIST/restart.sh"
chmod +x "$SCRIPT_DIR/$DEPLOY_DIST/reload.sh"
chmod +x "$SCRIPT_DIR/$DEPLOY_DIST/restart.sh"

# 3. 复制 docker-compose 配置
if [ -f "$SCRIPT_DIR/docker-compose.prod.yml" ]; then
  cp "$SCRIPT_DIR/docker-compose.prod.yml" "$SCRIPT_DIR/$DEPLOY_DIST/docker-compose.yml"
else
  cp "$SCRIPT_DIR/docker-compose.yml" "$SCRIPT_DIR/$DEPLOY_DIST/docker-compose.yml"
fi

# 4. 获取环境变量（如果有）
if [ -f "$SCRIPT_DIR/.env.example" ]; then
  echo "🔐 Fetching environment variables from AWS Parameter Store..."
  psenv -t "$SCRIPT_DIR/.env.example" -p "/studio-prod/" -o "$SCRIPT_DIR/$DEPLOY_DIST/.env"
fi

# 5. 写入版本号
echo "$VERSION" > "$SCRIPT_DIR/$DEPLOY_DIST/version.txt"

echo "✅ $SERVICE_NAME built: $SCRIPT_DIR/$DEPLOY_DIST"
ls -lh "$SCRIPT_DIR/$DEPLOY_DIST"
