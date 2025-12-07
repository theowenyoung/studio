#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../scripts/build-lib.sh"

# 检测环境（必须在开头调用）
detect_environment

# 支持指定目标服务器（用于 prod 环境区分 prod1/prod2）
TARGET_SERVER="${1:-}"

SERVICE_NAME="caddy"
VERSION="$(get_version)"

echo "🔨 Building $SERVICE_NAME (version: $VERSION)"

rm -rf "$SCRIPT_DIR/$DEPLOY_DIST"
mkdir -p "$SCRIPT_DIR/$DEPLOY_DIST"

# 复制基础文件
cp "$SCRIPT_DIR/docker-compose.prod.yml" "$SCRIPT_DIR/$DEPLOY_DIST/docker-compose.yml"
cp "$SCRIPT_DIR/src/reload.sh" "$SCRIPT_DIR/src/restart.sh" "$SCRIPT_DIR/$DEPLOY_DIST/"

# 复制配置（不包含 production-prod* 目录）
mkdir -p "$SCRIPT_DIR/$DEPLOY_DIST/config"
cp "$SCRIPT_DIR/src/config/Caddyfile" "$SCRIPT_DIR/$DEPLOY_DIST/config/"
cp -r "$SCRIPT_DIR/src/config/snippets" "$SCRIPT_DIR/$DEPLOY_DIST/config/"

# 创建 production 目录并根据环境/目标服务器复制配置
mkdir -p "$SCRIPT_DIR/$DEPLOY_DIST/config/production"

if [ "$DEPLOY_ENV" = "preview" ]; then
  # Preview 环境：清空 production 目录（避免为生产域名申请证书）
  # Preview 的应用域名配置由 deploy-app.yml 自动生成到 preview/ 目录
  echo "🔧 Preview environment: production configs cleared"
elif [ "$DEPLOY_ENV" = "prod" ]; then
  # Prod 环境：根据目标服务器选择配置
  if [ -z "$TARGET_SERVER" ]; then
    TARGET_SERVER="prod1"  # 默认 prod1
  fi

  if [ -d "$SCRIPT_DIR/src/config/production-${TARGET_SERVER}" ]; then
    echo "🔧 Prod environment: using production-${TARGET_SERVER} configs"
    cp "$SCRIPT_DIR/src/config/production-${TARGET_SERVER}/"*.caddy "$SCRIPT_DIR/$DEPLOY_DIST/config/production/" 2>/dev/null || true
  else
    echo "⚠️  Warning: No production-${TARGET_SERVER} directory found"
  fi
fi

# 获取环境变量（如果有）
if [ -f "$SCRIPT_DIR/.env.example" ]; then
  echo "🔐 Fetching environment variables from AWS Parameter Store..."
  psenv -t "$SCRIPT_DIR/.env.example" -p "$AWS_PARAM_PATH" -o "$SCRIPT_DIR/$DEPLOY_DIST/.env"
fi

# 创建 preview 目录（用于动态生成的预览环境配置）
# rsync 会同步此空目录，但 --exclude=config/preview/* 会保留服务器上已有的配置
mkdir -p "$SCRIPT_DIR/$DEPLOY_DIST/config/preview"

# 写入版本号
echo "$VERSION" > "$SCRIPT_DIR/$DEPLOY_DIST/version.txt"

echo "✅ $SERVICE_NAME built: $SCRIPT_DIR/$DEPLOY_DIST"
ls -lh "$SCRIPT_DIR/$DEPLOY_DIST"
