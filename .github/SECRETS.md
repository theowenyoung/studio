# 密钥配置指南

本项目使用 **AWS Parameter Store** 集中管理所有配置和密钥，GitHub Secrets 中只需要存放最少的 CI 凭证。

## 架构设计

```
GitHub Actions (CI)
    ↓ 使用 CI_AWS_* 凭证
AWS Parameter Store
    ├── /studio-prod/DEPLOY_HOST      → 生产服务器地址
    ├── /studio-prod/DEPLOY_USER      → 部署用户名
    └── /studio-prod/DEPLOY_SSH_KEY   → SSH 私钥（加密）
```

### 优点

✅ **集中管理**：所有密钥在 AWS 中统一管理，便于轮换和审计
✅ **最小暴露**：GitHub 只需要 2 个 secrets，降低泄露风险
✅ **加密存储**：SSH 私钥等敏感信息使用 SecureString 加密
✅ **权限控制**：通过 IAM 精细控制访问权限
✅ **版本历史**：Parameter Store 保留参数变更历史

## 配置步骤

### 第一步：设置 GitHub Secrets（只需 2 个）

这些是 CI 用来访问 AWS Parameter Store 和 ECR 的凭证。

#### 方法 1：使用脚本（推荐）

```bash
./scripts/setup-github-secrets.sh
```

#### 方法 2：使用 GitHub CLI

```bash
gh secret set CI_AWS_ACCESS_KEY_ID
# 输入 AWS Access Key ID

gh secret set CI_AWS_SECRET_ACCESS_KEY
# 输入 AWS Secret Access Key
```

#### 方法 3：通过 GitHub Web UI

1. 进入仓库 → Settings → Secrets and variables → Actions
2. 添加以下 2 个 secrets：
   - `CI_AWS_ACCESS_KEY_ID`
   - `CI_AWS_SECRET_ACCESS_KEY`

### 第二步：设置 AWS Parameter Store

#### 方法 1：使用脚本（推荐）

```bash
./scripts/setup-parameter-store.sh
```

脚本会交互式地引导你设置所有必需的参数。

#### 方法 2：使用 AWS CLI

```bash
# 服务器地址
aws ssm put-parameter \
  --name '/studio-prod/DEPLOY_HOST' \
  --value '1.2.3.4' \
  --type String \
  --description '生产服务器地址'

# 部署用户
aws ssm put-parameter \
  --name '/studio-prod/DEPLOY_USER' \
  --value 'deploy' \
  --type String \
  --description '部署用户名'

# SSH 私钥（SecureString 加密）
aws ssm put-parameter \
  --name '/studio-prod/DEPLOY_SSH_KEY' \
  --value "file://$HOME/.ssh/id_rsa" \
  --type SecureString \
  --description 'SSH 私钥'
```

#### 方法 3：通过 AWS Console

1. 进入 AWS Systems Manager → Parameter Store
2. Create parameter
3. 依次创建以下参数：

| Name | Type | Value |
|------|------|-------|
| /studio-prod/DEPLOY_HOST | String | 你的服务器地址 |
| /studio-prod/DEPLOY_USER | String | deploy |
| /studio-prod/DEPLOY_SSH_KEY | SecureString | SSH 私钥内容 |

### 第三步：配置 IAM 权限

CI 用的 IAM 用户需要以下权限：

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "ParameterStoreAccess",
      "Effect": "Allow",
      "Action": [
        "ssm:GetParameter",
        "ssm:GetParameters"
      ],
      "Resource": "arn:aws:ssm:us-west-2:*:parameter/studio-prod/*"
    },
    {
      "Sid": "ECRAccess",
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
```

保存为 IAM 策略并附加到 CI 用户。

## 验证配置

### 验证 GitHub Secrets

```bash
gh secret list

# 应该看到：
# CI_AWS_ACCESS_KEY_ID
# CI_AWS_SECRET_ACCESS_KEY
```

### 验证 Parameter Store

```bash
# 列出所有参数
aws ssm describe-parameters \
  --filters "Key=Name,Values=/studio-prod/" \
  --query "Parameters[*].[Name,Type]" \
  --output table

# 读取参数值（非加密）
aws ssm get-parameter \
  --name '/studio-prod/DEPLOY_HOST' \
  --query 'Parameter.Value' \
  --output text

# 读取加密参数
aws ssm get-parameter \
  --name '/studio-prod/DEPLOY_SSH_KEY' \
  --with-decryption \
  --query 'Parameter.Value' \
  --output text
```

### 测试部署流程

```bash
# 本地测试（需要配置本地 AWS 凭证）
aws ssm get-parameter --name '/studio-prod/DEPLOY_HOST' --query 'Parameter.Value' --output text

# 推送代码触发 CI
git push origin main

# 监控部署
gh run watch
```

## 工作流程

当 GitHub Actions 运行时：

1. **认证 AWS**
   ```yaml
   - uses: aws-actions/configure-aws-credentials@v4
     with:
       aws-access-key-id: ${{ secrets.CI_AWS_ACCESS_KEY_ID }}
       aws-secret-access-key: ${{ secrets.CI_AWS_SECRET_ACCESS_KEY }}
   ```

2. **从 Parameter Store 读取配置**
   ```bash
   DEPLOY_HOST=$(aws ssm get-parameter --name "/studio-prod/DEPLOY_HOST" --query "Parameter.Value" --output text)
   DEPLOY_USER=$(aws ssm get-parameter --name "/studio-prod/DEPLOY_USER" --query "Parameter.Value" --output text)
   DEPLOY_SSH_KEY=$(aws ssm get-parameter --name "/studio-prod/DEPLOY_SSH_KEY" --with-decryption --query "Parameter.Value" --output text)
   ```

3. **使用配置进行部署**
   - 配置 SSH
   - 登录 ECR
   - 运行 Ansible
   - 部署服务

## 管理和维护

### 更新参数

```bash
# 更新服务器地址
aws ssm put-parameter \
  --name '/studio-prod/DEPLOY_HOST' \
  --value '新的地址' \
  --type String \
  --overwrite

# 更新 SSH 密钥
aws ssm put-parameter \
  --name '/studio-prod/DEPLOY_SSH_KEY' \
  --value "file://$HOME/.ssh/new_key" \
  --type SecureString \
  --overwrite
```

### 轮换密钥

**建议每 3-6 个月轮换一次：**

1. **轮换 AWS 凭证**
   ```bash
   # 在 AWS IAM 中创建新的 Access Key
   # 更新 GitHub Secrets
   gh secret set CI_AWS_ACCESS_KEY_ID
   gh secret set CI_AWS_SECRET_ACCESS_KEY
   # 删除旧的 Access Key
   ```

2. **轮换 SSH 密钥**
   ```bash
   # 生成新密钥
   ssh-keygen -t ed25519 -f ~/.ssh/deploy_new

   # 添加公钥到服务器
   ssh-copy-id -i ~/.ssh/deploy_new.pub deploy@server

   # 更新 Parameter Store
   aws ssm put-parameter \
     --name '/studio-prod/DEPLOY_SSH_KEY' \
     --value "file://$HOME/.ssh/deploy_new" \
     --type SecureString \
     --overwrite

   # 测试后删除旧密钥
   ```

### 查看历史版本

```bash
# 查看参数历史
aws ssm get-parameter-history \
  --name '/studio-prod/DEPLOY_HOST' \
  --query 'Parameters[*].[LastModifiedDate,Value]' \
  --output table
```

### 删除参数

```bash
aws ssm delete-parameter --name '/studio-prod/DEPLOY_HOST'
```

## 安全最佳实践

### ✅ 做到

- ✅ 使用独立的 CI IAM 用户，不要使用管理员权限
- ✅ 为 SSH 私钥使用 SecureString 类型
- ✅ 定期轮换所有凭证（建议 3-6 个月）
- ✅ 启用 AWS CloudTrail 审计 Parameter Store 访问
- ✅ 使用 MFA 保护 AWS 账户
- ✅ 定期审查 IAM 权限

### ❌ 避免

- ❌ 不要在代码中硬编码任何密钥
- ❌ 不要在 Git 提交历史中包含密钥
- ❌ 不要共享 AWS root 账户凭证
- ❌ 不要给 CI 用户过多权限
- ❌ 不要在日志中输出敏感信息

## 多环境配置

如果需要支持多个环境（dev/staging/prod）：

```bash
# 开发环境
/studio-dev/DEPLOY_HOST
/studio-dev/DEPLOY_USER
/studio-dev/DEPLOY_SSH_KEY

# 预发布环境
/studio-staging/DEPLOY_HOST
/studio-staging/DEPLOY_USER
/studio-staging/DEPLOY_SSH_KEY

# 生产环境
/studio-prod/DEPLOY_HOST
/studio-prod/DEPLOY_USER
/studio-prod/DEPLOY_SSH_KEY
```

在 workflow 中根据分支或环境变量选择不同的前缀。

## 故障排查

### 问题：无法读取参数

```bash
# 检查权限
aws ssm describe-parameters --filters "Key=Name,Values=/studio-prod/"

# 如果出现 AccessDenied，检查 IAM 策略
aws iam get-user-policy --user-name ci-user --policy-name ci-policy
```

### 问题：SSH 连接失败

```bash
# 验证 SSH 密钥格式
aws ssm get-parameter \
  --name '/studio-prod/DEPLOY_SSH_KEY' \
  --with-decryption \
  --query 'Parameter.Value' \
  --output text | head -1

# 应该看到：-----BEGIN OPENSSH PRIVATE KEY-----
```

### 问题：参数不存在

```bash
# 列出所有参数
aws ssm describe-parameters --query "Parameters[*].Name"

# 重新创建参数
./scripts/setup-parameter-store.sh
```

## 相关文档

- [AWS Systems Manager Parameter Store](https://docs.aws.amazon.com/systems-manager/latest/userguide/systems-manager-parameter-store.html)
- [GitHub Encrypted Secrets](https://docs.github.com/en/actions/security-guides/encrypted-secrets)
- [部署指南](DEPLOYMENT.md)
- [检查清单](CHECKLIST.md)
