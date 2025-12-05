#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../scripts/build-lib.sh"

# 检测环境（必须在开头调用）
detect_environment

SERVICE_NAME="caddy"
VERSION="$(get_version)"

echo "🔨 Building $SERVICE_NAME (version: $VERSION)"

rm -rf "$SCRIPT_DIR/$DEPLOY_DIST"
mkdir -p "$SCRIPT_DIR/$DEPLOY_DIST"

# 复制所有必要文件
cp "$SCRIPT_DIR/docker-compose.prod.yml" "$SCRIPT_DIR/$DEPLOY_DIST/docker-compose.yml"
cp -r "$SCRIPT_DIR/src/config" "$SCRIPT_DIR/$DEPLOY_DIST/"
cp "$SCRIPT_DIR/src/reload.sh" "$SCRIPT_DIR/src/restart.sh" "$SCRIPT_DIR/$DEPLOY_DIST/"

# Preview 环境：清空 production 目录（避免为生产域名申请证书）
# Preview 的应用域名配置由 deploy-app.yml 自动生成到 preview/ 目录
if [ "$DEPLOY_ENV" = "preview" ]; then
  echo "🔧 Preview environment: clearing production configs"
  rm -f "$SCRIPT_DIR/$DEPLOY_DIST/config/production/"*.caddy
fi

# 获取环境变量（如果有）
if [ -f "$SCRIPT_DIR/.env.example" ]; then
  echo "🔐 Fetching environment variables from AWS Parameter Store..."
  psenv -t "$SCRIPT_DIR/.env.example" -p "$AWS_PARAM_PATH" -o "$SCRIPT_DIR/$DEPLOY_DIST/.env"
fi

# 写入版本号
echo "$VERSION" > "$SCRIPT_DIR/$DEPLOY_DIST/version.txt"

echo "✅ $SERVICE_NAME built: $SCRIPT_DIR/$DEPLOY_DIST"
ls -lh "$SCRIPT_DIR/$DEPLOY_DIST"
