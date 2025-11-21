#!/bin/bash
# 帮助设置 AWS Parameter Store 的脚本

set -e

echo "==================================="
echo "AWS Parameter Store 设置助手"
echo "==================================="
echo ""
echo "此脚本将帮助你配置部署所需的 Parameter Store 参数"
echo "需要先配置 AWS CLI: aws configure"
echo ""

# 检查 AWS CLI 是否安装
if ! command -v aws &> /dev/null; then
    echo "❌ 错误：未找到 AWS CLI"
    echo "请先安装: brew install awscli"
    exit 1
fi

# 检查 AWS 凭证
if ! aws sts get-caller-identity &> /dev/null; then
    echo "❌ 错误：AWS 凭证未配置或已过期"
    echo "请先配置: aws configure"
    exit 1
fi

echo "✅ AWS CLI 已就绪"
IDENTITY=$(aws sts get-caller-identity --query "Arn" --output text)
echo "当前身份: $IDENTITY"
echo ""

# 设置参数的函数
set_parameter() {
    local name=$1
    local description=$2
    local type=$3
    local example=$4

    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "设置: $name"
    echo "说明: $description"
    echo "类型: $type"
    if [ -n "$example" ]; then
        echo "示例: $example"
    fi
    echo ""

    # 检查是否已存在
    if aws ssm get-parameter --name "$name" &> /dev/null; then
        CURRENT=$(aws ssm get-parameter --name "$name" --query "Parameter.Value" --output text 2>/dev/null || echo "[加密参数]")
        echo "当前值: ${CURRENT}"
        read -p "是否更新? (y/N): " update
        if [[ ! $update =~ ^[Yy]$ ]]; then
            echo "跳过 $name"
            echo ""
            return
        fi
        OVERWRITE="--overwrite"
    else
        OVERWRITE=""
    fi

    # 根据类型读取输入
    if [[ $name == *"SSH_KEY"* ]]; then
        read -p "SSH 私钥文件路径（例如: ~/.ssh/id_rsa）: " filepath
        filepath="${filepath/#\~/$HOME}"  # 展开 ~ 为 home 目录

        if [ -f "$filepath" ]; then
            aws ssm put-parameter \
                --name "$name" \
                --value "file://${filepath}" \
                --type "$type" \
                $OVERWRITE \
                --description "$description"
            echo "✅ 已设置 $name（从文件）"
        else
            echo "❌ 文件不存在: $filepath"
        fi
    else
        read -p "请输入 $name 的值: " value
        if [ -n "$value" ]; then
            aws ssm put-parameter \
                --name "$name" \
                --value "$value" \
                --type "$type" \
                $OVERWRITE \
                --description "$description"
            echo "✅ 已设置 $name"
        else
            echo "❌ 值为空，跳过"
        fi
    fi
    echo ""
}

echo "开始配置 Parameter Store..."
echo ""

# 生产环境配置
echo "🏭 生产环境配置 (/studio-prod/)"
set_parameter "/studio-prod/DEPLOY_HOST" "生产服务器地址" "String" "1.2.3.4 或 server.example.com"
set_parameter "/studio-prod/DEPLOY_USER" "部署用户名" "String" "deploy"
set_parameter "/studio-prod/DEPLOY_SSH_KEY" "SSH 私钥" "SecureString" "~/.ssh/id_rsa"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✨ 设置完成！"
echo ""
echo "查看已配置的参数:"
echo ""
aws ssm describe-parameters \
    --filters "Key=Name,Values=/studio-prod/" \
    --query "Parameters[*].[Name,Type,LastModifiedDate]" \
    --output table

echo ""
echo "验证参数值（非加密）:"
echo ""
echo "DEPLOY_HOST: $(aws ssm get-parameter --name '/studio-prod/DEPLOY_HOST' --query 'Parameter.Value' --output text 2>/dev/null || echo '未设置')"
echo "DEPLOY_USER: $(aws ssm get-parameter --name '/studio-prod/DEPLOY_USER' --query 'Parameter.Value' --output text 2>/dev/null || echo '未设置')"
echo "DEPLOY_SSH_KEY: [SecureString - 已加密]"

echo ""
echo "下一步："
echo "1. 确保 GitHub Secrets 中已设置 CI_AWS_ACCESS_KEY_ID 和 CI_AWS_SECRET_ACCESS_KEY"
echo "2. 确保 CI 用的 IAM 用户有以下权限："
echo "   - ssm:GetParameter (for /studio-prod/*)"
echo "   - ecr:* (for Docker registry)"
echo "3. 推送代码测试部署"
echo ""

# 提供 IAM 策略示例
cat << 'EOF'
━━━━━━━━━━━━━━━━━━━━━━━━━━━━
📋 推荐的 IAM 策略：

{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "ssm:GetParameter",
        "ssm:GetParameters"
      ],
      "Resource": "arn:aws:ssm:us-west-2:*:parameter/studio-prod/*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "ecr:GetAuthorizationToken",
        "ecr:BatchCheckLayerAvailability",
        "ecr:GetDownloadUrlForLayer",
        "ecr:BatchGetImage",
        "ecr:PutImage",
        "ecr:InitiateLayerUpload",
        "ecr:UploadLayerPart",
        "ecr:CompleteLayerUpload"
      ],
      "Resource": "*"
    }
  ]
}
━━━━━━━━━━━━━━━━━━━━━━━━━━━━
EOF
