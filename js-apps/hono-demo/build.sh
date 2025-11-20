#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../scripts/build-lib.sh"

SERVICE_NAME="hono-demo"
APP_PATH="js-apps/hono-demo"
PORT="8001"
START_CMD="node dist/server/index.js"
VERSION="$(get_version)"

echo "🔨 Building $SERVICE_NAME (version: $VERSION)"

IMAGE="$ECR_REGISTRY/studio/$SERVICE_NAME"

# ===== 1. 构建并推送镜像 =====
build_and_push_image \
  "$IMAGE" \
  "$VERSION" \
  "docker/nodejs/Dockerfile" \
  --build-arg APP_PATH="$APP_PATH" \
  --build-arg EXPOSE_PORT="$PORT" \
  --build-arg START_CMD="$START_CMD"

# ===== 2. 准备部署目录 =====
rm -rf "$SCRIPT_DIR/$DEPLOY_DIST"
mkdir -p "$SCRIPT_DIR/$DEPLOY_DIST"

# ===== 3. 获取运行时环境变量 =====
fetch_env \
  "$SCRIPT_DIR/.env.example" \
  "/studio-prod/$SERVICE_NAME/" \
  "$SCRIPT_DIR/$DEPLOY_DIST/.env"

# ===== 4. 生成 docker-compose.yml（使用模板 + envsubst） =====
export IMAGE_TAG="$IMAGE:$VERSION"
export SERVICE_PORT="$PORT"

if [ -f "$SCRIPT_DIR/templates/docker-compose.prod.yml" ]; then
  envsubst < "$SCRIPT_DIR/templates/docker-compose.prod.yml" > "$SCRIPT_DIR/$DEPLOY_DIST/docker-compose.yml"
else
  cp "$SCRIPT_DIR/docker-compose.yml" "$SCRIPT_DIR/$DEPLOY_DIST/docker-compose.yml"
fi

# ===== 5. 写入版本号 =====
echo "$VERSION" > "$SCRIPT_DIR/$DEPLOY_DIST/version.txt"

echo "✅ $SERVICE_NAME built: $SCRIPT_DIR/$DEPLOY_DIST"
ls -lh "$SCRIPT_DIR/$DEPLOY_DIST"
