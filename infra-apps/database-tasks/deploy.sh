#!/bin/bash
# =====================================
# Database Tasks 简化部署脚本
# 使用 envsubst 处理 SQL 变量
# =====================================

set -e

SERVICE_NAME="database-tasks"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

main() {
    local action="${1:-list}"
    local task_file="${2:-}"
    
    cd "$SCRIPT_DIR"
    
    case "$action" in
        "run")
            if [[ -z "$task_file" ]]; then
                echo "❌ 请指定任务文件: $0 run <task_file>"
                exit 1
            fi
            run_task "$task_file"
            ;;
        "list")
            list_tasks
            ;;
        *)
            echo "Database Tasks 管理"
            echo "用法: $0 list|run <task_file>"
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
    
    # 确保目录存在
    mkdir -p logs
    
    # 检查共享网络和 postgres 服务
    if ! docker ps | grep -q "postgres.*Up"; then
        echo "❌ PostgreSQL 服务未运行，请先启动"
        exit 1
    fi
    
    # 启动任务容器
    docker compose --profile task up -d
    sleep 2
    
    # 使用 envsubst 处理 SQL 文件中的变量，然后执行
    echo "📝 处理 SQL 变量并执行..."
    if docker compose --profile task exec -T db-task-runner \
        bash -c "envsubst < /tasks/$task_file | psql --echo-all --set ON_ERROR_STOP=1"; then
        echo "✅ 任务执行成功"
    else
        echo "❌ 任务执行失败"
        docker compose --profile task logs db-task-runner
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