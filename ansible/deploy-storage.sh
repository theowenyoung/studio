#!/bin/bash

# Hetzner 云硬盘部署脚本
set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 默认参数
ENVIRONMENT="production"
TAGS="storage,mount"
VERBOSE=""

# 帮助信息
show_help() {
    echo "用法: $0 [选项]"
    echo ""
    echo "选项:"
    echo "  -e, --environment ENV    指定环境 (production|staging) [默认: production]"
    echo "  -t, --tags TAGS          指定要运行的标签 [默认: storage,mount]"
    echo "  -v, --verbose            详细输出"
    echo "  -h, --help               显示此帮助信息"
    echo ""
    echo "示例:"
    echo "  $0 -e production                    # 部署到生产环境"
    echo "  $0 -e staging -t storage            # 只运行存储标签到测试环境"
    echo "  $0 -v -e production                 # 详细输出部署到生产环境"
}

# 解析命令行参数
while [[ $# -gt 0 ]]; do
    case $1 in
        -e|--environment)
            ENVIRONMENT="$2"
            shift 2
            ;;
        -t|--tags)
            TAGS="$2"
            shift 2
            ;;
        -v|--verbose)
            VERBOSE="-v"
            shift
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        *)
            echo -e "${RED}错误: 未知参数 $1${NC}"
            show_help
            exit 1
            ;;
    esac
done

# 验证环境参数
if [[ "$ENVIRONMENT" != "production" && "$ENVIRONMENT" != "staging" ]]; then
    echo -e "${RED}错误: 环境必须是 'production' 或 'staging'${NC}"
    exit 1
fi

echo -e "${GREEN}开始部署 Hetzner 云硬盘到 $ENVIRONMENT 环境...${NC}"
echo ""

# 检查 Ansible 是否安装
if ! command -v ansible-playbook &> /dev/null; then
    echo -e "${RED}错误: ansible-playbook 未安装${NC}"
    exit 1
fi

# 检查 inventory 文件
if [[ ! -f "inventory.ini" ]]; then
    echo -e "${RED}错误: inventory.ini 文件不存在${NC}"
    exit 1
fi

# 运行 Ansible playbook
echo -e "${YELLOW}运行存储配置 playbook...${NC}"
ansible-playbook \
    -i inventory.ini \
    playbooks/storage.yml \
    --limit "$ENVIRONMENT" \
    --tags "$TAGS" \
    $VERBOSE

if [[ $? -eq 0 ]]; then
    echo ""
    echo -e "${GREEN}✅ Hetzner 云硬盘部署成功！${NC}"
    echo ""
    echo -e "${YELLOW}下一步:${NC}"
    echo "1. 验证挂载: ssh deploy@your-server 'df -h /data'"
    echo "2. 检查目录结构: ssh deploy@your-server 'ls -la /data/'"
    echo "3. 测试写入权限: ssh deploy@your-server 'touch /data/test.txt && rm /data/test.txt'"
else
    echo ""
    echo -e "${RED}❌ 部署失败！请检查错误信息。${NC}"
    exit 1
fi


