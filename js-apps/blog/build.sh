#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../scripts/build-lib.sh"

SERVICE_NAME="blog"
VERSION="$(get_version)"

echo "🔨 Building SSG: $SERVICE_NAME (version: $VERSION)"

# ===== 1. 生成构建时环境变量（如果有）=====
if [ -f "$SCRIPT_DIR/.env.example" ]; then
  echo "🔐 Fetching build-time environment variables from AWS Parameter Store..."
  psenv -t "$SCRIPT_DIR/.env.example" -p "/studio-prod/" -o "$SCRIPT_DIR/.env.production"

  # 加载环境变量
  set -a
  source .env.production
  set +a
else
  echo "⚠️  No .env.example found, skipping environment variable fetch"
fi

# ===== 2. 本地构建静态文件 =====
cd "$SCRIPT_DIR"
echo "🔧 Building static files..."
pnpm build

# ===== 3. 准备部署目录 =====
rm -rf "$SCRIPT_DIR/$DEPLOY_DIST"
mkdir -p "$SCRIPT_DIR/$DEPLOY_DIST"

# 复制构建产物（支持多种框架的输出目录）
if [ -d "$SCRIPT_DIR/build/client" ]; then
  # Remix
  cp -r "$SCRIPT_DIR/build/client/." "$SCRIPT_DIR/$DEPLOY_DIST/"
elif [ -d "$SCRIPT_DIR/out" ]; then
  # Next.js
  cp -r "$SCRIPT_DIR/out/." "$SCRIPT_DIR/$DEPLOY_DIST/"
elif [ -d "$SCRIPT_DIR/dist" ]; then
  # Vite
  cp -r "$SCRIPT_DIR/dist/." "$SCRIPT_DIR/$DEPLOY_DIST/"
else
  echo "❌ Error: No build output found (checked 'build/client', 'out', and 'dist')"
  exit 1
fi

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
