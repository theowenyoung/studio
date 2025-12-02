# 数据库创建快速指南

## 两种方式对比

| 特性 | 方式 1: 共享用户 | 方式 2: 独立用户 |
|------|-----------------|-----------------|
| **复杂度** | 简单 | 复杂 |
| **用户管理** | 共享 app_user | 每个应用独立用户 |
| **只读用户** | ❌ | ✅ |
| **隔离性** | 数据库级别 | 用户+数据库级别 |
| **推荐场景** | 开发环境、内部应用 | 生产环境、高安全需求 |
| **示例** | `002-create-hono-demo-db.sh` | `003-create-demo-db-with-dedicated-user.sh` |

---

## 方式 1: 使用共享 app_user（简单）

### 创建步骤

1. **复制模板**：
```bash
cp migrations/002-create-hono-demo-db.sh migrations/004-create-myapp-db.sh
```

2. **修改配置变量**（文件顶部）：
```bash
# 编辑文件
vim migrations/004-create-myapp-db.sh

# 只需修改这一行：
DB_NAME="myapp"  # 改成你的数据库名
```

或使用 sed 批量替换：
```bash
sed -i '' 's/hono_demo/myapp/g' migrations/004-create-myapp-db.sh
```

3. **添加执行权限**：
```bash
chmod +x migrations/004-create-myapp-db.sh
```

4. **运行迁移**：
```bash
mise run dev-db-admin
```

### 脚本结构

```sh
#!/bin/sh
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
. "$SCRIPT_DIR/../scripts/common.sh"

# ==========================================
# Configuration - 只需修改这里
# ==========================================
DB_NAME="myapp"

# ==========================================
# 调用函数创建数据库（不需要修改）
# ==========================================
create_database_with_app_user "$DB_NAME"
```

### 使用数据库

```bash
# 环境变量（使用共享密码）
DATABASE_URL=postgresql://app_user:${POSTGRES_APP_USER_PASSWORD}@localhost:5432/myapp
```

---

## 方式 2: 创建独立用户（安全）

### 创建步骤

1. **复制模板**：
```bash
cp migrations/003-create-demo-db-with-dedicated-user.sh migrations/004-create-myapp-db.sh
```

2. **修改配置变量**（文件顶部）：
```bash
# 编辑文件
vim migrations/004-create-myapp-db.sh

# 修改这些配置变量：
DB_NAME="myapp"
USER_NAME="myapp"
USER_PASSWORD_ENV="POSTGRES_MYAPP_USER_PASSWORD"
READONLY_PASSWORD_ENV="POSTGRES_MYAPP_READONLY_PASSWORD"
```

或使用 sed 批量替换：
```bash
# 将 demo 替换为你的应用名
sed -i '' 's/demo/myapp/g' migrations/004-create-myapp-db.sh
# 将 DEMO 替换为大写的应用名
sed -i '' 's/DEMO/MYAPP/g' migrations/004-create-myapp-db.sh
```

3. **添加执行权限**：
```bash
chmod +x migrations/004-create-myapp-db.sh
```

4. **配置环境变量**：
```bash
# 在 .env.example 中添加模板
cat >> .env.example <<EOF

# MyApp Database
POSTGRES_MYAPP_USER_PASSWORD=
POSTGRES_MYAPP_READONLY_PASSWORD=
EOF

# 在 .env 中添加实际密码
cat >> .env <<EOF

# MyApp Database
POSTGRES_MYAPP_USER_PASSWORD=$(openssl rand -base64 32)
POSTGRES_MYAPP_READONLY_PASSWORD=$(openssl rand -base64 32)
EOF
```

5. **运行迁移**：
```bash
mise run dev-db-admin
```

### 脚本结构

```sh
#!/bin/sh
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
. "$SCRIPT_DIR/../scripts/common.sh"

# ==========================================
# Configuration - 只需修改这里
# ==========================================
DB_NAME="myapp"
USER_NAME="myapp"
USER_PASSWORD_ENV="POSTGRES_MYAPP_USER_PASSWORD"
READONLY_PASSWORD_ENV="POSTGRES_MYAPP_READONLY_PASSWORD"

# ==========================================
# 调用函数创建数据库（不需要修改）
# ==========================================
require_env_var "$USER_PASSWORD_ENV"
require_env_var "$READONLY_PASSWORD_ENV"

eval USER_PASSWORD="\$$USER_PASSWORD_ENV"
eval READONLY_PASSWORD="\$$READONLY_PASSWORD_ENV"

create_database_with_dedicated_users "$DB_NAME" "$USER_NAME" "$USER_PASSWORD" "$READONLY_PASSWORD"
```

### 使用数据库

```bash
# 读写用户
DATABASE_URL=postgresql://myapp:${POSTGRES_MYAPP_USER_PASSWORD}@localhost:5432/myapp

# 只读用户（用于报表、分析等）
DATABASE_URL=postgresql://myapp_readonly:${POSTGRES_MYAPP_READONLY_PASSWORD}@localhost:5432/myapp
```

---

## 实际示例：为 hono-demo 创建数据库

### 使用方式 1（已创建）

```bash
# 文件：migrations/002-create-hono-demo-db.sh
# 数据库名：hono_demo
# 用户：app_user（共享）
# 连接：postgresql://app_user:${POSTGRES_APP_USER_PASSWORD}@localhost:5432/hono_demo
```

### 使用方式 2（已创建示例）

```bash
# 文件：migrations/003-create-demo-db-with-dedicated-user.sh
# 数据库名：demo
# 用户：demo（读写）、demo_readonly（只读）
# 连接：
#   - postgresql://demo:${POSTGRES_DEMO_USER_PASSWORD}@localhost:5432/demo
#   - postgresql://demo_readonly:${POSTGRES_DEMO_READONLY_PASSWORD}@localhost:5432/demo
```

---

## 常见问题

### Q: 我应该选择哪种方式？

**A:**
- 开发环境、内部工具：方式 1（简单快速）
- 生产环境、需要只读访问：方式 2（更安全）

### Q: 如何生成安全密码？

**A:**
```bash
# 生成 32 字符随机密码
openssl rand -base64 32

# 或使用 pwgen
pwgen -s 32 1
```

### Q: 如何查看现有数据库和用户？

**A:**
```bash
# 连接到 PostgreSQL
mise run db-connect

# 查看所有数据库
\l

# 查看所有用户
\du

# 查看当前数据库的权限
\dp
```

### Q: 迁移脚本执行顺序？

**A:**
按文件名字母顺序执行，使用数字前缀控制顺序：
```
001-init-app-user.sh       # 先执行
002-create-hono-demo-db.sh # 再执行
003-create-demo-db.sh      # 最后执行
```

### Q: 可以重复运行迁移吗？

**A:**
可以！所有脚本都使用 `IF NOT EXISTS` 检查，是幂等的。

### Q: 如何为应用配置数据库连接？

**A:**
```bash
# 1. 在应用的 .env.example 中添加
DATABASE_URL=postgresql://user:password@host:5432/dbname

# 2. 使用 psenv 从参数存储获取密码
cd js-apps/myapp
psenv -t .env.example -p "/studio-dev/" -o .env

# 3. 或手动在 .env 中设置
DATABASE_URL=postgresql://app_user:dev@localhost:5432/myapp
```

---

## 部署到生产环境

### 准备环境变量

```bash
# 1. 在 AWS Parameter Store 中存储密码
aws ssm put-parameter \
  --name "/studio-prod/POSTGRES_MYAPP_USER_PASSWORD" \
  --value "$(openssl rand -base64 32)" \
  --type SecureString

aws ssm put-parameter \
  --name "/studio-prod/POSTGRES_MYAPP_READONLY_PASSWORD" \
  --value "$(openssl rand -base64 32)" \
  --type SecureString
```

### 运行迁移

```bash
# 部署数据库管理员任务到生产
mise run deploy-db-admin
```

### 在应用中使用

```bash
# 应用会自动从 Parameter Store 获取密码
# 在应用的 .env.example 中配置：
DATABASE_URL=postgresql://myapp:${POSTGRES_MYAPP_USER_PASSWORD}@postgres.internal:5432/myapp
```
