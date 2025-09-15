#!/bin/bash
# =====================================
# Bun Demo 部署脚本
# =====================================

set -e

ENV_MODE=${ENV_MODE:-local}
ACTION=${1:-up}

echo "🚀 Bun Demo 部署脚本"
echo "环境模式: $ENV_MODE"
echo "操作: $ACTION"

case $ENV_MODE in
  local)
    COMPOSE_FILE="docker-compose.yml"
    echo "📍 使用本地开发配置"
    ;;
  aws|prod|production)
    COMPOSE_FILE="docker-compose.prod.yml"
    echo "📍 使用生产环境配置"
    ;;
  *)
    echo "❌ 未知环境模式: $ENV_MODE"
    echo "支持的模式: local, aws, prod, production"
    exit 1
    ;;
esac

# 检查必要文件
if [ ! -f "$COMPOSE_FILE" ]; then
    echo "❌ 找不到配置文件: $COMPOSE_FILE"
    exit 1
fi

if [ ! -f ".env" ]; then
    echo "❌ 找不到环境配置文件: .env"
    echo "请复制 .env.example 为 .env 并配置相应的环境变量"
    exit 1
fi

# 确保共享网络存在
if ! docker network ls | grep -q "shared_network"; then
    echo "📡 创建共享网络..."
    docker network create shared_network
fi

case $ACTION in
  up|start)
    echo "🚀 启动 Bun Demo..."
    docker compose -f "$COMPOSE_FILE" up -d
    echo "✅ 启动完成"
    echo "🌐 本地访问: http://localhost:3000"
    echo "🔍 健康检查: http://localhost:3000/health"
    ;;
  down|stop)
    echo "🛑 停止 Bun Demo..."
    docker compose -f "$COMPOSE_FILE" down
    echo "✅ 停止完成"
    ;;
  restart)
    echo "🔄 重启 Bun Demo..."
    docker compose -f "$COMPOSE_FILE" down
    docker compose -f "$COMPOSE_FILE" up -d
    echo "✅ 重启完成"
    ;;
  logs)
    echo "📜 查看日志..."
    docker compose -f "$COMPOSE_FILE" logs -f
    ;;
  status)
    echo "📊 服务状态:"
    docker compose -f "$COMPOSE_FILE" ps
    ;;
  build)
    echo "🔨 构建镜像..."
    cd ../../.. && mise run builddocker
    echo "✅ 构建完成"
    ;;
  *)
    echo "❌ 未知操作: $ACTION"
    echo "支持的操作: up, down, restart, logs, status, build"
    exit 1
    ;;
esac
