#!/bin/bash
# =====================================
# PostgreSQL 简化部署脚本
# 本地和远程统一逻辑
# =====================================

set -e

SERVICE_NAME="postgres"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

main() {
    echo "🚀 部署 PostgreSQL..."
    cd "$SCRIPT_DIR"
    
    # 创建必要目录
    mkdir -p {data,backups,logs}
    
    # 检查初始化脚本是否存在
    if [[ ! -d "init" ]]; then
        echo "❌ 未找到 init 目录，请确保项目配置完整"
        exit 1
    fi
    
    # 确保共享网络存在
    if ! docker network ls | grep -q "shared_network"; then
        echo "📡 创建共享网络..."
        docker network create shared_network
    fi
    
    # 启动服务
    echo "📦 启动 PostgreSQL..."
    docker compose up -d
    
    # 等待服务就绪
    echo "⏳ 等待数据库启动..."
    local retries=30
    while ! docker compose exec postgres pg_isready -U postgres >/dev/null 2>&1; do
        retries=$((retries - 1))
        if [ $retries -eq 0 ]; then
            echo "❌ 数据库启动超时"
            docker compose logs
            exit 1
        fi
        sleep 1
    done
    
    echo "✅ PostgreSQL 部署成功！"
    echo ""
    echo "📊 连接信息:"
    echo "  • 容器: docker compose exec postgres psql -U postgres"
    echo "  • 本地: psql -h localhost -U postgres -d postgres"
    echo ""
    echo "🛠️  管理命令:"
    echo "  • 重启: docker compose restart"
    echo "  • 日志: docker compose logs -f"
    echo "  • 状态: docker compose ps"
}

main "$@"