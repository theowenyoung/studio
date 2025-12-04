#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../scripts/build-lib.sh"

# 检测环境（必须在开头调用）
detect_environment

SERVICE_NAME="blog"
set_docker_service_name "$SERVICE_NAME"
APP_PATH="js-apps/blog"
VERSION="$(get_version)"

echo "🔨 Building $SERVICE_NAME (version: $VERSION)"

IMAGE="$ECR_REGISTRY/$SERVICE_NAME"

# ===== 1. 构建并推送镜像 =====
build_and_push_image \
  "$IMAGE" \
  "$VERSION" \
  "docker/nodejs-ssg/Dockerfile" \
  --build-arg APP_NAME="${SERVICE_NAME}"

# ===== 2. 准备部署目录 =====
rm -rf "$SCRIPT_DIR/$DEPLOY_DIST"
mkdir -p "$SCRIPT_DIR/$DEPLOY_DIST"

# ===== 3. 生成 docker-compose.yml（使用模板 + envsubst） =====
export IMAGE_TAG="$IMAGE_TAG_VERSIONED"
# DOCKER_SERVICE_NAME 已由 detect_environment 导出

envsubst < "$SCRIPT_DIR/../../docker/nodejs-ssg/docker-compose.template.yml" > "$SCRIPT_DIR/$DEPLOY_DIST/docker-compose.yml"

# ===== 4. 写入版本号 =====
echo "$VERSION" > "$SCRIPT_DIR/$DEPLOY_DIST/version.txt"

echo "✅ $SERVICE_NAME built: $SCRIPT_DIR/$DEPLOY_DIST"
ls -lh "$SCRIPT_DIR/$DEPLOY_DIST"
