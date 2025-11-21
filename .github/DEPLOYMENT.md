# 部署指南

## 快速开始

### 前置条件

1. **安装 GitHub CLI**
   ```bash
   brew install gh
   gh auth login
   ```

2. **配置 GitHub Secrets**
   ```bash
   ./scripts/setup-github-secrets.sh
   ```

   或手动在 GitHub 仓库设置中添加以下 secrets：
   - `AWS_ACCESS_KEY_ID` - AWS 访问密钥
   - `AWS_SECRET_ACCESS_KEY` - AWS 密钥
   - `DEPLOY_HOST` - 服务器地址
   - `DEPLOY_USER` - 部署用户（通常是 `deploy`）
   - `DEPLOY_SSH_KEY` - SSH 私钥内容

## 部署方式

### 1. 自动部署（推荐）

推送代码到 `main` 分支即可自动部署：

```bash
# 修改代码
vim js-apps/hono-demo/src/index.ts

# 提交并推送
git add .
git commit -m "Update hono-demo"
git push origin main

# GitHub Actions 会自动检测变更并部署 hono-demo
```

**智能检测规则：**
- 只部署变更的服务
- 共享包（js-packages/*）变更 → 部署所有服务
- 多个服务变更 → 并行部署

### 2. 手动部署

#### 方式 A：通过 GitHub UI

1. 进入仓库的 `Actions` 页面
2. 选择 `Deploy Applications` workflow
3. 点击 `Run workflow`
4. 选择部署目标：
   - `auto` - 自动检测变更
   - `all` - 部署所有服务
   - 具体服务名 - 部署单个服务
5. 点击 `Run workflow` 开始

#### 方式 B：通过 GitHub CLI

```bash
# 部署单个服务
gh workflow run deploy-apps.yml -f target=hono-demo

# 部署所有服务
gh workflow run deploy-apps.yml -f target=all

# 自动检测并部署
gh workflow run deploy-apps.yml -f target=auto
```

### 3. 本地部署

```bash
# 部署应用
mise run deploy-app-hono-demo
mise run deploy-app-proxy
mise run deploy-app-blog
mise run deploy-app-storefront

# 部署基础设施（仅手动）
mise run deploy-infra-postgres
mise run deploy-infra-redis
mise run deploy-infra-caddy
mise run deploy-infra-backup
```

## 部署流程详解

### 应用部署流程

```
1. 触发部署
   └─ git push 或手动触发

2. 检测变更
   └─ 使用 paths-filter 检测哪些服务需要部署

3. 准备环境
   ├─ 安装 mise
   ├─ 恢复缓存（pnpm store, mise tools）
   └─ 配置 AWS 和 SSH

4. 构建镜像
   ├─ 运行 mise run build-app-xxx
   ├─ 执行 js-apps/xxx/build.sh
   ├─ 使用 Docker buildx（带缓存）
   └─ 推送到 ECR

5. 部署到服务器
   ├─ 运行 Ansible playbook
   ├─ 拉取最新镜像
   ├─ 重启容器
   └─ 健康检查

6. 完成
   └─ 显示部署摘要
```

### 缓存机制

**三层缓存提速：**

1. **Mise 工具缓存**
   - 缓存 mise 安装的工具（node, python, etc.）
   - 节省时间：30s-1min

2. **pnpm Store 缓存**
   - 缓存 npm 包下载
   - 节省时间：2-5min

3. **Docker Layer 缓存**
   - 通过 ECR 作为缓存源
   - 节省时间：3-10min

**性能表现：**
- 首次部署：8-15 分钟
- 代码变更（缓存命中）：2-5 分钟
- 重新部署（无变更）：1-2 分钟

## 部署场景示例

### 场景 1：修复 Bug

```bash
# 1. 修复代码
vim js-apps/hono-demo/src/api/users.ts

# 2. 本地测试
mise run dev-hono

# 3. 提交推送
git add .
git commit -m "fix: user API validation"
git push

# ✅ GitHub Actions 自动部署 hono-demo
```

### 场景 2：更新共享组件

```bash
# 1. 更新共享 UI 组件
vim js-packages/ui/src/Button.tsx

# 2. 推送
git add .
git commit -m "feat: add loading state to Button"
git push

# ✅ GitHub Actions 自动部署所有使用该组件的应用
```

### 场景 3：紧急回滚

```bash
# 方式 A：使用 mise 回滚任务（如果有）
mise run server-rollback-app-hono

# 方式 B：重新部署上一个版本
git revert HEAD
git push

# 方式 C：手动在服务器上回滚
ssh deploy@your-server
cd /srv/studio/js-apps/hono-demo
PREV=$(ls -t | grep '^[0-9]\{14\}$' | sed -n 2p)
ln -sfn $PREV current
cd current && docker compose up -d
```

### 场景 4：部署新功能（需要数据库迁移）

```bash
# 1. 先部署数据库迁移
gh workflow run deploy-apps.yml -f target=hono-demo
# 等待部署完成，mise 会自动运行迁移

# 2. 如果需要单独运行迁移
ssh deploy@your-server
cd /srv/studio/js-apps/hono-demo/current
docker compose run --rm app pnpm migrate
```

## 监控和调试

### 查看部署状态

```bash
# 列出最近的 workflow runs
gh run list --workflow=deploy-apps.yml

# 查看特定 run 的状态
gh run view <run-id>

# 查看日志
gh run view <run-id> --log
```

### 常见问题排查

#### 1. 部署失败：SSH 连接问题

```bash
# 检查 SSH key 是否正确
gh secret list | grep DEPLOY_SSH_KEY

# 本地测试 SSH 连接
ssh -i ~/.ssh/id_rsa deploy@your-server

# 更新 SSH key
gh secret set DEPLOY_SSH_KEY < ~/.ssh/id_rsa
```

#### 2. 部署失败：Docker 构建错误

```bash
# 本地重现构建
cd js-apps/hono-demo
docker build -t test .

# 查看详细日志
mise run build-app-hono
```

#### 3. 部署失败：ECR 推送权限问题

```bash
# 检查 AWS 凭证
aws ecr get-login-password --region us-west-2

# 更新 AWS 凭证
gh secret set AWS_ACCESS_KEY_ID
gh secret set AWS_SECRET_ACCESS_KEY
```

#### 4. 服务未更新

```bash
# SSH 到服务器检查
ssh deploy@your-server
cd /srv/studio/js-apps/hono-demo/current
docker compose ps
docker compose logs --tail=50

# 检查镜像版本
docker images | grep hono-demo
```

## 最佳实践

### 1. 部署前检查清单

- [ ] 本地测试通过 (`mise run dev`)
- [ ] 代码已经过 lint (`mise run lint`)
- [ ] 提交信息清晰明确
- [ ] 已合并最新的 main 分支

### 2. 安全建议

- ⚠️ 定期轮换 SSH 密钥（建议 3-6 个月）
- ⚠️ 定期轮换 AWS 凭证
- ⚠️ 使用最小权限的 IAM 角色
- ⚠️ 定期审查 GitHub Actions 日志

### 3. 性能优化

- 💡 保持 pnpm-lock.yaml 稳定，提高缓存命中率
- 💡 构建脚本中使用 Docker buildx 缓存
- 💡 合理组织 Dockerfile，利用 layer 缓存
- 💡 避免在构建时下载大文件

### 4. 分支策略建议

```
main (production)
  ↑
  └─ feature/* (开发分支)
```

- `main` 分支保护，只能通过 PR 合并
- PR 合并后自动部署到生产环境
- 考虑添加 staging 分支用于预发布测试

## 扩展和自定义

### 添加新服务

1. 在 `js-apps/` 下创建新目录
2. 添加 build.sh 和 docker-compose.yml
3. 在 `mise.toml` 中添加构建和部署任务
4. Workflow 会自动识别（无需修改）

### 添加部署通知

在 workflow 中添加通知步骤：

```yaml
- name: Notify deployment
  if: always()
  run: |
    # 发送到 Slack
    curl -X POST ${{ secrets.SLACK_WEBHOOK }} \
      -d "{'text':'Deployed ${{ matrix.service }}: ${{ job.status }}'}"
```

### 添加部署审批

对于生产环境，可以添加手动审批：

```yaml
jobs:
  approve:
    runs-on: ubuntu-latest
    environment: production  # 需要在 GitHub 设置中配置
    steps:
      - run: echo "Approved"

  deploy:
    needs: approve
    # ...
```

## 相关文档

- [Workflows README](.github/workflows/README.md) - Workflow 详细说明
- [mise.toml](../mise.toml) - 任务定义
- [Ansible Playbooks](../ansible/playbooks/) - 部署脚本
