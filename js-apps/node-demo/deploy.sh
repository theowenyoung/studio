#!/bin/bash
# =====================================
# Node Demo 部署脚本
# =====================================

set -e

# 配置
APP_NAME="node-demo"
ECR_REGISTRY="912951144733.dkr.ecr.us-west-2.amazonaws.com"
AWS_REGION="us-west-2"
PARAM_PATH="/node-demo/prod/.env"

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

# Docker 登录 ECR
login_ecr() {
    log "登录到 ECR Registry"
    aws ecr get-login-password --region "$AWS_REGION" | docker login --username AWS --password-stdin "$ECR_REGISTRY"
}

# 构建并推送镜像
build_and_push() {
    log "构建 Docker 镜像: $APP_NAME"
    docker build -t "$APP_NAME:latest" .

    # 标记并推送到 ECR
    IMAGE_URI="$ECR_REGISTRY/$APP_NAME:latest"
    docker tag "$APP_NAME:latest" "$IMAGE_URI"

    log "推送镜像到 ECR: $IMAGE_URI"
    docker push "$IMAGE_URI"

    # 更新 docker-compose 使用 ECR 镜像
    sed -i.bak "s|image: $APP_NAME:latest|image: $IMAGE_URI|g" docker-compose.prod.yml
}

# 启动服务
start_service() {
    log "启动 $APP_NAME 服务"
    docker compose -f docker-compose.prod.yml up -d

    log "等待服务启动..."
    sleep 10
}

# 停止服务
stop_service() {
    log "停止 $APP_NAME 服务"
    docker compose -f docker-compose.prod.yml down || true
}

# 显示日志
show_logs() {
    log "显示服务日志"
    docker compose -f docker-compose.prod.yml logs --tail=50
}

# 健康检查
health_check() {
    log "执行健康检查"
    local retries=10
    local count=0

    while [ $count -lt $retries ]; do
        if curl -f http://localhost:3000/health >/dev/null 2>&1; then
            log "健康检查通过 ✓"
            return 0
        fi

        count=$((count + 1))
        log "健康检查失败，重试 $count/$retries"
        sleep 5
    done

    log "健康检查失败，服务可能未正常启动"
    return 1
}

# 主函数
main() {
    case "${1:-deploy}" in
        "load-env")
            load_env
            ;;
        "build")
            login_ecr
            build_and_push
            ;;
        "up"|"start")
            start_service
            ;;
        "down"|"stop")
            stop_service
            ;;
        "logs")
            show_logs
            ;;
        "health")
            health_check
            ;;
        "deploy")
            log "开始完整部署流程"
            load_env
            login_ecr
            build_and_push
            stop_service
            start_service
            if health_check; then
                log "部署成功 ✓"
            else
                log "部署失败，显示日志:"
                show_logs
                exit 1
            fi
            ;;
        *)
            echo "用法: $0 {deploy|load-env|build|up|down|logs|health}"
            echo "  deploy    - 完整部署流程"
            echo "  load-env  - 从 Parameter Store 加载环境变量"
            echo "  build     - 构建并推送 Docker 镜像"
            echo "  up        - 启动服务"
            echo "  down      - 停止服务"
            echo "  logs      - 显示日志"
            echo "  health    - 健康检查"
            exit 1
            ;;
    esac
}

main "$@"
