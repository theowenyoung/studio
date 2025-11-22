#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../scripts/build-lib.sh"

SERVICE_NAME="backup"
VERSION="$(get_version)"

echo "🔨 Building $SERVICE_NAME (version: $VERSION)"

IMAGE="$ECR_REGISTRY/studio/$SERVICE_NAME"

# ===== 1. 构建并推送镜像 =====
build_and_push_image \
  "$IMAGE" \
  "$VERSION" \
  "infra-apps/backup/Dockerfile"

# ===== 2. 准备部署目录 =====
rm -rf "$SCRIPT_DIR/$DEPLOY_DIST"
mkdir -p "$SCRIPT_DIR/$DEPLOY_DIST"

# ===== 3. 获取运行时环境变量 =====
if psenv -t "$SCRIPT_DIR/.env.example" -p "/studio-prod/" -o "$SCRIPT_DIR/$DEPLOY_DIST/.env" 2>/dev/null; then
  echo "✅ Fetched environment variables from AWS Parameter Store"
else
  echo "⚠️  Failed to fetch from Parameter Store, using local .env file"
  if [ -f "$SCRIPT_DIR/.env" ]; then
    cp "$SCRIPT_DIR/.env" "$SCRIPT_DIR/$DEPLOY_DIST/.env"
  else
    echo "❌ Error: No .env file found and Parameter Store fetch failed"
    exit 1
  fi
fi

# ===== 4. 生成 docker-compose.yml =====
export IMAGE_TAG="$IMAGE:$VERSION"

# 使用生产配置
cp "$SCRIPT_DIR/docker-compose.prod.yml" "$SCRIPT_DIR/$DEPLOY_DIST/docker-compose.yml"

# 替换镜像标签
sed -i.bak "s|image: backup:latest|image: $IMAGE_TAG|g" "$SCRIPT_DIR/$DEPLOY_DIST/docker-compose.yml"
rm "$SCRIPT_DIR/$DEPLOY_DIST/docker-compose.yml.bak"

# ===== 5. 写入版本号 =====
echo "$VERSION" >"$SCRIPT_DIR/$DEPLOY_DIST/version.txt"

echo "✅ $SERVICE_NAME built: $SCRIPT_DIR/$DEPLOY_DIST"
ls -lh "$SCRIPT_DIR/$DEPLOY_DIST"
