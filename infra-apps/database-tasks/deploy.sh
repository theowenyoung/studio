#!/bin/bash
# =====================================
# Database Tasks 部署脚本
# 从 AWS Parameter Store 获取环境变量
# =====================================

set -e

SERVICE_NAME="database-tasks"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AWS_REGION="${AWS_REGION:-us-west-2}"
PARAM_PATH="/database-tasks/prod/.env"

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

main() {
    local action="${1:-list}"
    local task_file="${2:-}"

    cd "$SCRIPT_DIR"

    case "$action" in
        "setup")
            log "设置 Database Tasks 环境"
            load_env
            log "环境设置完成"
            ;;
        "run")
            if [[ -z "$task_file" ]]; then
                echo "❌ 请指定任务文件: $0 run <task_file>"
                exit 1
            fi
            # 确保有环境变量
            if [[ ! -f ".env" ]]; then
                load_env
            fi
            run_task "$task_file"
            ;;
        "list")
            list_tasks
            ;;
        *)
            echo "Database Tasks 管理"
            echo "用法: $0 setup|list|run <task_file>"
            ;;
    esac
}

run_task() {
    local task_file="$1"

    if [[ ! -f "tasks/$task_file" ]]; then
        echo "❌ 任务文件不存在: tasks/$task_file"
        list_tasks
        exit 1
    fi

    echo "🚀 执行数据库任务: $task_file"

    # 加载环境变量
    if [[ -f ".env" ]]; then
        echo "📂 加载环境变量..."
        set -a  # 自动导出所有变量
        source .env
        set +a
    fi
    
    # 确保目录存在
    mkdir -p logs
    
    # 检查共享网络和 postgres 服务
    if ! docker ps | grep -q "postgres.*Up"; then
        echo "❌ PostgreSQL 服务未运行，请先启动"
        exit 1
    fi
    
    # 直接使用一次性容器执行任务，避免复杂的容器管理
    echo "📝 执行数据库任务..."

    # 读取 SQL 文件并替换变量
    local sql_content=$(cat "tasks/$task_file")

    # 简单的变量替换
    sql_content=${sql_content//\$TEST_DEMO_POSTGRES_PASSWORD/${TEST_DEMO_POSTGRES_PASSWORD}}
    sql_content=${sql_content//\$POSTGRES_PASSWORD/${POSTGRES_PASSWORD}}

    # 使用一次性容器执行 SQL
    if echo "$sql_content" | docker run --rm -i --network shared_network \
        -e PGPASSWORD="$POSTGRES_PASSWORD" \
        postgres:17-alpine psql -h postgres -U postgres --echo-all --set ON_ERROR_STOP=1; then
        echo "✅ 任务执行成功"
    else
        echo "❌ 任务执行失败"
        exit 1
    fi
    
    # 清理
    docker compose --profile task down
}

list_tasks() {
    echo "📋 可用的数据库任务:"
    if [[ -n "$(ls tasks/*.sql 2>/dev/null)" ]]; then
        local i=1
        for task in tasks/*.sql; do
            local filename=$(basename "$task")
            local description=$(head -n 3 "$task" | grep -E "^--" | head -n 1 | sed 's/^-- *//')
            printf "%2d. %-30s" "$i" "$filename"
            [[ -n "$description" ]] && printf " - %s" "$description"
            printf "\n"
            ((i++))
        done
        echo ""
        echo "执行: $0 run <task_file>"
    else
        echo "未找到任务文件，请在 tasks/ 目录创建 .sql 文件"
    fi
}

main "$@"