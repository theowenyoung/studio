#!/bin/bash
# =====================================
# Redis 简化部署脚本
# 本地和远程统一逻辑
# =====================================

set -e

SERVICE_NAME="redis"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

main() {
    echo "🚀 部署 Redis..."
    cd "$SCRIPT_DIR"
    
    # 创建必要目录
    mkdir -p {data,conf,logs}
    
    # 确保共享网络存在
    if ! docker network ls | grep -q "shared_network"; then
        echo "📡 创建共享网络..."
        docker network create shared_network
    fi
    
    # 启动服务
    echo "📦 启动 Redis..."
    docker compose up -d
    
    # 等待服务就绪
    echo "⏳ 等待 Redis 启动..."
    local retries=30
    while ! docker compose exec redis redis-cli --no-auth-warning ping >/dev/null 2>&1; do
        retries=$((retries - 1))
        if [ $retries -eq 0 ]; then
            echo "❌ Redis 启动超时"
            docker compose logs
            exit 1
        fi
        sleep 1
    done
    
    echo "✅ Redis 部署成功！"
    echo ""
    echo "📊 连接信息:"
    echo "  • 容器: docker compose exec redis redis-cli"
    echo "  • 本地: redis-cli -h localhost -p 6379"
    echo ""
    echo "🛠️  管理命令:"
    echo "  • 重启: docker compose restart"
    echo "  • 日志: docker compose logs -f" 
    echo "  • 监控: docker compose exec redis redis-cli monitor"
}

main "$@"