#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../scripts/build-lib.sh"

SERVICE_NAME="storefront"
VERSION="$(get_version)"

echo "🔨 Building SSG: $SERVICE_NAME (version: $VERSION)"

# ===== 1. 生成构建时环境变量 =====
echo "🔐 Fetching build-time environment variables from AWS Parameter Store..."
psenv -t "$SCRIPT_DIR/.env.example" -p "/studio-prod/" -o "$SCRIPT_DIR/.env.production"

# ===== 2. 本地构建静态文件 =====
cd "$SCRIPT_DIR"
echo "🔧 Building static files..."

# 加载 .env.production 并构建
set -a
source .env.production
set +a

pnpm build

# ===== 3. 准备部署目录 =====
rm -rf "$SCRIPT_DIR/$DEPLOY_DIST"
mkdir -p "$SCRIPT_DIR/$DEPLOY_DIST"

# 复制构建产物
cp -r "$SCRIPT_DIR/dist/." "$SCRIPT_DIR/$DEPLOY_DIST/"

# ===== 4. 写入部署元信息 =====
echo "$VERSION" >"$SCRIPT_DIR/$DEPLOY_DIST/version.txt"

cat >"$SCRIPT_DIR/$DEPLOY_DIST/.deploy-meta" <<EOF
SERVICE_NAME=$SERVICE_NAME
SERVICE_TYPE=ssg
VERSION=$VERSION
BUILD_TIME=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
BUILT_BY=$(whoami)
GIT_COMMIT=$(git rev-parse HEAD)
EOF

# ===== 5. 清理构建时环境变量 =====
rm -f "$SCRIPT_DIR/.env.production"

echo "✅ $SERVICE_NAME built: $SCRIPT_DIR/$DEPLOY_DIST"
du -sh "$SCRIPT_DIR/$DEPLOY_DIST"
