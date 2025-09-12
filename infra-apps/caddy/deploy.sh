#!/bin/bash
# =====================================
# Caddy 简化部署脚本
# 本地和远程统一逻辑
# =====================================

set -e

SERVICE_NAME="caddy"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

main() {
    echo "🚀 部署 Caddy..."
    cd "$SCRIPT_DIR"
    
    # 创建必要目录
    mkdir -p {data,config,logs,certs}
    
    # 检查配置文件
    if [[ ! -f "Caddyfile.local" ]]; then
        echo "❌ 未找到 Caddyfile.local，请先设置配置文件"
        exit 1
    fi
    
    # 确保共享网络存在
    if ! docker network ls | grep -q "shared_network"; then
        echo "📡 创建共享网络..."
        docker network create shared_network
    fi
    
    # 检查本地证书是否存在
    if [[ ! -d "certs" ]] || [[ -z "$(ls certs/*.pem 2>/dev/null)" ]]; then
        echo "❌ 未找到本地证书，请先运行: ./setup-local-dev.sh"
        exit 1
    fi
    
    # 启动服务
    echo "📦 启动 Caddy..."
    docker compose up -d
    
    # 等待服务就绪
    echo "⏳ 等待 Caddy 启动..."
    sleep 3
    
    if docker compose ps | grep -q "Up"; then
        echo "✅ Caddy 部署成功！"
        echo ""
        echo "🌐 访问地址:"
        echo "  • https://app.local      - 主应用"
        echo "  • https://admin.local    - 管理后台"
        echo "  • https://api.local      - API 服务"
        echo "  • https://db.local       - 数据库管理"
        echo ""
        echo "🛠️  管理命令:"
        echo "  • 重启: docker compose restart"
        echo "  • 日志: docker compose logs -f"
        echo "  • 重载: docker compose exec caddy caddy reload"
    else
        echo "❌ Caddy 启动失败"
        docker compose logs
        exit 1
    fi
}

main "$@"