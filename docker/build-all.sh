#!/bin/bash

# Studio 项目批量构建脚本
# 使用方法: ./build-all.sh [tag_prefix]

set -e

# 默认配置
DEFAULT_TAG_PREFIX="studio"
DOCKERFILE_PATH="docker/bun/Dockerfile"

# 获取参数
TAG_PREFIX=${1:-$DEFAULT_TAG_PREFIX}

echo "🚀 Studio 项目批量构建脚本"
echo "================================"
echo "标签前缀: $TAG_PREFIX"
echo "Dockerfile: $DOCKERFILE_PATH"
echo "================================"

# 检查 Dockerfile 是否存在
if [ ! -f "$DOCKERFILE_PATH" ]; then
    echo "❌ 错误: Dockerfile 不存在: $DOCKERFILE_PATH"
    exit 1
fi

# 获取所有应用
APPS=()
for app_dir in apps/*/; do
    if [ -d "$app_dir" ] && [ -f "$app_dir/package.json" ]; then
        app_name=$(basename "$app_dir")
        # 排除隐藏文件和系统文件
        if [[ ! "$app_name" =~ ^\. ]]; then
            APPS+=("$app_name")
        fi
    fi
done

if [ ${#APPS[@]} -eq 0 ]; then
    echo "❌ 错误: 没有找到可用的应用"
    exit 1
fi

echo "📦 发现的应用: ${APPS[*]}"
echo "================================"

# 构建所有应用
for app in "${APPS[@]}"; do
    echo "🔨 构建应用: $app"
    docker build \
        --target app \
        --build-arg APP="$app" \
        -t "${TAG_PREFIX}-${app}" \
        -f "$DOCKERFILE_PATH" \
        .
    echo "✅ $app 构建完成"
    echo "---"
done

echo "🎉 所有应用构建完成!"
echo "================================"
echo "构建的镜像:"
for app in "${APPS[@]}"; do
    echo "  - ${TAG_PREFIX}-${app}"
done
echo ""
echo "运行示例:"
for app in "${APPS[@]}"; do
    echo "  docker run -p 3000:3000 ${TAG_PREFIX}-${app}"
done
echo "================================"
