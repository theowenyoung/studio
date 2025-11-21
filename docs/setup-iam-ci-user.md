# 配置 CI IAM 用户指南

## 概述

为 GitHub Actions CI 创建一个专用的 IAM 用户，只具有必要的权限。

## 步骤 1：创建 IAM 用户

### 通过 AWS Console

1. 进入 AWS Console → IAM → Users
2. 点击 "Add users"
3. 用户名：`github-ci` 或 `studio-ci`
4. 访问类型：选择 "Programmatic access"（程序化访问）
5. 点击 "Next"

### 通过 AWS CLI

```bash
aws iam create-user --user-name github-ci
```

## 步骤 2：创建并附加策略

### 方式 A：使用提供的 JSON 文件（推荐）

```bash
# 1. 修改 S3 bucket 名称（根据你的实际 bucket 名称）
vim docs/iam-policy-ci-user.json

# 2. 创建策略
aws iam create-policy \
  --policy-name studio-ci-policy \
  --policy-document file://docs/iam-policy-ci-user.json

# 3. 获取策略 ARN（替换 ACCOUNT_ID）
POLICY_ARN="arn:aws:iam::ACCOUNT_ID:policy/studio-ci-policy"

# 4. 附加策略到用户
aws iam attach-user-policy \
  --user-name github-ci \
  --policy-arn $POLICY_ARN
```

### 方式 B：通过 AWS Console

1. IAM → Policies → Create policy
2. JSON 标签页 → 粘贴 `docs/iam-policy-ci-user.json` 的内容
3. 修改 S3 bucket 名称为你的实际名称
4. Review → 名称：`studio-ci-policy`
5. Create policy
6. IAM → Users → github-ci → Add permissions
7. 选择 `studio-ci-policy`

### 方式 C：使用 AWS 托管策略（快速但权限较大）

如果你想快速测试，可以使用这些托管策略（**不推荐生产环境**）：

```bash
# ECR 完全访问
aws iam attach-user-policy \
  --user-name github-ci \
  --policy-arn arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryPowerUser

# SSM 只读访问
aws iam attach-user-policy \
  --user-name github-ci \
  --policy-arn arn:aws:iam::aws:policy/AmazonSSMReadOnlyAccess

# S3 完全访问（需要限制到特定 bucket）
# 不推荐直接使用，请使用自定义策略
```

## 步骤 3：创建访问密钥

### 通过 AWS Console

1. IAM → Users → github-ci
2. Security credentials → Create access key
3. 用途：Application running outside AWS
4. 保存 Access Key ID 和 Secret Access Key

### 通过 AWS CLI

```bash
aws iam create-access-key --user-name github-ci

# 输出示例：
# {
#   "AccessKey": {
#     "AccessKeyId": "AKIAIOSFODNN7EXAMPLE",
#     "SecretAccessKey": "wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY",
#     "Status": "Active",
#     "CreateDate": "2024-01-01T00:00:00Z"
#   }
# }
```

⚠️ **重要**：Secret Access Key 只显示一次，请立即保存！

## 步骤 4：配置 GitHub Secrets

```bash
# 使用刚创建的访问密钥
gh secret set CI_AWS_ACCESS_KEY_ID
# 粘贴 Access Key ID

gh secret set CI_AWS_SECRET_ACCESS_KEY
# 粘贴 Secret Access Key
```

或使用提供的脚本：
```bash
./scripts/setup-github-secrets.sh
```

## 权限说明

### ECR 权限（Docker 镜像）

| 权限 | 用途 |
|------|------|
| `ecr:GetAuthorizationToken` | 登录 ECR |
| `ecr:BatchCheckLayerAvailability` | 检查镜像层是否存在 |
| `ecr:GetDownloadUrlForLayer` | 下载镜像层 |
| `ecr:BatchGetImage` | 获取镜像清单 |
| `ecr:PutImage` | 推送镜像 |
| `ecr:InitiateLayerUpload` | 开始上传层 |
| `ecr:UploadLayerPart` | 上传层分片 |
| `ecr:CompleteLayerUpload` | 完成层上传 |
| `ecr:DescribeRepositories` | 列出仓库 |
| `ecr:ListImages` | 列出镜像 |

### SSM 权限（Parameter Store）

| 权限 | 用途 | 资源 |
|------|------|------|
| `ssm:GetParameter` | 读取单个参数 | `/studio-prod/*`, `/studio-dev/*` |
| `ssm:GetParameters` | 批量读取参数 | `/studio-prod/*`, `/studio-dev/*` |
| `ssm:DescribeParameters` | 列出参数 | 所有资源 |

**注意**：此用户**只能读取**，不能写入或删除参数。

### S3 权限（备份和静态资源）

| 权限 | 用途 |
|------|------|
| `s3:PutObject` | 上传文件 |
| `s3:GetObject` | 下载文件 |
| `s3:ListBucket` | 列出文件 |
| `s3:DeleteObject` | 删除文件 |
| `s3:GetObjectVersion` | 获取文件版本 |
| `s3:PutObjectAcl` | 设置文件权限（静态网站） |

## 验证权限

### 测试 ECR 访问

```bash
# 使用 CI 用户的凭证
export AWS_ACCESS_KEY_ID="AKIA..."
export AWS_SECRET_ACCESS_KEY="wJalr..."

# 测试登录 ECR
aws ecr get-login-password --region us-west-2 | \
  docker login --username AWS --password-stdin 912951144733.dkr.ecr.us-west-2.amazonaws.com

# 应该看到：Login Succeeded
```

### 测试 Parameter Store 访问

```bash
# 读取参数（应该成功）
aws ssm get-parameter --name '/studio-prod/DEPLOY_HOST' --query 'Parameter.Value' --output text

# 写入参数（应该失败 - AccessDenied）
aws ssm put-parameter --name '/studio-prod/TEST' --value 'test' --type String
# 预期错误：An error occurred (AccessDeniedException)
```

### 测试 S3 访问

```bash
# 列出 bucket（根据你的实际 bucket 名称）
aws s3 ls s3://studio-backups-prod/

# 上传测试文件
echo "test" > /tmp/test.txt
aws s3 cp /tmp/test.txt s3://studio-backups-prod/test.txt
```

## 安全最佳实践

### ✅ 做到

1. **最小权限原则**
   - 只授予必要的权限
   - 限制资源范围（使用 ARN）

2. **定期轮换密钥**
   ```bash
   # 每 3-6 个月创建新密钥
   aws iam create-access-key --user-name github-ci

   # 更新 GitHub Secrets
   gh secret set CI_AWS_ACCESS_KEY_ID
   gh secret set CI_AWS_SECRET_ACCESS_KEY

   # 删除旧密钥
   aws iam delete-access-key --user-name github-ci --access-key-id OLD_KEY_ID
   ```

3. **启用 CloudTrail**
   - 监控 CI 用户的所有 API 调用
   - 设置异常活动告警

4. **使用条件限制**
   - 可选：限制来源 IP（如果 GitHub Actions 有固定 IP）
   - 限制使用时间（如工作时间）

### ❌ 避免

- ❌ 不要给 CI 用户管理员权限
- ❌ 不要使用 root 账户凭证
- ❌ 不要在代码中硬编码密钥
- ❌ 不要共享密钥给多个系统
- ❌ 不要长期不轮换密钥

## 修改 S3 Bucket 名称

如果你的 S3 bucket 名称不同，需要修改策略文件：

```bash
# 编辑策略文件
vim docs/iam-policy-ci-user.json

# 查找并替换 bucket 名称
# 旧的: studio-backups-prod
# 新的: your-actual-bucket-name
```

或使用 sed：
```bash
sed -i '' 's/studio-backups-prod/your-bucket-name/g' docs/iam-policy-ci-user.json
sed -i '' 's/studio-static-prod/your-static-bucket/g' docs/iam-policy-ci-user.json
```

## 多环境配置

如果你有多个环境（dev/staging/prod），建议：

### 方式 A：使用不同的 IAM 用户

```bash
# 开发环境 CI 用户
aws iam create-user --user-name github-ci-dev
# 附加策略（只能访问 /studio-dev/* 和 dev buckets）

# 生产环境 CI 用户
aws iam create-user --user-name github-ci-prod
# 附加策略（只能访问 /studio-prod/* 和 prod buckets）
```

### 方式 B：使用同一个用户，通过资源 ARN 区分

```json
{
  "Resource": [
    "arn:aws:ssm:us-west-2:*:parameter/studio-dev/*",
    "arn:aws:ssm:us-west-2:*:parameter/studio-staging/*",
    "arn:aws:ssm:us-west-2:*:parameter/studio-prod/*"
  ]
}
```

## 故障排查

### 问题 1：AccessDenied 错误

**原因**：权限不足

**解决方案**：
```bash
# 检查附加的策略
aws iam list-attached-user-policies --user-name github-ci

# 查看策略内容
aws iam get-policy-version \
  --policy-arn arn:aws:iam::ACCOUNT_ID:policy/studio-ci-policy \
  --version-id v1
```

### 问题 2：SecureString 无法解密

**原因**：缺少 KMS 权限

**解决方案**：添加 KMS 权限到策略
```json
{
  "Effect": "Allow",
  "Action": [
    "kms:Decrypt"
  ],
  "Resource": "arn:aws:kms:us-west-2:ACCOUNT_ID:key/KEY_ID"
}
```

### 问题 3：ECR 推送失败

**原因**：ECR 仓库策略限制

**解决方案**：检查 ECR 仓库策略
```bash
aws ecr get-repository-policy --repository-name hono-demo
```

## 监控和审计

### 查看 CI 用户活动

```bash
# CloudTrail 查询最近的活动
aws cloudtrail lookup-events \
  --lookup-attributes AttributeKey=Username,AttributeValue=github-ci \
  --max-results 10
```

### 设置告警

在 CloudWatch 中设置告警：
- 异常的 API 调用量
- 失败的认证尝试
- 访问未授权的资源

## 完成检查清单

- [ ] 创建 IAM 用户 `github-ci`
- [ ] 创建自定义策略 `studio-ci-policy`
- [ ] 修改策略中的 S3 bucket 名称
- [ ] 附加策略到用户
- [ ] 创建访问密钥
- [ ] 配置 GitHub Secrets
- [ ] 测试 ECR 访问
- [ ] 测试 Parameter Store 访问
- [ ] 测试 S3 访问
- [ ] 设置 CloudTrail 审计（可选）
- [ ] 设置密钥轮换提醒（日历）

## 相关文档

- [AWS IAM 最佳实践](https://docs.aws.amazon.com/IAM/latest/UserGuide/best-practices.html)
- [ECR 权限参考](https://docs.aws.amazon.com/AmazonECR/latest/userguide/security-iam.html)
- [Parameter Store 权限](https://docs.aws.amazon.com/systems-manager/latest/userguide/sysman-paramstore-access.html)
- [密钥配置指南](../.github/SECRETS.md)
