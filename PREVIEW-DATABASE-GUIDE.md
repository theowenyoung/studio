# Preview 环境数据库管理指南

## 概述

Preview 环境的数据库管理现已完全自动化，并提供了强大的查询和清理工具。

---

## 🎯 核心特性

### 1. **自动创建**
当你部署预览应用时，数据库会自动创建：
- 数据库名：`{app}_{branch}` (如 `hono_demo_feature_new_ui`)
- Owner：共享的 `app_user`
- 元数据：自动记录分支名、环境、创建时间

### 2. **可见性**
随时查看预览数据库的状态和年龄：
- 查看当前分支的数据库
- 列出所有旧的预览数据库
- 显示数据库大小和年龄

### 3. **灵活清理**
多种清理选项：
- 完全清理（容器 + 数据库）
- 只清理数据库
- 只清理容器
- 批量清理旧数据库

---

## 📋 工作流程

### 典型的开发流程

```bash
# 1. 创建功能分支
git checkout -b feature-new-ui

# 2. 部署到预览环境（数据库自动创建）
mise run deploy-hono

# 3. 查看预览环境信息（包括数据库状态）
mise run preview-info
# 或
mise run info

# 4. 开发和测试...

# 5. 合并到 main
git checkout main
git merge feature-new-ui

# 6. 清理预览环境
git checkout feature-new-ui
mise run preview-destroy

# 7. 删除分支
git branch -d feature-new-ui
```

---

## 🛠️ 命令详解

### 1. `preview-info` - 查看当前分支信息

显示当前分支的预览环境完整信息，包括数据库状态。

```bash
mise run preview-info
# 或使用别名
mise run info
```

**输出示例**：
```
📍 Preview Environment
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
   Branch:     feature-new-ui
   Clean name: feature-new-ui

🌐 Domains (if deployed):
   • https://feature-new-ui-hono-demo-preview.owenyoung.com

💾 Database names:
   • hono_demo_feature_new_ui

🐳 Docker tags:
   • hono-demo:preview-feature-new-ui

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Querying database status on prod server...

📊 Preview Databases on prod
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Database                          Age        Size
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
hono_demo_feature_new_ui         3 days     15 MB
```

---

### 2. `preview-list-old` - 列出所有旧数据库

列出所有超过指定天数的预览数据库（默认 7 天）。

```bash
# 列出 7 天以上的数据库（默认）
mise run preview-list-old

# 列出 14 天以上的数据库
mise run preview-list-old 14

# 列出 30 天以上的数据库
mise run preview-list-old 30
```

**输出示例**：
```
🔍 Listing Preview Databases
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
   Threshold: 7 days
   Server:    prod (5.78.126.18)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

📊 Preview Databases on prod
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Database                          Age        Size       Details
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
hono_demo_hotfix_bug_123         1 days     8 MB
hono_demo_feature_new_ui         3 days     15 MB
blog_feature_redesign            14 days    120 MB     ⚠️  OLD
hono_demo_old_feature            21 days    45 MB      ⚠️  OLD
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Total: 4 preview databases
Old (>7 days): 2

⚠️  Found 2 database(s) older than 7 days
Consider running: mise run preview-destroy
```

**用途**：
- 定期检查积累的预览数据库
- 识别需要清理的旧数据库
- 监控数据库存储使用情况

---

### 3. `preview-destroy` - 清理预览环境

清理当前分支的预览环境，支持多种模式。

#### 基本用法

```bash
# 完全清理（容器 + 数据库 + 镜像）
mise run preview-destroy

# 只清理数据库
mise run preview-destroy --db-only

# 只清理容器（保留数据库）
mise run preview-destroy --containers-only

# 跳过确认提示
mise run preview-destroy -y
mise run preview-destroy --db-only -y
```

#### 交互示例

```bash
$ mise run preview-destroy

🗑️  Preview Environment Cleanup
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
   Branch:     feature-new-ui
   Clean name: feature-new-ui
   Mode:       all

This will remove:
   • All containers (hono-demo-feature-new-ui, blog-feature-new-ui, etc.)
   • Docker images (preview-feature-new-ui tags)
   • Caddy configurations
   • All databases (hono_demo_feature_new_ui, etc.)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Continue? (yes/no): yes

✅ Preview environment cleanup completed: feature-new-ui

💡 Usage examples:
   mise run preview-destroy              # Destroy everything (with confirmation)
   mise run preview-destroy --db-only    # Only delete databases
   mise run preview-destroy -y           # Skip confirmation
```

---

### 4. `preview-list` - 列出预览服务器上的容器

列出 preview 服务器上所有运行的预览容器。

```bash
mise run preview-list
```

**注意**：这个命令列出的是 **preview 服务器**上的容器，而 `preview-list-old` 列出的是 **prod 服务器**上的数据库。

---

## 🔄 数据库生命周期

### 创建（自动）

当你运行 `mise run deploy-hono` 时：

1. **检测环境**：自动识别你在非 main 分支
2. **生成名称**：`hono_demo_feature_new_ui`
3. **创建数据库**：
   ```sql
   CREATE DATABASE hono_demo_feature_new_ui OWNER app_user;
   COMMENT ON DATABASE hono_demo_feature_new_ui IS
     'Environment: preview | Branch: feature-new-ui | Service: hono-demo | Created: 2025-11-26T10:30:00Z';
   ```
4. **运行迁移**：自动执行应用的迁移脚本

### 使用（自动）

应用自动连接到预览数据库：
```bash
DATABASE_URL=postgresql://app_user:${POSTGRES_APP_USER_PASSWORD}@postgres.internal:5432/hono_demo_feature_new_ui
```

### 清理（手动）

```bash
# 方式 1: 使用命令（推荐）
git checkout feature-new-ui
mise run preview-destroy

# 方式 2: 直接删除数据库（不推荐）
ssh prod "docker exec postgres psql -U postgres -c 'DROP DATABASE hono_demo_feature_new_ui;'"
```

---

## 📊 维护最佳实践

### 每周检查

```bash
# 列出所有超过 7 天的数据库
mise run preview-list-old

# 如果有旧数据库，逐个清理
git checkout <branch-name>
mise run preview-destroy
```

### 每月大扫除

```bash
# 列出所有超过 30 天的数据库
mise run preview-list-old 30

# 批量清理（手动）
ssh prod
docker exec postgres psql -U postgres -c "
SELECT 'DROP DATABASE ' || datname || ';'
FROM pg_database
WHERE datname LIKE '%\\_%\\_%'
  AND pg_catalog.shobj_description(oid, 'pg_database') LIKE '%Created:%'
  AND EXTRACT(DAY FROM (NOW() -
    substring(pg_catalog.shobj_description(oid, 'pg_database')
    from 'Created: ([^|]+)')::timestamp
  )) > 30;
"
```

### 监控存储

```bash
# 查看所有预览数据库的总大小
ssh prod "docker exec postgres psql -U postgres -c \"
SELECT
  COUNT(*) as count,
  pg_size_pretty(SUM(pg_database_size(datname))) as total_size
FROM pg_database
WHERE datname LIKE '%\\_%\\_%';
\""
```

---

## 🛡️ 安全机制

### 1. 生产环境保护

`preview-destroy` 有内置的保护机制：

```bash
$ git checkout main
$ mise run preview-destroy

❌ Error: Cannot destroy prod environment!
   You are on branch: main
```

### 2. 确认提示

默认需要确认才能删除：

```bash
Continue? (yes/no):
```

可以使用 `-y` 跳过（小心使用）。

### 3. 数据库元数据

每个数据库都有注释，包含：
- 环境类型（preview/prod）
- 分支名
- 服务名
- 创建时间

---

## 🔧 故障排查

### 问题 1: 数据库年龄显示 "unknown"

**原因**：数据库在添加元数据功能之前创建。

**解决**：
```bash
# 手动添加注释
ssh prod "docker exec postgres psql -U postgres -c \"
COMMENT ON DATABASE hono_demo_old_feature IS
  'Environment: preview | Branch: old-feature | Service: hono-demo | Created: 2025-11-01T00:00:00Z';
\""
```

### 问题 2: preview-info 查询失败

**错误**：`Could not query database information`

**原因**：Ansible 连接失败或 PostgreSQL 不可达。

**解决**：
```bash
# 测试 Ansible 连接
ansible -i ansible/inventory.yml prod -m ping

# 测试 PostgreSQL
ssh prod "docker exec postgres psql -U postgres -c 'SELECT 1;'"
```

### 问题 3: 删除数据库失败

**错误**：`database is being accessed by other users`

**解决**：
```bash
# 1. 先停止应用容器
ssh preview "cd /srv/studio/js-apps/hono-demo-feature-x && docker compose down"

# 2. 强制断开连接
ssh prod "docker exec postgres psql -U postgres -c \"
SELECT pg_terminate_backend(pid)
FROM pg_stat_activity
WHERE datname = 'hono_demo_feature_x' AND pid <> pg_backend_pid();
\""

# 3. 再删除数据库
ssh prod "docker exec postgres psql -U postgres -c 'DROP DATABASE hono_demo_feature_x;'"
```

---

## 📝 技术实现细节

### 数据库注释格式

```
Environment: {preview|prod} | Branch: {branch-name} | Service: {service-base} | Created: {ISO8601-timestamp}
```

### SQL 查询示例

```sql
-- 列出所有预览数据库及其年龄
SELECT
  datname,
  pg_size_pretty(pg_database_size(datname)) as size,
  EXTRACT(DAY FROM (NOW() - (
    substring(pg_catalog.shobj_description(oid, 'pg_database')
    from 'Created: ([^|]+)')::timestamp
  ))) as age_days
FROM pg_database
WHERE datname LIKE '%\_%\_%'
ORDER BY age_days DESC NULLS LAST;
```

### 分支名清理规则

在 `build-lib.sh` 中定义：

```bash
BRANCH_CLEAN=$(echo "$current_branch" |
  sed 's/[^a-zA-Z0-9-]/-/g' |
  tr '[:upper:]' '[:lower:]' |
  cut -c1-30)
```

**转换示例**：
- `feature/new-ui` → `feature-new-ui`
- `hotfix/bug#123` → `hotfix-bug-123`
- `RELEASE-v2.0` → `release-v2-0`

---

## 🎓 总结

### 新增功能

1. ✅ **自动元数据**：数据库创建时自动记录分支和时间
2. ✅ **改进的 preview-info**：显示数据库状态和年龄
3. ✅ **新命令 preview-list-old**：列出所有旧数据库
4. ✅ **增强的 preview-destroy**：支持部分清理选项

### 保留特性

- ✅ 自动创建预览数据库（无需手动操作）
- ✅ 使用共享 app_user（简化密码管理）
- ✅ 手动清理机制（保持控制权）

### 工作流程

```
创建分支 → 部署应用（自动创建DB） → 开发测试 →
查看状态（preview-info） → 合并分支 → 清理环境（preview-destroy）
```

### 维护建议

- **每周**：运行 `preview-list-old` 查看积累情况
- **每月**：批量清理超过 30 天的数据库
- **合并后**：及时运行 `preview-destroy` 清理

---

## 🔗 相关文档

- [DEPLOYMENT-GUIDE.md](./DEPLOYMENT-GUIDE.md) - 完整的部署指南
- [infra-apps/db-admin/README.md](./infra-apps/db-admin/README.md) - 数据库管理工具
- [ansible/playbooks/list-preview-dbs.yml](./ansible/playbooks/list-preview-dbs.yml) - 数据库查询 playbook
