# 本地开发指南

## 数据库策略

本地开发支持两种模式：

### 模式 1：简单模式（默认，推荐日常开发）✅

**特点**：
- ✅ 一个共享用户 (`local_dev` / `dev`)
- ✅ 应用自动创建数据库
- ✅ 快速启动，零配置
- ✅ 与预览环境一致

**适用场景**：
- 日常功能开发
- 快速原型验证
- 新同事快速上手

**限制**：
- ⚠️ 无法测试权限相关问题
- ⚠️ 与生产环境配置不完全一致

---

### 模式 2：生产模式（可选，部署前验证）

**特点**：
- ✅ 每个应用独立用户
- ✅ 读写分离（RW + RO 用户）
- ✅ 与生产环境完全一致
- ✅ 可测试权限问题

**适用场景**：
- 部署前完整测试
- 权限相关功能开发
- CI/CD 测试环境

**限制**：
- ⚠️ 初始化复杂
- ⚠️ 需要管理多个用户

---

## 快速开始（简单模式）

### 1. 启动基础设施

```bash
# 初始化 Docker 网络（首次）
mise run init

# 启动 PostgreSQL, Redis, Caddy
mise run up

# 查看日志
mise run logs
```

PostgreSQL 会自动初始化：
- ✅ 创建 `local_dev` 用户（密码：`dev`）
- ✅ 赋予 CREATEDB 权限
- ✅ 创建 `template_local` 模板数据库

### 2. 配置应用环境变量

```bash
# 拉取示例配置（已经配置好了）
cp js-apps/hono-demo/.env.example js-apps/hono-demo/.env

# 内容：
# DATABASE_URL=postgresql://local_dev:dev@localhost:5432/hono_demo
# REDIS_URL=redis://default:xxxxxxxx@localhost:6379
```

### 3. 运行应用迁移

```bash
# 应用会自动创建数据库（如果不存在）
mise run db-migrate-hono

# 或运行所有应用的迁移
mise run db-migrate
```

### 4. 启动开发服务器

```bash
# 启动单个应用
mise run dev-hono

# 或启动所有应用
mise run dev
```

**就这么简单！** 🎉

---

## 切换到生产模式（可选）

如果需要测试生产环境的权限配置：

### 1. 初始化生产模式数据库

```bash
mise run db-init-prod-mode

# 会创建：
# - demo_user / demo_readonly
# - hono_user / hono_readonly
# - blog_user / blog_readonly
# ... 等独立用户
```

### 2. 更新应用环境变量

```bash
# js-apps/hono-demo/.env
DATABASE_URL=postgresql://hono_user:local_password@localhost:5432/hono_demo

# 或使用只读用户测试
DATABASE_URL=postgresql://hono_readonly:local_password@localhost:5432/hono_demo
```

### 3. 运行迁移和应用

```bash
mise run db-migrate-hono
mise run dev-hono
```

---

## 环境对比

| 特性 | 简单模式 | 生产模式 | 实际生产环境 |
|------|---------|---------|-------------|
| 用户数 | 1 个共享 | 每应用 2-3 个 | 每应用 2-3 个 |
| 数据库创建 | 自动 | 手动（迁移脚本） | 手动（迁移脚本） |
| 权限隔离 | 无 | 有（RW/RO） | 有（RW/RO） |
| 初始化时间 | 5 秒 | 30 秒 | 30 秒 |
| 凭证管理 | 硬编码 | 本地文件 | AWS Parameter Store |
| 适用场景 | 日常开发 | 部署前测试 | 生产部署 |

---

## 数据库管理

### 连接数据库

```bash
# 使用 psql
mise run db

# 或直接连接
psql postgresql://local_dev:dev@localhost:5432/hono_demo
```

### 查看所有数据库

```sql
\l

-- 你会看到：
-- hono_demo      | local_dev
-- blog           | local_dev
-- template_local | local_dev (模板)
```

### 删除数据库（重新开始）

```sql
DROP DATABASE hono_demo;

-- 应用迁移会自动重新创建
```

### 清理所有应用数据库

```bash
# 停止并删除 PostgreSQL 容器和数据
mise run dev-down-postgres
docker volume rm postgres_postgres_data

# 重新启动（会重新初始化）
mise run dev-up-postgres
```

---

## 常见问题

### Q: 为什么本地不用生产模式？

**A: 日常开发不需要那么复杂**

生产模式的优势（权限隔离、读写分离）在日常开发中价值不大：
- 本地数据是临时的
- 开发者需要完全控制
- 快速迭代更重要

但在以下场景可以用生产模式：
- 部署前验证权限配置
- 测试只读用户的行为
- CI/CD 环境（更接近生产）

### Q: 简单模式安全吗？

**A: 本地开发足够安全**

- 本地数据库只监听 localhost
- 没有敏感数据
- 密码 `dev` 只用于开发

生产环境用完全不同的凭证（AWS Parameter Store）。

### Q: 如何在简单模式和生产模式之间切换？

**A: 只需修改 .env 文件**

```bash
# 简单模式
DATABASE_URL=postgresql://local_dev:dev@localhost:5432/hono_demo

# 生产模式
DATABASE_URL=postgresql://hono_user:local_password@localhost:5432/hono_demo
```

数据库是独立的，可以同时存在。

### Q: 新同事如何快速开始？

**A: 三步搞定**

```bash
# 1. 启动基础设施
mise run up

# 2. 复制环境变量（已配置好）
cp js-apps/hono-demo/.env.example js-apps/hono-demo/.env

# 3. 运行迁移并启动
mise run db-migrate-hono
mise run dev-hono
```

无需配置密码、创建用户、手动建库。

### Q: 预览环境也用简单模式吗？

**A: 是的！预览环境 = 简单模式**

```
本地开发 (local_dev)  →  预览环境 (preview_app_user)  →  生产环境 (独立用户)
简单模式                  简单模式                      生产模式
```

这样可以在本地完全模拟预览环境的行为。

---

## 最佳实践

### ✅ 推荐做法

1. **日常开发用简单模式**
   ```bash
   mise run up
   mise run dev
   ```

2. **部署前切换到生产模式测试**
   ```bash
   mise run db-init-prod-mode
   # 修改 .env 使用 hono_user
   mise run dev-hono
   ```

3. **提交代码前恢复简单模式**
   ```bash
   # 改回 .env
   DATABASE_URL=postgresql://local_dev:dev@localhost:5432/hono_demo
   ```

4. **团队统一使用简单模式**
   - 降低新人门槛
   - 减少环境问题
   - 提高开发效率

### ❌ 避免做法

1. **不要在 .env 中硬编码生产凭证**
   ```bash
   # ❌ 危险！
   DATABASE_URL=postgresql://prod_user:real_password@prod_host:5432/prod_db
   ```

2. **不要把本地数据库当生产用**
   - 本地数据随时可以删除
   - 用 Docker 卷管理数据

3. **不要在简单模式测试权限**
   - `local_dev` 有 CREATEDB 权限
   - 需要测试权限时切换到生产模式

---

## 总结

| 场景 | 推荐模式 | 命令 |
|------|---------|------|
| 日常开发 | 简单模式 | `mise run up && mise run dev` |
| 新功能开发 | 简单模式 | 同上 |
| 部署前验证 | 生产模式 | `mise run db-init-prod-mode` |
| 权限测试 | 生产模式 | 同上 |
| CI/CD | 生产模式 | 自动化脚本 |
| 新同事入职 | 简单模式 | 三步启动 |

**核心原则**：默认简单，按需复杂 🎯
