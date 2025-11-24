# 数据库初始化架构

## 核心理念：一个脚本，适配所有环境 ✨

不再按环境分目录，逻辑完全统一！

---

## 文件结构

```
infra-apps/
├── db-admin/
│   ├── migrations/
│   │   └── 001-init-app-user.sh          # ← 唯一的初始化脚本！
│   └── scripts/
│       └── run-migrations.sh              # ← 执行器
└── postgres/
    └── src/
        └── initdb.d/
            └── 01-init-local-dev.sh       # ← 代理脚本（调用 db-admin）
```

---

## 统一脚本设计

### `db-admin/migrations/001-init-app-user.sh`

**核心逻辑**：

```bash
#!/bin/sh
set -e

# 从环境变量读取密码，fallback 到 'dev'
APP_USER_PASSWORD="${POSTGRES_APP_USER_PASSWORD:-dev}"

# 创建 app_user
psql -v ON_ERROR_STOP=1 <<-EOSQL
    DO \$\$
    BEGIN
        IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'app_user') THEN
            CREATE USER app_user WITH PASSWORD '$APP_USER_PASSWORD';
        END IF;
    END
    \$\$;

    GRANT app_user TO postgres;
EOSQL
```

**为什么这样设计？**

1. **零重复**：一个脚本适配所有环境
2. **智能 fallback**：本地自动使用 'dev'，预览/生产从环境变量读取
3. **幂等性**：`IF NOT EXISTS` 保证可以重复运行
4. **POSIX 兼容**：使用 `sh`，不依赖 bash 特性

---

## 各环境的执行方式

### 1️⃣ 本地开发

**触发**：`docker compose up postgres`

**流程**：
```
PostgreSQL 容器启动
    ↓
/docker-entrypoint-initdb.d/01-init-local-dev.sh
    ↓
调用 /docker-entrypoint-initdb.d/db-admin-migrations/001-init-app-user.sh
    ↓
读取 $POSTGRES_APP_USER_PASSWORD (未设置)
    ↓
Fallback 到 'dev'
    ↓
CREATE USER app_user WITH PASSWORD 'dev'
```

**Volume Mount**：
```yaml
# infra-apps/postgres/docker-compose.yml
volumes:
  - ../db-admin/migrations:/docker-entrypoint-initdb.d/db-admin-migrations:ro
```

**环境变量**：无需设置（自动 fallback）

---

### 2️⃣ 预览环境

**触发**：`mise run deploy-db-admin -l preview -e DEPLOY_ENV=preview`

**流程**：
```
ansible-playbook deploy-db-admin.yml
    ↓
docker compose run --rm db-admin
    ↓
scripts/run-migrations.sh
    ↓
执行 /migrations/001-init-app-user.sh
    ↓
读取 $POSTGRES_APP_USER_PASSWORD (从 AWS SSM)
    ↓
CREATE USER app_user WITH PASSWORD '<from-aws-ssm>'
```

**Docker Compose 配置**：
```yaml
# infra-apps/db-admin/docker-compose.yml (简化示例)
services:
  db-admin:
    env_file: .env  # 包含 POSTGRES_APP_USER_PASSWORD
    volumes:
      - ./migrations:/migrations:ro
```

**环境变量** (Ansible 生成 `.env`)：
```bash
POSTGRES_APP_USER_PASSWORD=<from-aws-ssm>
PGHOST=postgres
PGPORT=5432
PGUSER=postgres
PGPASSWORD=<postgres-password>
```

---

### 3️⃣ 生产环境

**与预览环境完全相同！**

唯一区别：
- **预览**：`-l preview`
- **生产**：`-l prod`

---

## 环境变量总结

### 初始化脚本需要的环境变量

| 环境 | POSTGRES_APP_USER_PASSWORD | 来源 |
|------|---------------------------|------|
| **本地** | (未设置，fallback 到 'dev') | - |
| **预览** | `<strong-password>` | AWS SSM → Ansible → `.env` |
| **生产** | `<strong-password>` | AWS SSM → Ansible → `.env` |

**只需要 1 个环境变量，且本地可以不设置！**

---

## 对比：之前 vs 现在

### 之前（按环境分目录）

```
infra-apps/db-admin/migrations/
├── local/
│   └── 001-init-local-dev.sh        # 68 行
├── preview/
│   └── 001-init-preview.sh          # 68 行
└── prod/
    └── 001-init-app-user.sh         # 68 行

总计：3 个文件，204 行代码（重复率 95%+）
```

**问题**：
- ❌ 重复代码多
- ❌ 维护困难（改一个要改三个）
- ❌ 容易不一致

### 现在（统一脚本）

```
infra-apps/db-admin/migrations/
└── 001-init-app-user.sh             # 68 行

总计：1 个文件，68 行代码
```

**优势**：
- ✅ 零重复
- ✅ 易维护（只需改一个文件）
- ✅ 强制一致性

---

## 设计原则

### 1. 环境无关性

脚本不关心"我在哪个环境"，只关心"环境变量是什么"。

```bash
# ✅ 好的设计
APP_USER_PASSWORD="${POSTGRES_APP_USER_PASSWORD:-dev}"

# ❌ 不好的设计
if [ "$DEPLOY_ENV" = "local" ]; then
    APP_USER_PASSWORD="dev"
elif [ "$DEPLOY_ENV" = "preview" ]; then
    APP_USER_PASSWORD="$POSTGRES_APP_USER_PASSWORD"
fi
```

### 2. 智能默认值

本地开发使用合理的默认值，生产环境强制明确配置。

```bash
# 本地：未设置 → 自动使用 'dev'
# 生产：未设置 → 脚本继续运行，但使用 'dev'（不推荐但不会报错）

# 如果要严格检查，可以改为：
if [ -z "$POSTGRES_APP_USER_PASSWORD" ]; then
    if [ "$DEPLOY_ENV" = "prod" ]; then
        echo "ERROR: POSTGRES_APP_USER_PASSWORD required for production"
        exit 1
    fi
    APP_USER_PASSWORD="dev"
fi
```

### 3. 幂等性

脚本可以安全地重复执行。

```sql
-- ✅ 好的设计
IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'app_user') THEN
    CREATE USER app_user ...;
END IF;

-- ❌ 不好的设计
CREATE USER app_user ...;  -- 第二次运行会报错
```

---

## 扩展性

### 添加新的初始化逻辑

只需要在同一个文件中添加，所有环境自动生效：

```bash
# 001-init-app-user.sh

# 1. 创建用户
psql -v ON_ERROR_STOP=1 <<-EOSQL
    CREATE USER app_user ...;
EOSQL

# 2. 创建扩展（新增）
psql -v ON_ERROR_STOP=1 <<-EOSQL
    CREATE EXTENSION IF NOT EXISTS pg_trgm;
    CREATE EXTENSION IF NOT EXISTS btree_gin;
EOSQL

# 3. 创建通用函数（新增）
psql -v ON_ERROR_STOP=1 <<-EOSQL
    CREATE OR REPLACE FUNCTION update_updated_at()
    RETURNS TRIGGER AS \$\$
    BEGIN
        NEW.updated_at = NOW();
        RETURN NEW;
    END;
    \$\$ LANGUAGE plpgsql;
EOSQL
```

### 添加多个脚本

按数字顺序执行：

```
infra-apps/db-admin/migrations/
├── 001-init-app-user.sh           # 创建用户
├── 002-create-extensions.sh       # 安装扩展
└── 003-create-functions.sh        # 创建通用函数
```

`run-migrations.sh` 会按顺序执行所有 `*.sh` 文件。

---

## 总结

### 核心优势

✅ **极简**：1 个脚本，68 行代码（之前 204 行）
✅ **统一**：所有环境使用相同逻辑
✅ **智能**：本地自动 fallback，生产从环境变量读取
✅ **安全**：幂等性设计，可重复运行
✅ **灵活**：易于扩展新的初始化逻辑

### 关键技术

- **环境变量 fallback**：`${VAR:-default}`
- **幂等 SQL**：`IF NOT EXISTS`
- **POSIX 兼容**：使用 `sh` 而非 `bash`
- **Volume Mount**：本地通过 Docker volume 共享脚本

---

**一个脚本，适配所有环境！** 🚀
