# 环境变量管理

## 核心原则：完全统一 ✅

所有环境使用 **相同的环境变量名**，只有 **值** 不同。

---

## 数据库初始化环境变量

### 初始化脚本需要的环境变量

**只需要 1 个**：`POSTGRES_APP_USER_PASSWORD`（可选）

```bash
# 预览/生产环境：必须提供
POSTGRES_APP_USER_PASSWORD=<strong-password>

# 本地开发：可选，默认 fallback 到 'dev'
POSTGRES_APP_USER_PASSWORD=dev  # 或者不设置，自动使用 'dev'
```

**统一初始化脚本**：
```bash
# infra-apps/db-admin/migrations/001-init-app-user.sh
APP_USER_PASSWORD="${POSTGRES_APP_USER_PASSWORD:-dev}"

# 本地：未设置 → 'dev'
# 预览：从 Docker Compose env_file 传入
# 生产：从 Docker Compose env_file 传入
```

**完全统一！一个脚本适配所有环境！**

---

## 应用迁移所需的环境变量

### 只需要 1 个环境变量

```bash
DATABASE_URL=postgresql://app_user:<password>@<host>:5432/<db_name>
```

**所有环境都一样！**

---

## 各环境的具体配置

### 1️⃣ 本地开发环境

**文件位置**：`js-apps/hono-demo/.env` (手动创建)

```bash
# 从 .env.example 复制
DATABASE_URL=postgresql://app_user:dev@localhost:5432/hono_demo
REDIS_URL=redis://default:xxxxxxxx@localhost:6379
```

**传入方式**：
```json
// package.json
{
  "scripts": {
    "migrate": "bash ../../scripts/ensure-database.sh && node-pg-migrate up",
    "dev": "vite --host --port 8001",
    "start": "NODE_ENV=production PORT=8001 node --env-file=.env dist/server/index.js"
  }
}
```

- `ensure-database.sh` 自动读取 `$DATABASE_URL`
- `node-pg-migrate` 自动读取 `$DATABASE_URL`
- Vite 开发服务器自动加载 `.env`
- Node.js 使用 `--env-file=.env` 加载环境变量

---

### 2️⃣ 预览环境

**文件位置**：`/srv/studio/js-apps/hono-demo/.env` (Ansible 自动生成)

```bash
# 由 Ansible 从 AWS SSM 拉取密码后生成
DATABASE_URL=postgresql://app_user:<from-aws-ssm>@preview-host:5432/feature_x_hono_demo
REDIS_URL=redis://default:<from-aws-ssm>@preview-host:6379
```

**传入方式**：
```yaml
# docker-compose.prod.yml
services:
  hono-demo-migrate:
    image: ${IMAGE_TAG}
    env_file: .env              # ← 自动加载 .env 文件
    command: ["pnpm", "migrate"]

  hono-demo:
    image: ${IMAGE_TAG}
    env_file: .env              # ← 自动加载 .env 文件
```

**Ansible 生成流程**：
```yaml
# ansible/playbooks/deploy-app.yml 会包含类似任务
- name: Generate .env file
  template:
    src: templates/app.env.j2
    dest: "{{ remote_dir }}/.env"
  vars:
    database_password: "{{ lookup('aws_ssm', '/studio-preview/database/app_user_password') }}"
```

---

### 3️⃣ 生产环境

**文件位置**：`/srv/studio/js-apps/hono-demo/.env` (Ansible 自动生成)

```bash
# 由 Ansible 从 AWS SSM 拉取密码后生成
DATABASE_URL=postgresql://app_user:<from-aws-ssm>@prod-host:5432/hono_demo
REDIS_URL=redis://default:<from-aws-ssm>@prod-host:6379
```

**传入方式**：与预览环境完全相同！

---

## 环境变量对比表

| 变量名 | 本地开发 | 预览环境 | 生产环境 |
|--------|----------|----------|----------|
| **DATABASE_URL** | `postgresql://app_user:dev@localhost:5432/hono_demo` | `postgresql://app_user:<aws-ssm>@preview-host:5432/feature_x_hono_demo` | `postgresql://app_user:<aws-ssm>@prod-host:5432/hono_demo` |
| **REDIS_URL** | `redis://default:localpass@localhost:6379` | `redis://default:<aws-ssm>@preview-host:6379` | `redis://default:<aws-ssm>@prod-host:6379` |
| **文件来源** | 手动创建 | Ansible 生成 | Ansible 生成 |
| **密码来源** | 硬编码 (`dev`) | AWS SSM | AWS SSM |

---

## AWS Parameter Store 参数

### 极简！只需要 4 个参数

```bash
# 预览环境 (2 个)
/studio-preview/database/host                    # 示例: preview-host
/studio-preview/database/app_user_password       # 示例: xxx

# 生产环境 (2 个)
/studio-prod/database/host                       # 示例: prod-host
/studio-prod/database/app_user_password          # 示例: yyy
```

**之前需要 20+ 个参数！**

---

## 迁移脚本执行流程

### 本地开发

```bash
cd js-apps/hono-demo
pnpm migrate
```

**执行过程**：
```
1. bash ../../scripts/ensure-database.sh
   ↓ 读取 $DATABASE_URL 环境变量
   ↓ 从 .env 文件加载
   ↓ 解析: postgresql://app_user:dev@localhost:5432/hono_demo
   ↓ 检查数据库 hono_demo 是否存在
   ↓ 不存在 → psql -U postgres -c "CREATE DATABASE hono_demo OWNER app_user"

2. node-pg-migrate up
   ↓ 读取 $DATABASE_URL 环境变量
   ↓ 从 .env 文件加载
   ↓ 连接到: postgresql://app_user:dev@localhost:5432/hono_demo
   ↓ 运行迁移文件 (CREATE TABLE ...)
```

### 预览/生产环境

```bash
# 在服务器上通过 Docker Compose
cd /srv/studio/js-apps/hono-demo
docker compose --profile migrate run --rm hono-demo-migrate
```

**执行过程**：
```
1. Docker 容器启动
   ↓ env_file: .env (Ansible 已生成)
   ↓ 加载环境变量到容器

2. 容器内执行: pnpm migrate
   ↓ bash ../../scripts/ensure-database.sh
   ↓ 读取 $DATABASE_URL (已在容器环境变量中)
   ↓ 解析: postgresql://app_user:<aws-ssm>@prod-host:5432/hono_demo
   ↓ 检查数据库是否存在
   ↓ 不存在 → psql -U postgres -c "CREATE DATABASE hono_demo OWNER app_user"

3. node-pg-migrate up
   ↓ 读取 $DATABASE_URL (已在容器环境变量中)
   ↓ 连接到数据库
   ↓ 运行迁移
```

---

## 开发环境 vs 生产环境的差异

### ✅ 相同之处（核心一致性）

1. **环境变量名**：完全相同
   ```bash
   DATABASE_URL=...
   REDIS_URL=...
   ```

2. **迁移命令**：完全相同
   ```bash
   pnpm migrate
   ```

3. **数据库用户**：完全相同
   ```bash
   app_user (no CREATEDB privilege)
   ```

4. **数据库创建逻辑**：完全相同
   ```bash
   postgres 超级用户创建数据库
   ```

### 🔄 不同之处（仅值不同）

1. **密码**
   - 本地：`dev` (硬编码)
   - 预览/生产：从 AWS SSM 拉取

2. **主机**
   - 本地：`localhost`
   - 预览：`preview-host` (或 Docker 网络中的 `postgres`)
   - 生产：`prod-host` (或 Docker 网络中的 `postgres`)

3. **数据库名**
   - 本地：`hono_demo`
   - 预览：`feature_x_hono_demo` (分支前缀)
   - 生产：`hono_demo`

4. **配置文件来源**
   - 本地：手动创建 `.env`
   - 预览/生产：Ansible 自动生成 `.env`

---

## 安全性

### 本地开发

- ✅ 密码硬编码为 `dev` (可以接受，仅本地)
- ✅ 所有开发者使用相同密码
- ✅ 简单易用

### 预览/生产环境

- ✅ 密码存储在 AWS Parameter Store (加密)
- ✅ Ansible 动态拉取密码并生成 `.env`
- ✅ `.env` 文件仅存在于服务器上，不提交到 Git
- ✅ 密码轮换：更新 AWS SSM → 重新部署

---

## 最佳实践

### 1. `.env` 文件管理

```bash
# ❌ 不要提交到 Git
.gitignore
*.env

# ✅ 提交 .env.example
js-apps/hono-demo/.env.example  # 包含本地开发的默认配置
```

### 2. 应用启动前检查

```bash
# 在应用代码中验证环境变量
if (!process.env.DATABASE_URL) {
  throw new Error('DATABASE_URL is required')
}
```

### 3. Docker Compose 配置

```yaml
# ✅ 推荐：使用 env_file
services:
  app:
    env_file: .env

# ❌ 避免：硬编码环境变量
services:
  app:
    environment:
      DATABASE_URL: postgresql://...  # 不要这样！
```

### 4. 密码轮换

```bash
# 1. 生成新密码
NEW_PASSWORD="$(openssl rand -base64 32)"

# 2. 更新 AWS SSM
aws ssm put-parameter \
  --name /studio-prod/database/app_user_password \
  --value "$NEW_PASSWORD" \
  --overwrite

# 3. 更新数据库
psql -U postgres -c "ALTER USER app_user PASSWORD '$NEW_PASSWORD'"

# 4. 重新部署应用（自动拉取新密码）
mise run deploy-hono
```

---

## 总结

### 核心优势

✅ **完全统一**：所有环境使用相同的环境变量名
✅ **极简配置**：只需要 1 个环境变量 (`DATABASE_URL`)
✅ **自动化**：预览/生产环境由 Ansible 自动生成配置
✅ **安全**：生产密码存储在 AWS SSM，不提交到 Git
✅ **易维护**：修改配置只需要改一个地方

### 开发体验

- 本地：复制 `.env.example` → 直接运行 `pnpm migrate`
- 预览：推送分支 → 自动部署 → 自动配置环境变量
- 生产：合并到 main → 自动部署 → 自动配置环境变量

**开发者无需关心环境差异！** 🚀
