# 统一数据库策略

## 核心设计：完全统一 ✅

### 所有环境使用相同的用户

```sql
-- 唯一的应用用户（所有环境）
CREATE USER app_user WITH PASSWORD '<password>';

-- 权限
-- - 无 CREATEDB（安全）
-- - 可以完全控制自己 OWNER 的数据库
-- - 不能连接到其他数据库（OWNER 隔离）
```

### 数据库创建统一由 postgres 超级用户完成

```sql
-- 所有环境相同的创建逻辑
CREATE DATABASE <db_name> OWNER app_user;
REVOKE CONNECT ON DATABASE <db_name> FROM PUBLIC;
GRANT CONNECT ON DATABASE <db_name> TO app_user;
```

---

## 凭证管理

### AWS Parameter Store（极简）

```bash
# 本地开发（硬编码）
用户：app_user
密码：dev

# 预览环境（2个参数）
/studio-preview/database/host
/studio-preview/database/app_user_password

# 生产环境（2个参数）
/studio-prod/database/host
/studio-prod/database/app_user_password
```

**总计**：4 个参数（之前需要 20+）

---

## 环境对比

| 维度 | 本地 | 预览 | 生产 |
|------|------|------|------|
| **用户** | app_user | app_user | app_user |
| **密码** | dev（硬编码） | AWS SSM | AWS SSM |
| **CREATEDB** | ❌ 否 | ❌ 否 | ❌ 否 |
| **数据库创建** | postgres | postgres | postgres |
| **自动化** | ✅ 完全 | ✅ 完全 | ✅ 完全 |

**完全统一！** 🎉

---

## 工作流

### 1. 本地开发

```bash
# 首次启动
mise run up                    # PostgreSQL 自动创建 app_user

# 运行迁移
mise run db-migrate-hono       # 自动创建数据库（如果不存在）

# .env 配置
DATABASE_URL=postgresql://app_user:dev@localhost:5432/hono_demo
```

**数据库创建流程**：
```
docker compose up postgres
    ↓
PostgreSQL 初始化
    ↓
/docker-entrypoint-initdb.d/01-init-local-dev.sh
    ↓
调用 db-admin/migrations/local/001-init-local-dev.sh
    ↓
创建 app_user (密码: dev)
    ↓
完成！

pnpm migrate
    ↓
scripts/ensure-database.sh
    ↓
检查数据库是否存在
    ↓
不存在 → psql -U postgres "CREATE DATABASE hono_demo OWNER app_user"
    ↓
node-pg-migrate up（创建表）
```

---

### 2. 预览环境

```bash
# 初始化（一次）
ansible-playbook ... deploy-db-admin.yml -e DEPLOY_ENV=preview -l preview
# 创建 app_user

# 日常部署
git checkout feature-x
mise run deploy-hono           # 自动创建数据库 + 运行迁移

# .env 配置（Ansible 生成）
DATABASE_URL=postgresql://app_user:<from-aws-ssm>@preview-host:5432/feature_x_hono_demo
```

**数据库创建流程**：
```
mise run deploy-hono
    ↓
ansible/playbooks/deploy-app.yml
    ↓
检查数据库是否存在
    ↓
不存在 → docker exec postgres psql -U postgres "CREATE DATABASE ..."
    ↓
运行应用迁移（创建表）
```

---

### 3. 生产环境

```bash
# 初始化（一次）
ansible-playbook ... deploy-db-admin.yml -e DEPLOY_ENV=prod -l prod
# 创建 app_user

# 日常部署
mise run deploy-hono           # 自动创建数据库 + 运行迁移

# .env 配置（Ansible 生成）
DATABASE_URL=postgresql://app_user:<from-aws-ssm>@prod-host:5432/hono_demo
```

**完全相同的流程！**

---

## 安全性

### 权限模型

```sql
-- app_user 无 CREATEDB
-- ✅ 不能随意创建数据库
-- ✅ 不能提升权限

-- OWNER 隔离
-- ✅ app_user 只能连接自己 OWNER 的数据库
-- ✅ 其他数据库默认无法访问（REVOKE CONNECT FROM PUBLIC）

-- 数据库创建由 postgres 控制
-- ✅ 审计性强
-- ✅ 可控性高
```

### 对比分析

| 安全维度 | 独立用户方案 | 统一用户方案 |
|---------|------------|------------|
| 应用间隔离 | 完全隔离 | OWNER 隔离 |
| 权限提升风险 | 低 | 低（无 CREATEDB） |
| 凭证泄露影响 | 单个应用 | 所有应用* |
| 审计追踪 | 高 | 中 |
| 管理复杂度 | 高 | 极低 |

**\* 注意**：虽然凭证泄露影响所有应用，但：
1. OWNER 隔离保证应用间不能互相访问
2. 强密码 + 定期轮换可以缓解
3. 对于小团队，风险可接受

---

## 优势总结

### 1. 凭证管理极简

```bash
# 之前（独立用户）
/studio-prod/database/demo_user_password
/studio-prod/database/demo_readonly_password
/studio-prod/database/hono_user_password
/studio-prod/database/hono_readonly_password
/studio-prod/database/blog_user_password
# ... 每个应用 2-3 个

# 现在（统一用户）
/studio-prod/database/app_user_password  # 1 个！
```

### 2. 初始化脚本极简且统一

```bash
# 之前（独立用户，每个应用一个脚本）
migrations/prod/001-create-demo-db.sh
migrations/prod/002-create-hono-db.sh
migrations/prod/003-create-blog-db.sh
# ... 每个应用一个脚本

# 现在（统一用户，一个脚本搞定所有环境！）
infra-apps/db-admin/migrations/
└── 001-init-app-user.sh                 # 唯一脚本！

# 不再按环境分目录！逻辑完全统一！
# 数据库创建由部署流程自动处理
```

**架构优势**：
- ✅ **postgres 保持干净**：只负责运行 PostgreSQL，不包含业务逻辑
- ✅ **db-admin 集中管理**：所有初始化逻辑在一个脚本
- ✅ **完全统一**：一个脚本适配所有环境（本地/预览/生产）
- ✅ **零重复**：密码从环境变量读取，本地 fallback 到 'dev'
- ✅ **极简维护**：修改逻辑只需要改一个文件

**密码处理**：
```bash
# 统一脚本自动处理所有环境
APP_USER_PASSWORD="${POSTGRES_APP_USER_PASSWORD:-dev}"

# 本地：未设置环境变量 → 使用 'dev'
# 预览：POSTGRES_APP_USER_PASSWORD=<from-aws-ssm>
# 生产：POSTGRES_APP_USER_PASSWORD=<from-aws-ssm>
```

### 3. 配置统一

```bash
# 所有环境 .env 文件格式一致
DATABASE_URL=postgresql://app_user:<password>@<host>:5432/<db_name>

# 只需要改：
# - 密码（dev / aws-ssm）
# - 主机（localhost / preview-host / prod-host）
# - 数据库名（hono_demo / feature_x_hono_demo）
```

### 4. 自动化程度高

```bash
# 所有环境都是自动创建数据库
本地：pnpm migrate → 自动创建
预览：mise run deploy-hono → 自动创建
生产：mise run deploy-hono → 自动创建
```

---

## 迁移指南

### 如果你已有独立用户的数据库

#### 选项 1：保持共存（推荐）

```sql
-- 保留旧用户和数据库
-- 新应用使用 app_user

-- 旧应用
DATABASE_URL=postgresql://hono_user:<old-password>@host/hono_demo

-- 新应用
DATABASE_URL=postgresql://app_user:<new-password>@host/new_app
```

#### 选项 2：迁移到 app_user

```sql
-- 1. 创建 app_user
CREATE USER app_user WITH PASSWORD '<password>';

-- 2. 转移数据库所有权
ALTER DATABASE hono_demo OWNER TO app_user;

-- 3. 更新应用配置
DATABASE_URL=postgresql://app_user:<password>@host/hono_demo

-- 4. 删除旧用户（可选）
DROP USER hono_user;
```

---

## 常见问题

### Q: app_user 能访问所有数据库吗？

**A: 不能！OWNER 隔离保证了安全性。**

```sql
-- hono_demo 的 OWNER 是 app_user
-- blog 的 OWNER 也是 app_user

-- 但它们互相不能访问（除非明确授权）
psql -U app_user -d hono_demo  -- ✅ 成功（自己是 OWNER）
psql -U app_user -d blog       -- ❌ 失败（REVOKE CONNECT FROM PUBLIC）
```

### Q: 为什么不给 app_user CREATEDB 权限？

**A: 安全考虑。**

- 如果有 CREATEDB：应用被攻击后可以创建任意数据库
- 没有 CREATEDB：只有 postgres 超级用户能创建，更可控

而且由 postgres 创建并不影响自动化（脚本自动处理）。

### Q: 本地开发也不能自己创建数据库吗？

**A: 可以！通过 postgres 自动创建。**

```bash
# pnpm migrate 会自动调用
scripts/ensure-database.sh
    ↓
psql -U postgres "CREATE DATABASE ..."  # 自动创建
    ↓
node-pg-migrate up                       # 运行迁移
```

开发者无感知，体验完全一致。

### Q: 密码泄露怎么办？

**A: 定期轮换 + 监控。**

```bash
# 1. 生成新密码
NEW_PASSWORD="$(openssl rand -base64 32)"

# 2. 更新 PostgreSQL
psql -U postgres -c "ALTER USER app_user PASSWORD '$NEW_PASSWORD'"

# 3. 更新 AWS SSM
aws ssm put-parameter --name /studio-prod/database/app_user_password \
  --value "$NEW_PASSWORD" --overwrite

# 4. 重新部署应用（自动拉取新密码）
mise run deploy-hono
```

### Q: 可以回到独立用户模式吗？

**A: 可以！两种模式可以共存。**

```sql
-- app_user 方式（新应用）
CREATE DATABASE new_app OWNER app_user;

-- 独立用户方式（旧应用或特殊需求）
CREATE USER special_app_user WITH PASSWORD 'xxx';
CREATE DATABASE special_app OWNER special_app_user;
```

---

## 总结

### 核心特点

- ✅ **完全统一**：所有环境相同的用户和流程
- ✅ **极简凭证**：从 20+ 个降到 4 个参数
- ✅ **自动创建**：数据库按需自动创建
- ✅ **安全可控**：OWNER 隔离 + 无 CREATEDB
- ✅ **易于维护**：一个初始化脚本搞定

### 适用场景

- ✅ 小型团队（< 20 人）
- ✅ 快速迭代
- ✅ 微服务架构（多个小应用）
- ✅ 预览环境频繁创建/销毁

### 何时考虑独立用户

- 严格的合规要求（审计、隔离）
- 大型团队（> 50 人）
- 多租户 SaaS（每个租户独立用户）
- 敏感数据（金融、医疗）

---

**推荐使用统一用户方案！** 🚀
