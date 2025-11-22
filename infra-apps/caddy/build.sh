#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../scripts/build-lib.sh"

SERVICE_NAME="caddy"
VERSION="$(get_version)"

echo "🔨 Building $SERVICE_NAME (version: $VERSION)"

rm -rf "$SCRIPT_DIR/$DEPLOY_DIST"
mkdir -p "$SCRIPT_DIR/$DEPLOY_DIST"

# 复制所有必要文件
cp "$SCRIPT_DIR/docker-compose.prod.yml" "$SCRIPT_DIR/$DEPLOY_DIST/docker-compose.yml"
cp -r "$SCRIPT_DIR/src/config" "$SCRIPT_DIR/$DEPLOY_DIST/"
cp "$SCRIPT_DIR/src/reload.sh" "$SCRIPT_DIR/src/restart.sh" "$SCRIPT_DIR/$DEPLOY_DIST/"

# 获取环境变量（如果有）
if [ -f "$SCRIPT_DIR/.env.example" ]; then
  echo "🔐 Fetching environment variables from AWS Parameter Store..."
  psenv -t "$SCRIPT_DIR/.env.example" -p "/studio-prod/" -o "$SCRIPT_DIR/$DEPLOY_DIST/.env"
fi

# 写入版本号
echo "$VERSION" > "$SCRIPT_DIR/$DEPLOY_DIST/version.txt"

echo "✅ $SERVICE_NAME built: $SCRIPT_DIR/$DEPLOY_DIST"
ls -lh "$SCRIPT_DIR/$DEPLOY_DIST"
