#!/bin/bash
# =====================================
# Caddy 部署脚本
# 从 AWS Parameter Store 获取环境变量并处理模板
# =====================================

set -e

SERVICE_NAME="caddy"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AWS_REGION="${AWS_REGION:-us-west-2}"
PARAM_PATH="/caddy/prod/.env"

# 日志函数
log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $1"
}

# 检查并安装 AWS CLI
check_aws_cli() {
    if ! command -v aws &> /dev/null; then
        log "AWS CLI 未安装，正在安装..."
        if command -v curl &> /dev/null; then
            curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
            if command -v unzip &> /dev/null; then
                unzip awscliv2.zip
                sudo ./aws/install
                rm -rf awscliv2.zip aws/
            else
                log "错误: 需要 unzip 命令来安装 AWS CLI"
                exit 1
            fi
        else
            log "错误: 需要 curl 命令来下载 AWS CLI"
            exit 1
        fi
    fi
}

# 从 AWS Parameter Store 加载环境变量
load_env() {
    log "从 AWS Parameter Store 加载环境变量: $PARAM_PATH"

    # 检查 AWS CLI
    check_aws_cli

    # 检查 AWS 凭证
    if ! aws sts get-caller-identity --region "$AWS_REGION" &> /dev/null; then
        log "错误: AWS 凭证未配置或无效"
        log "请确保已配置 AWS 凭证 (AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY)"
        exit 1
    fi

    aws ssm get-parameter --name "$PARAM_PATH" --with-decryption --region "$AWS_REGION" \
        --query 'Parameter.Value' --output text > .env

    if [ ! -s .env ]; then
        log "错误: 无法从 Parameter Store 加载环境变量"
        exit 1
    fi
    log "环境变量加载完成"
}

# 处理 Caddyfile 模板
process_template() {
    log "处理 Caddyfile 模板..."

    # 加载环境变量
    if [[ -f ".env" ]]; then
        set -a  # 自动导出所有变量
        source .env
        set +a
    fi

    # 检查模板文件
    if [[ ! -f "Caddyfile.prod.template" ]]; then
        log "错误: 未找到 Caddyfile.prod.template"
        exit 1
    fi

    # 处理模板 - 使用 envsubst 或简单替换
    if command -v envsubst &> /dev/null; then
        envsubst < Caddyfile.prod.template > Caddyfile
    else
        # 简单的 shell 替换
        local content=$(cat Caddyfile.prod.template)
        content=${content//\$\{ADMIN_EMAIL\}/${ADMIN_EMAIL}}
        content=${content//\$\{TEST_DEMO_DOMAIN\}/${TEST_DEMO_DOMAIN}}
        echo "$content" > Caddyfile
    fi

    log "Caddyfile 生成完成"
}

# 创建必要目录
setup_directories() {
    log "创建必要目录..."
    mkdir -p /data/caddy/{data,config,logs}
    chmod 755 /data/caddy/{data,config,logs}
}

# 部署服务
deploy_service() {
    log "部署 Caddy 服务..."

    # 确保共享网络存在
    if ! docker network ls | grep -q "shared_network"; then
        log "创建共享网络..."
        docker network create shared_network
    fi

    # 停止旧服务
    docker compose -f docker-compose.prod.yml down || true

    # 启动服务
    log "启动 Caddy..."
    docker compose -f docker-compose.prod.yml up -d

    # 等待服务就绪
    log "等待 Caddy 启动..."
    sleep 5

    # 检查服务状态
    if docker compose -f docker-compose.prod.yml ps | grep -q "Up"; then
        log "✅ Caddy 部署成功！"
        echo ""
        echo "🌐 访问地址:"
        echo "  • https://${TEST_DEMO_DOMAIN:-app.example.com}"
        echo ""
        echo "🛠️  管理命令:"
        echo "  • 重启: docker compose -f docker-compose.prod.yml restart"
        echo "  • 日志: docker compose -f docker-compose.prod.yml logs -f"
        echo "  • 重载: docker compose -f docker-compose.prod.yml exec caddy caddy reload"
    else
        log "❌ Caddy 启动失败"
        docker compose -f docker-compose.prod.yml logs
        exit 1
    fi
}

main() {
    local action="${1:-deploy}"

    cd "$SCRIPT_DIR"

    case "$action" in
        "setup")
            log "设置 Caddy 环境"
            load_env
            setup_directories
            log "环境设置完成"
            ;;
        "template")
            log "处理模板文件"
            # 确保有环境变量
            if [[ ! -f ".env" ]]; then
                load_env
            fi
            process_template
            log "模板处理完成"
            ;;
        "deploy")
            log "开始完整部署流程"
            # 确保有环境变量
            if [[ ! -f ".env" ]]; then
                load_env
            fi
            process_template
            setup_directories
            deploy_service
            ;;
        *)
            echo "Caddy 部署管理"
            echo "用法: $0 setup|template|deploy"
            ;;
    esac
}

main "$@"