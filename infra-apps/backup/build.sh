#!/bin/bash
# 构建备份镜像脚本

set -e

cd "$(dirname "$0")"

echo "🔨 Building backup Docker image..."

# 检查是否使用 --no-cache
if [ "$1" = "--no-cache" ]; then
    echo "📦 Building with --no-cache (full rebuild)"
    docker compose build --no-cache backup
else
    echo "📦 Building with cache"
    docker compose build backup
fi

echo ""
echo "✅ Build completed!"
echo ""
echo "Verify the build:"
echo "  docker compose run --rm backup head -15 /entrypoint.sh"
echo ""
echo "Test auto-exit:"
echo "  time docker compose run --rm backup echo 'Test'"
echo ""
