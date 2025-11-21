# 快速开始 - GitHub Actions 部署

## 🚀 5 分钟设置指南

### 1️⃣ 设置 GitHub Secrets（2 个）

```bash
./scripts/setup-github-secrets.sh
```

或手动设置：
```bash
gh secret set CI_AWS_ACCESS_KEY_ID
gh secret set CI_AWS_SECRET_ACCESS_KEY
```

### 2️⃣ 设置 AWS Parameter Store（3 个）

```bash
./scripts/setup-parameter-store.sh
```

或手动设置：
```bash
aws ssm put-parameter --name '/studio-prod/DEPLOY_HOST' --value '1.2.3.4' --type String
aws ssm put-parameter --name '/studio-prod/DEPLOY_USER' --value 'deploy' --type String
aws ssm put-parameter --name '/studio-prod/DEPLOY_SSH_KEY' --value "file://$HOME/.ssh/id_rsa" --type SecureString
```

### 3️⃣ 配置 IAM 权限

确保 CI 用户有以下权限：
- ✅ `ssm:GetParameter` for `/studio-prod/*`
- ✅ `ecr:*` for Docker registry

### 4️⃣ 测试部署

```bash
# 推送代码触发自动部署
git push origin main

# 或手动触发
gh workflow run deploy-apps.yml -f target=hono-demo
```

## 📊 密钥存储架构

```
┌─────────────────────────────────────┐
│      GitHub Secrets (只需2个)        │
│  • CI_AWS_ACCESS_KEY_ID             │
│  • CI_AWS_SECRET_ACCESS_KEY         │
└──────────────┬──────────────────────┘
               │
               ↓ 使用这2个凭证访问
┌─────────────────────────────────────┐
│   AWS Parameter Store (其他所有)     │
│  • /studio-prod/DEPLOY_HOST         │
│  • /studio-prod/DEPLOY_USER         │
│  • /studio-prod/DEPLOY_SSH_KEY      │
└─────────────────────────────────────┘
```

## 🔑 需要的密钥

### GitHub Secrets

| 名称 | 说明 | 示例 |
|------|------|------|
| `CI_AWS_ACCESS_KEY_ID` | AWS 访问密钥 ID | `AKIA...` |
| `CI_AWS_SECRET_ACCESS_KEY` | AWS 访问密钥 | `wJalr...` |

### AWS Parameter Store

| 名称 | 类型 | 说明 | 示例 |
|------|------|------|------|
| `/studio-prod/DEPLOY_HOST` | String | 服务器地址 | `1.2.3.4` |
| `/studio-prod/DEPLOY_USER` | String | 部署用户 | `deploy` |
| `/studio-prod/DEPLOY_SSH_KEY` | SecureString | SSH 私钥 | `-----BEGIN...` |

## ✅ 验证配置

```bash
# 1. 验证 GitHub Secrets
gh secret list

# 2. 验证 Parameter Store
aws ssm get-parameter --name '/studio-prod/DEPLOY_HOST' --query 'Parameter.Value' --output text

# 3. 验证权限
aws ssm describe-parameters --filters "Key=Name,Values=/studio-prod/"
```

## 🎯 常用命令

```bash
# 自动部署（推送触发）
git push origin main

# 手动部署单个服务
gh workflow run deploy-apps.yml -f target=hono-demo

# 手动部署所有服务
gh workflow run deploy-apps.yml -f target=all

# 部署基础设施
gh workflow run deploy-infra.yml -f service=postgres

# 监控部署状态
gh run watch

# 查看最近的部署
gh run list --workflow=deploy-apps.yml --limit 5
```

## 📚 详细文档

- [密钥配置详细指南](SECRETS.md)
- [完整部署指南](DEPLOYMENT.md)
- [配置检查清单](CHECKLIST.md)
- [Workflow 说明](workflows/README.md)

## 🆘 遇到问题？

### 问题 1：无法读取 Parameter Store

**解决方案：**
```bash
# 检查 IAM 权限
aws iam get-user-policy --user-name ci-user --policy-name ci-policy
```

### 问题 2：SSH 连接失败

**解决方案：**
```bash
# 验证 SSH 密钥格式
aws ssm get-parameter --name '/studio-prod/DEPLOY_SSH_KEY' --with-decryption --query 'Parameter.Value' --output text | head -1
# 应该看到：-----BEGIN OPENSSH PRIVATE KEY-----
```

### 问题 3：ECR 推送失败

**解决方案：**
```bash
# 测试 ECR 登录
aws ecr get-login-password --region us-west-2 | docker login --username AWS --password-stdin 912951144733.dkr.ecr.us-west-2.amazonaws.com
```

## 💡 最佳实践

- ✅ 每 3-6 个月轮换一次密钥
- ✅ 使用 SecureString 存储敏感信息
- ✅ 最小权限原则配置 IAM
- ✅ 定期审查 CloudTrail 日志
- ✅ 不要在代码中硬编码任何密钥

## 🎉 完成！

配置完成后，每次推送代码到 `main` 分支，GitHub Actions 会自动：
1. 从 Parameter Store 读取配置
2. 构建 Docker 镜像（带缓存）
3. 推送到 ECR
4. 通过 Ansible 部署到服务器

享受自动化部署的便利！🚀
