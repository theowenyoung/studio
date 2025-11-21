#!/bin/bash
# 帮助设置 GitHub Secrets 的脚本
# 使用 GitHub CLI (gh) 来配置 secrets

set -e

echo "==================================="
echo "GitHub Secrets 设置助手"
echo "==================================="
echo ""
echo "此脚本将帮助你配置 GitHub Actions 所需的 secrets"
echo "需要先安装 GitHub CLI: brew install gh"
echo ""
echo "注意：本项目使用 AWS Parameter Store 集中管理配置"
echo "只需要设置 CI 用的 AWS 凭证，其他配置从 Parameter Store 读取"
echo ""

# 检查 gh 是否安装
if ! command -v gh &> /dev/null; then
    echo "❌ 错误：未找到 GitHub CLI (gh)"
    echo "请先安装: brew install gh"
    exit 1
fi

# 检查是否已登录
if ! gh auth status &> /dev/null; then
    echo "❌ 错误：未登录 GitHub CLI"
    echo "请先登录: gh auth login"
    exit 1
fi

echo "✅ GitHub CLI 已就绪"
echo ""

# 获取仓库信息
REPO=$(gh repo view --json nameWithOwner -q .nameWithOwner)
echo "当前仓库: $REPO"
echo ""

# 设置 secrets 的函数
set_secret() {
    local name=$1
    local description=$2
    local example=$3

    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "设置: $name"
    echo "说明: $description"
    if [ -n "$example" ]; then
        echo "示例: $example"
    fi
    echo ""

    # 检查是否已存在
    if gh secret list | grep -q "^$name"; then
        read -p "已存在，是否更新? (y/N): " update
        if [[ ! $update =~ ^[Yy]$ ]]; then
            echo "跳过 $name"
            echo ""
            return
        fi
    fi

    # 根据类型读取输入
    if [[ $name == *"KEY"* ]] || [[ $name == "DEPLOY_SSH_KEY" ]]; then
        read -p "文件路径（例如: ~/.ssh/id_rsa）: " filepath
        if [ -f "$filepath" ]; then
            gh secret set "$name" < "$filepath"
            echo "✅ 已设置 $name（从文件）"
        else
            echo "❌ 文件不存在: $filepath"
        fi
    else
        read -p "请输入 $name: " value
        if [ -n "$value" ]; then
            echo "$value" | gh secret set "$name"
            echo "✅ 已设置 $name"
        else
            echo "❌ 值为空，跳过"
        fi
    fi
    echo ""
}

echo "开始配置 GitHub Secrets..."
echo ""

# 只需要配置 AWS CI 凭证
echo "📦 AWS CI 凭证（用于访问 ECR 和 Parameter Store）"
set_secret "CI_AWS_ACCESS_KEY_ID" "CI 用的 AWS 访问密钥 ID" "AKIA..."
set_secret "CI_AWS_SECRET_ACCESS_KEY" "CI 用的 AWS 访问密钥" ""

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✨ 设置完成！"
echo ""
echo "查看已配置的 secrets:"
gh secret list
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📝 接下来需要在 AWS Parameter Store 中配置："
echo ""
echo "1. /studio-prod/DEPLOY_HOST     - 生产服务器地址"
echo "2. /studio-prod/DEPLOY_USER     - 部署用户名（通常是 deploy）"
echo "3. /studio-prod/DEPLOY_SSH_KEY  - SSH 私钥内容（SecureString）"
echo ""
echo "配置方法："
echo "  aws ssm put-parameter --name '/studio-prod/DEPLOY_HOST' --value '1.2.3.4' --type String"
echo "  aws ssm put-parameter --name '/studio-prod/DEPLOY_USER' --value 'deploy' --type String"
echo "  aws ssm put-parameter --name '/studio-prod/DEPLOY_SSH_KEY' --value 'file://~/.ssh/id_rsa' --type SecureString"
echo ""
echo "或使用提供的辅助脚本："
echo "  ./scripts/setup-parameter-store.sh"
echo ""
echo "下一步："
echo "1. 配置 AWS Parameter Store"
echo "2. 推送代码到 main 分支测试自动部署"
echo "3. 或在 GitHub Actions 页面手动触发部署"
echo ""
