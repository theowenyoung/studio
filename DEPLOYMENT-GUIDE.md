# 部署指南

## 服务器架构

```
prod (5.78.126.18)      - 生产环境，运行所有基础设施和生产应用
preview (49.13.31.185)  - 预览环境，运行分支预览应用
```

## 服务器初始化（首次设置）

### 1. 创建 deploy 用户（在新服务器上）

```bash
# 在 prod 服务器上创建用户
mise run server-init-user 5.78.126.18

# 在 preview 服务器上创建用户
mise run server-init-user 49.13.31.185
```

### 2. 初始化服务器环境

```bash
# 初始化单个服务器
mise run server-init-prod        # 初始化生产服务器
mise run server-init-preview     # 初始化预览服务器

# 初始化所有服务器（推荐，一次性设置）
mise run server-init-all         # 或 mise run server-init
```

这会设置：
- ✅ 安全配置（防火墙、fail2ban、SSH 加固）
- ✅ Docker 环境
- ✅ 目录结构 (`/srv/studio`, `/data`)
- ✅ mise 工具和配置
- ✅ Bash 别名和环境

### 3. 配置 AWS 凭证（用于 ECR 访问）

```bash
# 单个服务器
mise run server-configure-aws-prod
mise run server-configure-aws-preview

# 所有服务器
mise run server-configure-aws-all    # 或 mise run server-configure-aws
```

### 4. 部署基础设施（仅生产服务器）

```bash
# 部署所有基础设施
mise run deploy-infra

# 或单独部署
mise run deploy-postgres
mise run deploy-redis
mise run deploy-caddy
mise run deploy-db-admin
```

现在服务器已准备好接收应用部署！

## 部署场景

### 1. 应用部署（智能检测环境）

这些命令会根据当前 Git 分支自动选择目标服务器：
- **main 分支** → 部署到 prod
- **其他分支** → 部署到 preview

```bash
# 在 main 分支
mise run deploy-hono        # → prod
mise run deploy-blog        # → prod

# 在 feature-x 分支
mise run deploy-hono        # → preview
mise run deploy-blog        # → preview
```

### 2. 基础设施部署（仅生产环境）

基础设施组件只部署到生产服务器：

```bash
mise run deploy-postgres    # 仅 prod
mise run deploy-redis       # 仅 prod
mise run deploy-caddy       # 仅 prod
mise run deploy-db-admin    # 仅 prod
```

### 3. 预览环境管理

```bash
# 查看当前分支的预览环境信息
mise run preview-info
mise run info              # 别名

# 清理当前分支的预览环境
mise run preview-destroy

# 列出所有预览环境
mise run preview-list
```

### 4. 手动覆盖目标服务器

如果需要手动指定目标服务器，使用环境变量：

```bash
# 强制部署到 preview 服务器（即使在 main 分支）
ANSIBLE_LIMIT=preview mise run deploy-hono

# 同时部署到两台服务器
ANSIBLE_LIMIT=all mise run deploy-hono

# 使用主机组
ANSIBLE_LIMIT=prod_servers mise run deploy-hono
```

### 5. 直接使用 Ansible（高级用户）

```bash
# 部署到指定服务器
ansible-playbook -i ansible/inventory.yml \
  ansible/playbooks/deploy-app.yml \
  -e service_name=hono-demo \
  -l prod

# 部署到所有服务器
ansible-playbook -i ansible/inventory.yml \
  ansible/playbooks/deploy-app.yml \
  -e service_name=hono-demo \
  -l all

# 使用主机组
ansible-playbook -i ansible/inventory.yml \
  ansible/playbooks/deploy-app.yml \
  -e service_name=hono-demo \
  -l preview_servers
```

## Inventory 结构

```yaml
all:
  children:
    prod_servers:        # 生产服务器组
      hosts:
        prod:            # 主机名

    preview_servers:     # 预览服务器组
      hosts:
        preview:         # 主机名
```

### 可用的 limit 目标

- `prod` - 生产服务器（主机名）
- `preview` - 预览服务器（主机名）
- `prod_servers` - 生产服务器组
- `preview_servers` - 预览服务器组
- `all` - 所有服务器

## 工作流示例

### 开发新功能

```bash
# 1. 创建功能分支
git checkout -b feature-new-ui

# 2. 开发代码...

# 3. 查看将要部署的环境
mise run info
# 输出: Preview Environment
#       Domain: feature-new-ui-hono-demo-preview.owenyoung.com

# 4. 部署到预览环境
mise run deploy-hono
# 自动部署到 preview 服务器

# 5. 测试完成，合并到 main
git checkout main
git merge feature-new-ui

# 6. 部署到生产
mise run deploy-hono
# 自动部署到 prod 服务器

# 7. 清理预览环境
git checkout feature-new-ui
mise run preview-destroy
```

### 紧急修复（hotfix）

```bash
# 1. 创建 hotfix 分支
git checkout -b hotfix-critical-bug

# 2. 快速修复...

# 3. 先在预览环境测试
mise run deploy-hono
# 部署到 preview

# 4. 验证修复后，合并到 main
git checkout main
git merge hotfix-critical-bug

# 5. 立即部署到生产
mise run deploy-hono
# 部署到 prod
```

### 多服务同时部署

```bash
# 在 main 分支，部署所有应用到生产
mise run deploy-apps

# 在功能分支，部署所有应用到预览
mise run deploy-apps
```

## 最佳实践

### ✅ 推荐做法

1. **让工具自动检测环境** - 使用 `mise run deploy-*` 命令
2. **功能分支用预览环境** - 合并前充分测试
3. **main 分支用生产环境** - 保持 main 永远可部署
4. **及时清理预览环境** - 合并后运行 `preview-destroy`

### ❌ 避免的做法

1. **不要在 main 分支手动指定 preview** - 容易混淆
2. **不要忘记清理预览环境** - 浪费资源
3. **不要跳过预览直接部署生产** - 先测试再合并

## 故障排查

### 部署到了错误的服务器

检查当前分支：
```bash
git branch --show-current
```

强制覆盖目标：
```bash
ANSIBLE_LIMIT=prod mise run deploy-hono
```

### 预览环境无法访问

1. 检查 DNS 配置：`*-preview.owenyoung.com` 是否指向预览服务器
2. 检查容器状态：`ssh preview "docker ps"`
3. 检查 Caddy 配置：预览配置文件是否生成

### 查看部署日志

```bash
# SSH 到对应服务器
mise run ssh              # prod 服务器 (或 mise run ssh-prod)
mise run ssh-preview      # preview 服务器

# 查看容器日志
cd /srv/studio/js-apps/hono-demo
docker compose logs -f hono-demo
```

## 服务器维护命令速查

### 初始化和配置

| 命令 | 说明 | 目标 |
|------|------|------|
| `mise run server-init-prod` | 初始化生产服务器 | prod |
| `mise run server-init-preview` | 初始化预览服务器 | preview |
| `mise run server-init-all` | 初始化所有服务器 | all |
| `mise run server-configure-aws-prod` | 配置 AWS 凭证（生产） | prod |
| `mise run server-configure-aws-preview` | 配置 AWS 凭证（预览） | preview |
| `mise run server-configure-aws-all` | 配置 AWS 凭证（所有） | all |

### 配置同步

| 命令 | 说明 | 目标 |
|------|------|------|
| `mise run server-sync-config-prod` | 同步配置到生产 | prod |
| `mise run server-sync-config-preview` | 同步配置到预览 | preview |
| `mise run server-sync-config-all` | 同步配置到所有服务器 | all |

### 更新和维护

| 命令 | 说明 | 目标 |
|------|------|------|
| `mise run server-update-prod` | 更新生产服务器配置 | prod |
| `mise run server-update-preview` | 更新预览服务器配置 | preview |
| `mise run server-update-all` | 更新所有服务器配置 | all |
| `mise run server-resize-volume-prod` | 扩展生产服务器磁盘 | prod |
| `mise run server-resize-volume-preview` | 扩展预览服务器磁盘 | preview |

### SSH 连接

| 命令 | 说明 |
|------|------|
| `mise run ssh` 或 `mise run ssh-prod` | SSH 到生产服务器 |
| `mise run ssh-preview` | SSH 到预览服务器 |

## 命名规则总结

### 任务后缀规则

所有服务器管理任务都遵循以下模式：

```
<task-name>-prod      # 仅生产服务器
<task-name>-preview   # 仅预览服务器
<task-name>-all       # 所有服务器（通常有 alias）
```

**例子**：
- `server-init-prod` / `server-init-preview` / `server-init-all` (alias: `server-init`)
- `server-update-prod` / `server-update-preview` / `server-update-all` (alias: `server-update`)
- `server-sync-config-prod` / `server-sync-config-preview` / `server-sync-config-all` (alias: `sync-config`)

### Alias 规则

带 `-all` 后缀的任务通常有简短的 alias：
- `server-init-all` → `server-init`
- `server-configure-aws-all` → `server-configure-aws`
- `server-sync-config-all` → `sync-config`

**为什么？** 大多数情况下你想同时操作两台服务器，所以 `-all` 作为默认行为更方便。
