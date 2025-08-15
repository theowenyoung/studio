#!/bin/bash

# Studio 项目一键构建脚本
# 使用方法: ./build.sh [app_name] [tag_prefix]

set -e

# 默认配置
DEFAULT_APP="bun-hello"
DEFAULT_TAG_PREFIX="studio"
DOCKERFILE_PATH="docker/bun/Dockerfile"

# 获取参数
APP_NAME=${1:-$DEFAULT_APP}
TAG_PREFIX=${2:-$DEFAULT_TAG_PREFIX}

echo "🚀 Studio 项目构建脚本"
echo "================================"
echo "应用名称: $APP_NAME"
echo "标签前缀: $TAG_PREFIX"
echo "Dockerfile: $DOCKERFILE_PATH"
echo "================================"

# 检查 Dockerfile 是否存在
if [ ! -f "$DOCKERFILE_PATH" ]; then
    echo "❌ 错误: Dockerfile 不存在: $DOCKERFILE_PATH"
    exit 1
fi

# 检查应用目录是否存在
if [ ! -d "apps/$APP_NAME" ]; then
    echo "❌ 错误: 应用目录不存在: apps/$APP_NAME"
    echo "可用的应用:"
    ls -1 apps/ | grep -v "^\.DS_Store$" | grep -v "^\.gitkeep$" || echo "  无可用应用"
    exit 1
fi

# 构建镜像
echo "🔨 开始构建镜像..."
docker build \
    --target app \
    --build-arg APP="$APP_NAME" \
    -t "${TAG_PREFIX}-${APP_NAME}" \
    -f "$DOCKERFILE_PATH" \
    .

echo "✅ 构建完成!"
echo "================================"
echo "镜像标签: ${TAG_PREFIX}-${APP_NAME}"
echo "运行命令: docker run -p 3000:3000 ${TAG_PREFIX}-${APP_NAME}"
echo "================================"
