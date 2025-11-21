# GitHub Actions Workflows

这个目录包含自动化部署的 GitHub Actions workflows。

## Workflows 概览

### 1. `deploy-apps.yml` - 应用自动部署

**触发条件：**
- 自动：推送到 `main` 分支，且修改了 `js-apps/*` 或 `js-packages/*`
- 手动：通过 GitHub Actions UI 触发

**功能：**
- 自动检测变更的服务（基于文件路径）
- 仅部署需要更新的服务
- 支持并行部署多个服务
- 支持手动选择部署目标（单个/多个/全部）

**手动触发选项：**
- `auto` - 自动检测变更（基于当前 commit）
- `all` - 部署所有应用
- 单个服务：`hono-demo`, `proxy`, `blog`, `storefront`, `admin`, `api`

### 2. `deploy-infra.yml` - 基础设施手动部署

**触发条件：**
- 仅手动触发（workflow_dispatch）

**功能：**
- 部署基础设施服务（postgres, redis, caddy, backup）
- 支持单独部署或全部部署

## 必需的 GitHub Secrets

在 GitHub 仓库设置中配置以下 secrets：

### AWS 相关
```
AWS_ACCESS_KEY_ID         # AWS 访问密钥 ID（用于 ECR）
AWS_SECRET_ACCESS_KEY     # AWS 访问密钥
```

### 服务器相关
```
DEPLOY_HOST               # 生产服务器地址（IP 或域名）
DEPLOY_USER               # 部署用户（通常是 'deploy'）
DEPLOY_SSH_KEY            # SSH 私钥（用于连接服务器）
```

## 工作流程

### 自动部署流程（Push 触发）

```
1. 推送代码到 main 分支
   ├─ 修改 js-apps/hono-demo/src/index.ts
   └─ 推送到 GitHub

2. GitHub Actions 自动运行
   ├─ 检测到 hono-demo 变更
   ├─ 安装 mise 和依赖
   ├─ 缓存命中（pnpm store, mise tools）
   ├─ 构建 Docker 镜像（带缓存）
   ├─ 推送到 ECR
   └─ 通过 Ansible 部署到服务器

3. 部署完成
   └─ 查看部署摘要
```

### 手动部署流程

```
1. 进入 GitHub Actions 页面
2. 选择 "Deploy Applications" workflow
3. 点击 "Run workflow"
4. 选择部署目标：
   ├─ auto：自动检测变更
   ├─ all：部署所有服务
   └─ 单个服务：选择具体的服务名
5. 点击 "Run workflow" 开始部署
```

## 缓存策略

为了加快部署速度，workflow 使用了多层缓存：

### 1. Mise 工具缓存
```yaml
key: mise-${{ runner.os }}-${{ hashFiles('mise.toml') }}
```
缓存 mise 安装的工具（node, python, etc.）

### 2. pnpm Store 缓存
```yaml
key: pnpm-${{ runner.os }}-${{ hashFiles('**/pnpm-lock.yaml') }}
```
缓存 pnpm 下载的包（node_modules 由 pnpm 自动管理）

### 3. Docker Layer 缓存
通过 ECR 作为缓存源（在 build.sh 中配置）
```bash
--cache-from type=registry,ref=$ECR_REGISTRY/app:buildcache
--cache-to type=registry,ref=$ECR_REGISTRY/app:buildcache,mode=max
```

**预期性能：**
- 首次部署：8-15 分钟
- 缓存命中后：2-5 分钟
- 无代码变更重新部署：1-2 分钟

## 部署架构

```
┌─────────────────┐
│  GitHub Repo    │
└────────┬────────┘
         │ git push / manual trigger
         ↓
┌─────────────────┐
│ GitHub Actions  │
│  - Install mise │
│  - Build image  │
│  - Push to ECR  │
└────────┬────────┘
         │ mise run deploy-app-xxx
         ↓
┌─────────────────┐
│    Ansible      │
│  - Pull image   │
│  - Deploy       │
└────────┬────────┘
         │ SSH
         ↓
┌─────────────────┐
│ Production      │
│   Server        │
└─────────────────┘
```

## 监控和调试

### 查看部署日志
1. 进入 GitHub Actions 页面
2. 选择对应的 workflow run
3. 查看每个步骤的详细日志

### 部署失败排查
1. 检查 GitHub Secrets 是否正确配置
2. 查看失败步骤的错误信息
3. 本地运行相同的 mise 命令测试
4. 检查服务器状态和 Ansible 日志

### 常见问题

**Q: 为什么没有自动部署？**
A: 检查是否修改了 `js-apps/*` 或 `js-packages/*` 目录下的文件

**Q: 如何只部署单个服务？**
A: 使用手动触发，选择对应的服务名

**Q: 共享包变更会部署哪些服务？**
A: 会部署所有应用（因为它们都依赖共享包）

**Q: 如何重新部署而不修改代码？**
A: 使用手动触发，选择要部署的服务

## 本地测试

在推送到 GitHub 之前，可以本地测试部署流程：

```bash
# 测试单个服务部署
mise run deploy-app-hono-demo

# 测试基础设施部署
mise run deploy-infra-postgres

# 测试构建（不部署）
mise run build-app-hono
```

## 扩展新服务

添加新服务的步骤：

1. 在 `js-apps/` 下创建新服务目录
2. 确保 package.json 有 `"private": true`
3. 在 `mise.toml` 中添加对应的 build 和 deploy 任务
4. workflow 会自动识别新服务（无需修改 workflow 文件）

## 安全注意事项

- ⚠️ 永远不要在代码中硬编码密钥
- ⚠️ 定期轮换 SSH 密钥和 AWS 凭证
- ⚠️ 使用最小权限原则配置 AWS IAM
- ⚠️ 定期检查 GitHub Actions 日志，避免泄露敏感信息
