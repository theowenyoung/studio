# 数据库迁移脚本指南

## 架构设计

### 核心原则

1. **配置与逻辑分离**：所有可配置的变量都放在脚本顶部的 Configuration 区域
2. **函数封装**：所有通用逻辑都封装在 `scripts/common.sh` 中
3. **可复用性**：通过复制模板并修改顶部变量即可创建新数据库
4. **清晰的命名**：变量名和函数名清晰表达其用途

### 文件结构

```
db-admin/
├── scripts/
│   └── common.sh              # 通用函数库
├── migrations/
│   ├── 001-init-app-user.sh   # 创建共享 app_user
│   ├── 002-*.sh               # 使用共享用户的数据库
│   └── 003-*.sh               # 使用独立用户的数据库
├── README.md                  # 完整文档
├── QUICK-START.md             # 快速参考
└── MIGRATION-GUIDE.md         # 本文档
```

---

## 通用函数（common.sh）

### 1. 日志函数

```sh
log "message"           # 普通日志
log_error "message"     # 错误日志（输出到 stderr）
log_success "message"   # 成功日志
```

### 2. 环境变量验证

```sh
require_env_var "VAR_NAME"
# 检查环境变量是否设置，未设置则报错退出
```

### 3. 创建数据库（共享用户）

```sh
create_database_with_app_user "DB_NAME"
# 使用共享的 app_user 创建数据库
# 适合大多数应用场景
```

### 4. 创建数据库（独立用户）

```sh
create_database_with_dedicated_users "DB_NAME" "USER_NAME" "USER_PASSWORD" "READONLY_PASSWORD"
# 创建独立的用户和数据库
# 包含读写用户和只读用户
# 适合高安全需求场景
```

---

## 迁移脚本模板

### 模板 1: 共享用户（简单）

**文件名**：`00X-create-APPNAME-db.sh`

```sh
#!/bin/sh
set -e

# Source the functions library
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
. "$SCRIPT_DIR/../scripts/common.sh"

# ==========================================
# Configuration - Modify these variables
# ==========================================
DB_NAME="your_database_name"

# ==========================================
# Create Database with Shared app_user
# ==========================================
# Uses shared app_user (created in 001-init-app-user.sh)
# ==========================================

create_database_with_app_user "$DB_NAME"
```

**特点**：
- 只需修改 `DB_NAME` 变量
- 使用共享的 `app_user`
- 最简单的方式

**环境变量需求**：
- `POSTGRES_APP_USER_PASSWORD`（在 001 迁移中配置）

---

### 模板 2: 独立用户（安全）

**文件名**：`00X-create-APPNAME-db-with-dedicated-user.sh`

```sh
#!/bin/sh
set -e

# Source the functions library
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
. "$SCRIPT_DIR/../scripts/common.sh"

# ==========================================
# Configuration - Modify these variables
# ==========================================
DB_NAME="your_database_name"
USER_NAME="your_user_name"
USER_PASSWORD_ENV="POSTGRES_YOURAPP_USER_PASSWORD"
READONLY_PASSWORD_ENV="POSTGRES_YOURAPP_READONLY_PASSWORD"

# ==========================================
# Create Dedicated Database with Users
# ==========================================
# Creates separate user and database for better isolation
# ==========================================

# Validate required environment variables
require_env_var "$USER_PASSWORD_ENV"
require_env_var "$READONLY_PASSWORD_ENV"

# Get passwords from environment
eval USER_PASSWORD="\$$USER_PASSWORD_ENV"
eval READONLY_PASSWORD="\$$READONLY_PASSWORD_ENV"

# Create database with dedicated users
create_database_with_dedicated_users "$DB_NAME" "$USER_NAME" "$USER_PASSWORD" "$READONLY_PASSWORD"
```

**特点**：
- 配置集中在顶部 4 个变量
- 创建独立的读写和只读用户
- 更高的安全性和隔离性

**环境变量需求**：
- `POSTGRES_YOURAPP_USER_PASSWORD`
- `POSTGRES_YOURAPP_READONLY_PASSWORD`

---

## 创建新数据库的步骤

### 方式 1: 使用共享用户

```bash
# 1. 复制模板
cp migrations/002-create-hono-demo-db.sh migrations/004-create-myapp-db.sh

# 2. 修改配置（只需改 DB_NAME）
sed -i '' 's/hono_demo/myapp/g' migrations/004-create-myapp-db.sh

# 3. 添加执行权限
chmod +x migrations/004-create-myapp-db.sh

# 4. 运行迁移
mise run db-init
```

### 方式 2: 使用独立用户

```bash
# 1. 复制模板
cp migrations/003-create-demo-db-with-dedicated-user.sh migrations/004-create-myapp-db.sh

# 2. 批量替换名称
sed -i '' 's/demo/myapp/g' migrations/004-create-myapp-db.sh
sed -i '' 's/DEMO/MYAPP/g' migrations/004-create-myapp-db.sh

# 3. 添加执行权限
chmod +x migrations/004-create-myapp-db.sh

# 4. 配置环境变量
cat >> .env <<EOF
POSTGRES_MYAPP_USER_PASSWORD=$(openssl rand -base64 32)
POSTGRES_MYAPP_READONLY_PASSWORD=$(openssl rand -base64 32)
EOF

# 5. 运行迁移
mise run db-init
```

---

## 迁移执行流程

### 执行顺序

迁移脚本按文件名字母顺序执行：

1. `001-init-app-user.sh` - 创建共享的 app_user
2. `002-*` - 应用数据库（使用共享用户）
3. `003-*` - 应用数据库（使用独立用户）
4. `004-*` - 更多数据库...

### 幂等性

所有迁移脚本都是幂等的（可重复执行）：
- 使用 `IF NOT EXISTS` 检查
- 如果资源已存在，跳过创建
- 可以安全地重复运行

### 运行命令

```bash
# 本地开发环境
mise run db-init

# 或直接使用 docker compose
cd infra-apps/db-admin
docker compose run --rm db-admin

# 生产环境部署
mise run deploy-db-admin
```

---

## 变量命名约定

### 数据库名

- 使用下划线分隔：`hono_demo`、`myapp`
- 小写字母
- 推荐使用应用名作为数据库名

### 用户名

对于共享用户方式：
- 固定使用 `app_user`

对于独立用户方式：
- 读写用户：与数据库名相同，如 `demo`
- 只读用户：添加 `_readonly` 后缀，如 `demo_readonly`

### 环境变量名

- 格式：`POSTGRES_<APPNAME>_<TYPE>_PASSWORD`
- 例子：
  - `POSTGRES_DEMO_USER_PASSWORD`
  - `POSTGRES_DEMO_READONLY_PASSWORD`
  - `POSTGRES_MYAPP_USER_PASSWORD`

---

## 最佳实践

### 1. 选择合适的方式

- **开发环境**：优先使用共享用户（方式 1）
- **生产环境**：
  - 普通应用：共享用户即可
  - 关键应用：使用独立用户（方式 2）
  - 需要只读访问：必须使用独立用户（方式 2）

### 2. 密码管理

```bash
# 生成安全密码
openssl rand -base64 32

# 存储在 AWS Parameter Store
aws ssm put-parameter \
  --name "/studio-prod/POSTGRES_MYAPP_USER_PASSWORD" \
  --value "$(openssl rand -base64 32)" \
  --type SecureString

# 应用自动从 Parameter Store 获取
psenv -t .env.example -p "/studio-prod/" -o .env
```

### 3. 迁移文件命名

- 使用三位数字前缀：`001-`, `002-`, `003-`
- 描述性名称：`create-<appname>-db.sh`
- 例子：
  - `001-init-app-user.sh`
  - `002-create-hono-demo-db.sh`
  - `003-create-demo-db-with-dedicated-user.sh`

### 4. 测试迁移

```bash
# 在本地测试
mise run db-init

# 验证数据库创建
mise run db-connect
\l              # 列出所有数据库
\du             # 列出所有用户
\c myapp        # 连接到数据库
\dt             # 列出表（如果有）
```

---

## 故障排查

### 问题：环境变量未设置

**错误信息**：
```
❌ Error: POSTGRES_MYAPP_USER_PASSWORD environment variable is required
```

**解决方案**：
```bash
# 设置环境变量
export POSTGRES_MYAPP_USER_PASSWORD="your-password"

# 或在 .env 文件中添加
echo "POSTGRES_MYAPP_USER_PASSWORD=your-password" >> .env
```

### 问题：权限被拒绝

**错误信息**：
```
permission denied to create database
```

**解决方案**：
- 确保以 postgres 用户身份运行
- 检查 Docker Compose 配置中的 `POSTGRES_USER`

### 问题：数据库已存在

这不是错误！迁移脚本设计为幂等的，会跳过已存在的资源。

---

## 扩展阅读

- PostgreSQL 用户管理：https://www.postgresql.org/docs/current/user-manag.html
- Docker Compose 最佳实践：https://docs.docker.com/compose/
- Shell 脚本编写指南：https://google.github.io/styleguide/shellguide.html
