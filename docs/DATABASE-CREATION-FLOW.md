# 数据库创建流程

## 概览

不同环境下数据库的创建时机和方式：

| 环境 | 用户创建 | 数据库创建 | 表创建 | 时机 |
|------|---------|-----------|-------|------|
| **本地开发** | 容器启动时（自动） | 应用迁移前（自动） | 应用迁移（手动触发） | 开发时 |
| **预览环境** | 初始化时（一次） | 应用部署前（自动） | 应用迁移（部署时） | 每次部署 |
| **生产环境** | 初始化时（一次） | 初始化时（一次） | 应用迁移（手动触发） | 初始化和部署时 |

---

## 1. 本地开发环境

### 流程图

```
Docker 启动 PostgreSQL
    ↓
执行 initdb.d/01-init-local-dev.sh
    ↓
创建 local_dev 用户 (CREATEDB 权限)
    ↓
创建 template_local 数据库
    ↓
开发者运行 pnpm migrate (或 mise run db-migrate-hono)
    ↓
scripts/ensure-database.sh 检查并创建数据库
    ↓
node-pg-migrate 运行应用迁移（创建表）
```

### 详细步骤

#### 步骤 1：PostgreSQL 容器启动（自动）

```bash
mise run dev-up-postgres
```

**执行**：
```sql
-- infra-apps/postgres/src/initdb.d/01-init-local-dev.sh
CREATE USER local_dev WITH PASSWORD 'dev' CREATEDB;
CREATE DATABASE template_local OWNER local_dev;
UPDATE pg_database SET datistemplate = TRUE WHERE datname = 'template_local';
```

**结果**：
- ✅ `local_dev` 用户（密码：`dev`，有 CREATEDB 权限）
- ✅ `template_local` 模板数据库

#### 步骤 2：应用迁移（手动触发）

```bash
# 单个应用
pnpm --filter "./js-apps/hono-demo" migrate

# 或使用 mise
mise run db-migrate-hono

# 所有应用
mise run db-migrate
```

**执行**：
1. `scripts/ensure-database.sh` 检查 `hono_demo` 数据库
   - 不存在：使用 `local_dev` 创建（因为有 CREATEDB 权限）
   - 存在：跳过

2. `node-pg-migrate up` 运行迁移
   - 创建表：`posts`
   - 执行种子数据

**结果**：
- ✅ `hono_demo` 数据库（如果不存在）
- ✅ 表和数据

### 命令总结

```bash
# 首次启动
mise run up                    # 启动所有基础设施（包括 PostgreSQL）
mise run db-migrate-hono       # 创建数据库 + 运行迁移

# 日常开发
mise run dev-hono              # 直接启动（数据库已存在）

# 重置数据库
psql -U postgres -c "DROP DATABASE hono_demo"
mise run db-migrate-hono       # 重新创建
```

---

## 2. 预览环境

### 流程图

```
初始化预览服务器（一次）
    ↓
mise run deploy-db-admin (DEPLOY_ENV=preview)
    ↓
执行 migrations/preview/001-init-preview.sh
    ↓
创建 preview_app_user (CREATEDB 权限)
    ↓
创建 template_preview 数据库
    ↓
─────────────────────────────
分支部署（每次）
    ↓
mise run deploy-hono (在 feature-x 分支)
    ↓
deploy-app.yml 检查 feature_x_hono_demo 数据库
    ↓
不存在：CREATE DATABASE ... OWNER preview_app_user
    ↓
运行应用迁移（创建表）
```

### 详细步骤

#### 步骤 1：初始化预览环境（一次性）

```bash
# 在 preview 服务器上
ansible-playbook -i ansible/inventory.yml \
  ansible/playbooks/deploy-db-admin.yml \
  -e DEPLOY_ENV=preview \
  -l preview
```

**执行**：
```sql
-- infra-apps/db-admin/migrations/preview/001-init-preview.sh
CREATE USER preview_app_user WITH PASSWORD '<from-aws-ssm>' CREATEDB;
GRANT preview_app_user TO postgres;
CREATE DATABASE template_preview OWNER preview_app_user;
UPDATE pg_database SET datistemplate = TRUE WHERE datname = 'template_preview';
```

**结果**：
- ✅ `preview_app_user` 用户（有 CREATEDB 权限）
- ✅ `template_preview` 模板数据库

#### 步骤 2：分支部署（每次）

```bash
# 开发者在功能分支
git checkout feature-user-dashboard
mise run deploy-hono
```

**执行**：
```yaml
# ansible/playbooks/deploy-app.yml
- name: Ensure database exists (preview environment only)
  shell: |
    docker exec postgres psql -U postgres -c "
    SELECT 1 FROM pg_database WHERE datname='feature_user_dashboard_hono_demo'
    " | grep -q 1 || \
    docker exec postgres psql -U postgres -c "
    CREATE DATABASE feature_user_dashboard_hono_demo
      WITH OWNER = preview_app_user
      TEMPLATE = template_preview
    "
  when: target_env == 'preview'
```

然后运行应用迁移（如果 docker-compose.yml 中配置了 migrate profile）。

**结果**：
- ✅ `feature_user_dashboard_hono_demo` 数据库
- ✅ 表和数据

### 命令总结

```bash
# 初始化（一次）
ansible-playbook -i ansible/inventory.yml \
  ansible/playbooks/deploy-db-admin.yml \
  -e DEPLOY_ENV=preview \
  -l preview

# 分支部署（每次）
git checkout feature-x
mise run deploy-hono           # 自动创建数据库 + 运行迁移

# 清理
mise run preview-destroy       # 删除数据库 + 容器 + 配置
```

---

## 3. 生产环境

### 流程图

```
初始化生产服务器（一次）
    ↓
mise run deploy-db-admin (DEPLOY_ENV=prod)
    ↓
执行 migrations/prod/*.sh
    ↓
001-create-demo-db.sh → demo_user + demo 数据库
002-create-hono-db.sh → hono_user + hono_demo 数据库
...
    ↓
─────────────────────────────
应用部署（每次）
    ↓
mise run deploy-hono (在 main 分支)
    ↓
应用容器启动
    ↓
运行应用迁移（创建/更新表）
```

### 详细步骤

#### 步骤 1：初始化生产环境（一次性）

```bash
# 在 prod 服务器上
ansible-playbook -i ansible/inventory.yml \
  ansible/playbooks/deploy-db-admin.yml \
  -e DEPLOY_ENV=prod \
  -l prod
```

**执行**：
```bash
# migrations/prod/001-create-demo-db.sh
CREATE USER demo_user WITH PASSWORD '<from-aws-ssm>';
CREATE USER demo_readonly WITH PASSWORD '<from-aws-ssm>';
CREATE DATABASE demo OWNER demo_user;
GRANT CONNECT ON DATABASE demo TO demo_readonly;

# migrations/prod/002-create-hono-db.sh
CREATE USER hono_user WITH PASSWORD '<from-aws-ssm>';
CREATE USER hono_readonly WITH PASSWORD '<from-aws-ssm>';
CREATE DATABASE hono_demo OWNER hono_user;
GRANT CONNECT ON DATABASE hono_demo TO hono_readonly;
```

**结果**：
- ✅ 所有应用的用户和数据库
- ✅ 读写用户 + 只读用户

#### 步骤 2：应用部署（每次）

```bash
# 在 main 分支
mise run deploy-hono
```

数据库已存在，直接运行应用迁移。

### 命令总结

```bash
# 初始化（一次）
ansible-playbook -i ansible/inventory.yml \
  ansible/playbooks/deploy-db-admin.yml \
  -e DEPLOY_ENV=prod \
  -l prod

# 应用部署（每次）
mise run deploy-hono           # 数据库已存在，只运行迁移

# 添加新应用数据库
# 1. 创建 migrations/prod/003-create-new-app-db.sh
# 2. 运行 mise run deploy-db-admin
```

---

## 关键机制对比

### 用户权限

| 环境 | 用户 | CREATEDB | 说明 |
|------|------|---------|------|
| 本地 | `local_dev` | ✅ 是 | 可以自己创建数据库 |
| 预览 | `preview_app_user` | ✅ 是 | 可以自己创建数据库 |
| 生产 | `hono_user` 等 | ❌ 否 | 数据库由初始化脚本创建 |

### 数据库创建时机

| 环境 | 创建时机 | 创建者 | 自动化 |
|------|---------|-------|-------|
| 本地 | 应用迁移前 | `local_dev` | ✅ 完全自动 |
| 预览 | 应用部署前 | Ansible playbook | ✅ 完全自动 |
| 生产 | 初始化时 | 初始化脚本 | ⚠️ 手动触发 |

### 清理策略

| 环境 | 删除数据库 | 删除用户 |
|------|-----------|---------|
| 本地 | 手动 `DROP DATABASE` | 不删除（复用） |
| 预览 | `mise run preview-destroy` | 不删除（复用） |
| 生产 | 手动（很少） | 手动（很少） |

---

## 故障排查

### 问题 1：本地迁移报错 "database does not exist"

**原因**：数据库不存在，`ensure-database.sh` 未成功创建。

**解决**：

```bash
# 检查 local_dev 用户是否有 CREATEDB 权限
psql -U postgres -c "\du local_dev"

# 如果没有，重新初始化 PostgreSQL
mise run dev-down-postgres
docker volume rm postgres_postgres_data
mise run dev-up-postgres

# 或手动创建数据库
psql -U postgres -c "CREATE DATABASE hono_demo OWNER local_dev"
```

### 问题 2：预览环境数据库未自动创建

**原因**：
1. `preview_app_user` 不存在
2. Ansible playbook 逻辑有误

**解决**：

```bash
# 1. 检查用户是否存在
ssh preview "docker exec postgres psql -U postgres -c '\du preview_app_user'"

# 2. 如果不存在，重新初始化
ansible-playbook -i ansible/inventory.yml \
  ansible/playbooks/deploy-db-admin.yml \
  -e DEPLOY_ENV=preview \
  -l preview

# 3. 手动创建数据库（临时）
ssh preview "docker exec postgres psql -U postgres -c \
  'CREATE DATABASE feature_x_hono_demo OWNER preview_app_user'"
```

### 问题 3：生产环境新应用数据库缺失

**原因**：忘记运行初始化脚本。

**解决**：

```bash
# 1. 创建迁移脚本
cat > infra-apps/db-admin/migrations/prod/003-create-storefront-db.sh <<'EOF'
#!/bin/sh
set -e
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
. "$SCRIPT_DIR/../../scripts/common.sh"

DB_NAME="storefront"
RW_PASSWORD="${POSTGRES_STOREFRONT_USER_PASSWORD:?Error: not set}"
RO_PASSWORD="${POSTGRES_STOREFRONT_READONLY_PASSWORD:?Error: not set}"

create_database_with_users "$DB_NAME" "$RW_PASSWORD" "$RO_PASSWORD" "Storefront"
EOF

chmod +x infra-apps/db-admin/migrations/prod/003-create-storefront-db.sh

# 2. 添加 AWS Parameter Store 凭证
aws ssm put-parameter --name /studio-prod/database/storefront_user_password \
  --value "<password>" --type SecureString

aws ssm put-parameter --name /studio-prod/database/storefront_readonly_password \
  --value "<password>" --type SecureString

# 3. 运行迁移
ansible-playbook -i ansible/inventory.yml \
  ansible/playbooks/deploy-db-admin.yml \
  -e DEPLOY_ENV=prod \
  -l prod
```

---

## 最佳实践

### ✅ 推荐

1. **本地开发**：让 `ensure-database.sh` 自动处理
   ```bash
   # 只需运行
   mise run db-migrate-hono
   ```

2. **预览环境**：依赖自动化流程
   ```bash
   # 不需要手动创建数据库
   mise run deploy-hono
   ```

3. **生产环境**：明确的初始化步骤
   ```bash
   # 新应用前先创建迁移脚本
   # 然后运行初始化
   mise run deploy-db-admin
   ```

### ❌ 避免

1. **不要手动创建本地数据库**
   ```bash
   # ❌ 不推荐（虽然可以工作）
   psql -U postgres -c "CREATE DATABASE hono_demo"

   # ✅ 推荐（自动化）
   pnpm migrate
   ```

2. **不要在预览环境手动创建数据库**
   - 应该由 Ansible playbook 自动处理
   - 如果失败，检查初始化是否正确

3. **不要在生产环境跳过初始化**
   - 必须先创建用户和数据库
   - 然后再部署应用

---

## 总结

### 核心差异

**本地和预览**：
- 共享用户有 CREATEDB 权限
- 数据库按需自动创建
- 开发体验优先

**生产环境**：
- 独立用户无 CREATEDB 权限
- 数据库预先创建
- 安全性和可控性优先

### 自动化程度

```
本地开发：  ████████████ 100% 自动（容器 + 迁移）
预览环境：  ██████████░░  90% 自动（需要初始化）
生产环境：  ████░░░░░░░░  40% 自动（需要迁移脚本）
```

### 命令速查

```bash
# 本地
mise run db-migrate-hono              # 创建 + 迁移

# 预览（首次）
ansible-playbook ... deploy-db-admin.yml -e DEPLOY_ENV=preview -l preview

# 预览（日常）
mise run deploy-hono                  # 自动创建 + 迁移

# 生产（首次）
ansible-playbook ... deploy-db-admin.yml -e DEPLOY_ENV=prod -l prod

# 生产（日常）
mise run deploy-hono                  # 只迁移（数据库已存在）
```
