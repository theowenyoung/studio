#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../scripts/build-lib.sh"

SERVICE_NAME="db-admin"
VERSION="$(get_version)"

echo "🔨 Building $SERVICE_NAME (version: $VERSION)"

# ===== 1. 准备部署目录 =====
rm -rf "$SCRIPT_DIR/$DEPLOY_DIST"
mkdir -p "$SCRIPT_DIR/$DEPLOY_DIST"

# ===== 2. 获取运行时环境变量 =====
echo "🔐 Fetching environment variables from AWS Parameter Store..."
psenv -t "$SCRIPT_DIR/.env.example" -p "/studio-prod/" -o "$SCRIPT_DIR/$DEPLOY_DIST/.env"

# ===== 3. 复制必要的文件 =====
cp "$SCRIPT_DIR/docker-compose.yml" "$SCRIPT_DIR/$DEPLOY_DIST/"
cp -r "$SCRIPT_DIR/scripts" "$SCRIPT_DIR/$DEPLOY_DIST/"
cp -r "$SCRIPT_DIR/migrations" "$SCRIPT_DIR/$DEPLOY_DIST/"

# ===== 4. 写入版本号 =====
echo "$VERSION" > "$SCRIPT_DIR/$DEPLOY_DIST/version.txt"

echo "✅ $SERVICE_NAME built: $SCRIPT_DIR/$DEPLOY_DIST"
ls -lh "$SCRIPT_DIR/$DEPLOY_DIST"
