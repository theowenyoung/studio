#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../scripts/build-lib.sh"

SERVICE_NAME="redis"
VERSION="$(get_version)"

echo "🔨 Building $SERVICE_NAME (version: $VERSION)"

rm -rf "$SCRIPT_DIR/$DEPLOY_DIST"
mkdir -p "$SCRIPT_DIR/$DEPLOY_DIST"

# 1. 获取环境变量
fetch_env \
  "$SCRIPT_DIR/.env.example" \
  "/studio-prod/$SERVICE_NAME/" \
  "$SCRIPT_DIR/$DEPLOY_DIST/.env"

# 2. 复制 docker-compose 配置
if [ -f "$SCRIPT_DIR/docker-compose.prod.yml" ]; then
  cp "$SCRIPT_DIR/docker-compose.prod.yml" "$SCRIPT_DIR/$DEPLOY_DIST/docker-compose.yml"
else
  cp "$SCRIPT_DIR/docker-compose.yml" "$SCRIPT_DIR/$DEPLOY_DIST/docker-compose.yml"
fi

# 3. 复制配置文件（如果有）
if [ -f "$SCRIPT_DIR/redis.conf" ]; then
  cp "$SCRIPT_DIR/redis.conf" "$SCRIPT_DIR/$DEPLOY_DIST/"
fi

# 4. 写入版本号
echo "$VERSION" > "$SCRIPT_DIR/$DEPLOY_DIST/version.txt"

echo "✅ $SERVICE_NAME built: $SCRIPT_DIR/$DEPLOY_DIST"
ls -lh "$SCRIPT_DIR/$DEPLOY_DIST"
