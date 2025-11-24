# ECR 生命周期管理策略

## 问题背景

AWS ECR 的生命周期规则是 **per-repository** 的，不能全局设置。对于有多个仓库的项目，需要逐个配置，非常繁琐。

---

## 自动化方案对比

### 方案 A：AWS CLI 脚本（推荐）✅

**实现**：`scripts/setup-ecr-lifecycle.sh`

```bash
# 一键设置所有仓库
mise run ecr-lifecycle
```

**优点**：
- ✅ 简单直接，一个脚本搞定
- ✅ 幂等操作（重复运行无副作用）
- ✅ 无额外依赖（只需 AWS CLI）
- ✅ 跳过已有规则的仓库
- ✅ 支持后续新增仓库（重新运行即可）

**缺点**：
- ⚠️ 需要手动运行（新增仓库时）
- ⚠️ 需要 AWS 凭证

**适用场景**：
- 仓库数量：任意（1-100+）
- 更新频率：低（仓库创建时运行一次）
- 团队规模：任意

---

### 方案 B：Terraform/CDK（过度设计）

**实现**：使用 IaC 工具管理 ECR

```hcl
# terraform/ecr.tf
resource "aws_ecr_repository" "studio" {
  for_each = toset([
    "studio/hono-demo",
    "studio/proxy",
    "studio/blog"
  ])
  name = each.value
}

resource "aws_ecr_lifecycle_policy" "studio" {
  for_each = aws_ecr_repository.studio
  repository = each.value.name

  policy = jsonencode({
    rules = [
      # ... 规则定义
    ]
  })
}
```

**优点**：
- ✅ 声明式配置
- ✅ 版本控制
- ✅ 自动化（CI/CD）

**缺点**：
- ❌ 引入额外工具（Terraform/CDK）
- ❌ 学习成本高
- ❌ 需要维护 state
- ❌ 过度复杂（对于简单需求）

**适用场景**：
- 已经在用 Terraform/CDK 管理 AWS 资源
- 需要严格的 IaC
- 团队有 DevOps 工程师

---

### 方案 C：Lambda + EventBridge（过度自动化）

**实现**：仓库创建时自动应用规则

```python
# lambda/auto-apply-lifecycle.py
def handler(event, context):
    repo_name = event['detail']['repositoryName']
    if repo_name.startswith('studio/'):
        ecr_client.put_lifecycle_policy(
            repositoryName=repo_name,
            lifecyclePolicyText=POLICY_JSON
        )
```

**优点**：
- ✅ 完全自动化
- ✅ 新仓库自动应用规则

**缺点**：
- ❌ 过度复杂
- ❌ 需要维护 Lambda 函数
- ❌ 需要配置 EventBridge
- ❌ 调试困难

**适用场景**：
- 仓库创建非常频繁
- 有专职 DevOps 团队
- 需要零手动干预

---

### 方案 D：ECR Public Registry（不适用）

AWS ECR Public 支持组织级别的规则，但：
- ❌ 只适用于公共镜像
- ❌ 我们用的是私有仓库

---

## 推荐方案

### 对于大多数项目：方案 A（脚本）✅

**理由**：
1. **简单**：一个 bash 脚本，无需额外工具
2. **够用**：ECR 仓库不会频繁创建
3. **可维护**：团队成员都能看懂和修改
4. **成本低**：无需额外 AWS 资源

**使用场景**：
```bash
# 场景 1：初始化项目
mise run ecr-lifecycle

# 场景 2：新增仓库后
# 1. 创建新仓库（通过 build.sh 自动创建）
# 2. 运行脚本应用规则
mise run ecr-lifecycle

# 场景 3：修改规则
# 1. 编辑 scripts/setup-ecr-lifecycle.sh
# 2. 删除旧规则（可选）
# 3. 重新运行
mise run ecr-lifecycle
```

---

## 脚本详解

### 核心逻辑

```bash
# 1. 获取所有 studio/* 仓库
REPOS=$(aws ecr describe-repositories \
  --region us-west-2 \
  --query "repositories[?starts_with(repositoryName, 'studio/')].repositoryName" \
  --output text)

# 2. 为每个仓库设置规则
for REPO in $REPOS; do
  # 检查是否已有规则
  EXISTING_POLICY=$(aws ecr get-lifecycle-policy \
    --repository-name "$REPO" 2>/dev/null || echo "")

  if [ -n "$EXISTING_POLICY" ]; then
    echo "Skipping $REPO (already has policy)"
    continue
  fi

  # 应用规则
  aws ecr put-lifecycle-policy \
    --repository-name "$REPO" \
    --lifecycle-policy-text "$LIFECYCLE_POLICY"
done
```

### 幂等性保证

**问题**：重复运行会覆盖已有规则吗？

**答案**：不会。脚本会跳过已有规则的仓库。

```bash
# 第一次运行
mise run ecr-lifecycle
# ✅ Applied: 10
# ⏭️  Skipped: 0

# 第二次运行（无新仓库）
mise run ecr-lifecycle
# ✅ Applied: 0
# ⏭️  Skipped: 10

# 新增仓库后运行
mise run ecr-lifecycle
# ✅ Applied: 1
# ⏭️  Skipped: 10
```

---

## 最佳实践

### 1. 初始化时运行

```bash
# 在 README.md 中添加
### 初始化 ECR 生命周期规则

mise run ecr-lifecycle
```

### 2. 新仓库创建时提醒

在 `scripts/build-lib.sh` 的 `ensure_ecr_repo()` 函数中添加提醒：

```bash
ensure_ecr_repo() {
  local repo_name=$1

  if aws ecr describe-repositories --repository-names "$repo_name" 2>/dev/null; then
    return 0
  fi

  echo "📦 Creating ECR repository: $repo_name"
  aws ecr create-repository --repository-name "$repo_name"

  echo ""
  echo "⚠️  Remember to setup lifecycle policy:"
  echo "   mise run ecr-lifecycle"
  echo ""
}
```

### 3. 定期检查

添加到 CI/CD 或定期运维任务：

```bash
# 每月运行一次，确保所有仓库都有规则
0 0 1 * * cd /path/to/project && mise run ecr-lifecycle
```

---

## 故障排查

### 问题 1：脚本报错 "No repositories found"

**原因**：仓库前缀不匹配

**解决**：
```bash
# 检查实际的仓库名
aws ecr describe-repositories --query 'repositories[].repositoryName'

# 调整脚本中的 REPO_PREFIX
REPO_PREFIX="your-prefix/"
```

### 问题 2：权限错误

**原因**：AWS 凭证没有 ECR 权限

**解决**：
```bash
# 确保 IAM 用户/角色有以下权限
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "ecr:DescribeRepositories",
        "ecr:GetLifecyclePolicy",
        "ecr:PutLifecyclePolicy"
      ],
      "Resource": "*"
    }
  ]
}
```

### 问题 3：想强制覆盖已有规则

**解决**：
```bash
# 编辑 scripts/setup-ecr-lifecycle.sh
# 删除这几行：
if [ -n "$EXISTING_POLICY" ]; then
  echo "   ⏭️  Skipping (already has lifecycle policy)"
  ((SKIP_COUNT++))
  continue
fi
```

---

## 成本分析

### 方案 A（脚本）
- **开发成本**：1 小时（一次性）
- **运行成本**：$0（只是 API 调用）
- **维护成本**：极低（几乎不需要改动）

### 方案 B（Terraform）
- **开发成本**：4-8 小时（学习 + 编写）
- **运行成本**：$0
- **维护成本**：中等（需要维护 state）

### 方案 C（Lambda）
- **开发成本**：8-16 小时（Lambda + EventBridge + 测试）
- **运行成本**：~$0.2/月（Lambda 调用费）
- **维护成本**：高（调试、监控）

---

## 总结

### 推荐使用方案 A（脚本）

**核心原因**：
- ✅ **简单够用**：ECR 仓库不会频繁创建
- ✅ **零成本**：无需额外 AWS 资源
- ✅ **易维护**：团队成员都能理解和修改
- ✅ **快速实施**：1 小时内完成

**使用方式**：
```bash
# 1. 初始化
mise run ecr-lifecycle

# 2. 新增仓库后重新运行
mise run ecr-lifecycle

# 3. 修改规则后重新运行
mise run ecr-lifecycle
```

**何时考虑其他方案**：
- 已经在用 Terraform/CDK → 方案 B
- 仓库创建非常频繁（> 1次/天） → 方案 C
- 需要多区域部署 → 扩展方案 A 支持多区域

---

**对于 monorepo + 少量微服务的场景，脚本方案是最佳选择！** 🚀
