# Ansible 目标服务器配置指南

## 设计原则

**简化命令：Playbook 中定义默认目标，无需每次都加 `-l` 参数**

```bash
# ✅ 简洁
mise run deploy-postgres

# ❌ 繁琐（旧方式）
mise run deploy-postgres -l prod
```

---

## Playbook 分类策略

### 1. **基础设施 Playbooks** - 默认 `prod_servers`

这些 playbook 默认只在生产服务器运行：

| Playbook | 默认目标 | 原因 |
|----------|---------|------|
| `deploy-infra-postgres.yml` | `prod_servers` | 数据库只在生产 |
| `deploy-infra-redis.yml` | `prod_servers` | Redis 只在生产 |
| `deploy-infra-caddy.yml` | `prod_servers` | Caddy 只在生产 |
| `deploy-infra-backup.yml` | `prod_servers` | 备份只在生产 |
| `deploy-db-admin.yml` | `prod_servers` | 数据库迁移默认生产 |
| `deploy-external-app.yml` | `prod_servers` | 外部应用只在生产 |
| `migrate-app.yml` | `prod_servers` | 应用迁移默认生产 |
| `run-backup.yml` | `prod_servers` | 备份只在生产 |

**Playbook 定义**：
```yaml
---
- name: Deploy PostgreSQL Infrastructure
  hosts: prod_servers  # 默认目标
```

**mise 命令**：
```bash
mise run deploy-postgres    # 自动运行在 prod_servers
mise run deploy-redis        # 自动运行在 prod_servers
mise run deploy-caddy        # 自动运行在 prod_servers
```

**覆盖目标**（如需）：
```bash
ansible-playbook ... -l preview    # 手动指定预览服务器
ansible-playbook ... -l all        # 运行在所有服务器
```

---

### 2. **应用部署 Playbooks** - 智能检测 + 脚本传参

应用部署根据 Git 分支自动选择目标：

| Playbook | 默认目标 | 传参方式 |
|----------|---------|---------|
| `deploy-app.yml` | `all` | 脚本传递 `-l` |

**Playbook 定义**：
```yaml
---
- name: Deploy Application
  hosts: all  # 保持灵活
```

**脚本逻辑** (`scripts/deploy-app.sh`):
```bash
# 检测当前分支
if [ "$CURRENT_BRANCH" = "main" ]; then
    ANSIBLE_TARGET="prod"
else
    ANSIBLE_TARGET="preview"
fi

# 传递 -l 参数
ansible-playbook ... -l $ANSIBLE_TARGET
```

**mise 命令**：
```bash
# 在 main 分支
mise run deploy-hono    # 自动 -l prod

# 在 feature-x 分支
mise run deploy-hono    # 自动 -l preview
```

---

### 3. **服务器管理 Playbooks** - 保持 `all` + 明确的任务分类

服务器管理任务保持 `hosts: all`，通过 mise 任务名明确目标：

| Playbook | 默认目标 | mise 任务 |
|----------|---------|----------|
| `init-server.yml` | `all` | `server-init-prod` / `server-init-preview` / `server-init-all` |
| `sync-server-config.yml` | `all` | `server-sync-config-prod` / `server-sync-config-preview` / `server-sync-config-all` |
| `configure-aws-credentials.yml` | `all` | `server-configure-aws-prod` / `server-configure-aws-preview` / `server-configure-aws-all` |
| `resize.yml` | `all` | `server-resize-volume-prod` / `server-resize-volume-preview` / `server-resize-volume-all` |

**Playbook 定义**：
```yaml
---
- name: Initialize Server
  hosts: all  # 灵活
```

**mise 任务定义**：
```toml
[tasks.server-init-prod]
run = "ansible-playbook ... -l prod"

[tasks.server-init-preview]
run = "ansible-playbook ... -l preview"

[tasks.server-init-all]
run = "ansible-playbook ... -l all"
alias = "server-init"
```

**使用**：
```bash
# 明确指定目标
mise run server-init-prod
mise run server-init-preview

# 默认所有服务器
mise run server-init    # alias for server-init-all
```

---

### 4. **特殊 Playbooks** - 支持变量覆盖

某些 playbook 需要更灵活的控制：

| Playbook | 默认目标 | 覆盖方式 |
|----------|---------|---------|
| `deploy-infra-caddy-reload.yml` | `prod_servers` | `-e target_host=preview` |

**Playbook 定义**：
```yaml
---
- name: Reload Caddy Configuration
  hosts: "{{ target_host | default('prod_servers') }}"  # 支持变量
```

**使用**：
```bash
# 默认生产
ansible-playbook ansible/playbooks/deploy-infra-caddy-reload.yml

# 覆盖到预览
ansible-playbook ansible/playbooks/deploy-infra-caddy-reload.yml -e target_host=preview

# 或用 -l（更直接）
ansible-playbook ansible/playbooks/deploy-infra-caddy-reload.yml -l preview
```

---

## 命令速查表

### 基础设施部署（自动 prod）

```bash
mise run deploy-postgres     # → prod_servers
mise run deploy-redis        # → prod_servers
mise run deploy-caddy        # → prod_servers
mise run deploy-db-admin     # → prod_servers
mise run deploy-meilisearch  # → prod_servers
mise run backup              # → prod_servers
```

### 应用部署（自动检测分支）

```bash
# 在 main 分支
mise run deploy-hono         # → prod

# 在 feature-x 分支
mise run deploy-hono         # → preview
```

### 服务器管理（明确指定）

```bash
# 单个服务器
mise run server-init-prod
mise run server-init-preview

# 所有服务器（推荐）
mise run server-init         # alias for server-init-all
mise run sync-config         # alias for server-sync-config-all
mise run server-configure-aws # alias for server-configure-aws-all
```

---

## `-l` 参数总结

### 何时不需要 `-l`

**基础设施任务**：
- Playbook 中已定义 `hosts: prod_servers`
- mise 任务无需加 `-l`

**应用部署任务**：
- 脚本自动检测分支并传递 `-l`
- 用户无需关心

### 何时需要 `-l`

**服务器管理任务**：
- Playbook 保持 `hosts: all`
- mise 任务通过 `-l` 明确目标

**手动覆盖**：
- 直接使用 `ansible-playbook` 命令时
- 需要覆盖默认行为时

---

## 最佳实践

### ✅ 推荐

1. **使用 mise 任务** - 封装了正确的参数
   ```bash
   mise run deploy-postgres    # 简洁
   ```

2. **让工具自动处理** - 应用部署自动检测分支
   ```bash
   mise run deploy-hono        # 自动选择环境
   ```

3. **明确的任务命名** - 服务器管理任务带后缀
   ```bash
   mise run server-init-prod   # 清晰明确
   ```

### ❌ 避免

1. **手动加 `-l` 到 mise 任务**
   ```bash
   # ❌ 不需要（playbook 已有默认值）
   mise run deploy-postgres -l prod

   # ✅ 直接用
   mise run deploy-postgres
   ```

2. **直接调用 ansible-playbook 而不理解目标**
   ```bash
   # ❌ 不理解会运行在哪里
   ansible-playbook ansible/playbooks/deploy-infra-postgres.yml

   # ✅ 先检查 playbook 的 hosts 定义
   # hosts: prod_servers → 只在生产
   # hosts: all → 所有服务器（需要 -l 限制）
   ```

---

## 故障排查

### 问题：不知道会运行在哪台服务器

**解决**：
1. 检查 playbook 的 `hosts:` 定义
   ```bash
   head -3 ansible/playbooks/deploy-infra-postgres.yml
   ```

2. 使用 `--list-hosts` 预览
   ```bash
   ansible-playbook ansible/playbooks/deploy-infra-postgres.yml --list-hosts
   ```

### 问题：想覆盖默认目标

**解决**：
```bash
# 方法 1：使用 -l 参数
ansible-playbook ansible/playbooks/deploy-infra-postgres.yml -l preview

# 方法 2：使用 -e 变量（如果 playbook 支持）
ansible-playbook ansible/playbooks/deploy-infra-caddy-reload.yml -e target_host=preview
```

### 问题：想同时运行在所有服务器

**解决**：
```bash
# 对于 hosts: all 的 playbook（无需改动）
ansible-playbook ansible/playbooks/init-server.yml

# 对于 hosts: prod_servers 的 playbook（需要覆盖）
ansible-playbook ansible/playbooks/deploy-infra-postgres.yml -l all
```

---

## 总结

| 任务类型 | Playbook hosts | mise 任务 | 是否需要 -l |
|---------|---------------|-----------|-----------|
| 基础设施部署 | `prod_servers` | `deploy-postgres` | ❌ 不需要 |
| 应用部署 | `all` | `deploy-hono` | ❌ 脚本处理 |
| 服务器管理 | `all` | `server-init-prod` | ✅ 在任务中 |

**核心思想**：
- ✅ Playbook 定义合理的默认值
- ✅ mise 任务封装正确的参数
- ✅ 用户无需关心 `-l` 的细节
