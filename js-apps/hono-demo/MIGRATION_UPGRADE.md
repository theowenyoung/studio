# Migration 系统升级 - 使用 node-pg-migrate

## 改进说明

将自定义的 migration 系统替换为成熟的第三方工具 **node-pg-migrate**。

## 为什么改用第三方工具？

### 问题
之前尝试自己实现 migration 系统，虽然功能完整，但：
- ❌ 重复造轮子
- ❌ 需要维护自定义代码
- ❌ 缺少成熟工具的高级功能（如 dry-run、rollback 等）
- ❌ 没有社区支持

### 解决方案
使用 **node-pg-migrate**：
- ✅ 成熟稳定（2.8k+ GitHub stars）
- ✅ 轻量级，零额外依赖（只依赖 pg）
- ✅ 功能完善（up/down、dry-run、rollback）
- ✅ 社区活跃，持续维护
- ✅ 文档完善
- ✅ 支持 SQL 和 TypeScript/JavaScript

## 改动内容

### 1. 安装依赖

```bash
pnpm add node-pg-migrate
```

### 2. 新增文件

- `.node-pg-migrate.config.js` - 配置文件
- `migrations/` - Migration 文件目录（从 `src/db/migrations/` 迁移）

### 3. 修改文件

**`src/db/postgres.ts`** - 简化为只保留连接池和 migration 调用
```typescript
// 之前：100+ 行自定义实现
// 之后：~50 行，使用 node-pg-migrate

import runner from 'node-pg-migrate'

export async function runMigrations() {
  await runner({
    databaseUrl: process.env.DATABASE_URL,
    dir: join(projectRoot, 'migrations'),
    direction: 'up',
    // ...
  })
}
```

**`package.json`** - 更新 scripts
```json
{
  "scripts": {
    "migrate": "node-pg-migrate",
    "migrate:up": "node-pg-migrate up",
    "migrate:down": "node-pg-migrate down",
    "migrate:create": "node-pg-migrate create"
  }
}
```

**`README-MIGRATIONS.md`** - 重写文档
- 使用 node-pg-migrate 的用法
- 完整的命令参考
- 最佳实践

**`README.md`** - 更新数据库管理部分

### 4. 删除文件

删除自定义实现的代码：
- `src/db/migrate.ts`
- `src/db/create-migration.ts`
- `src/db/migrations/` 目录（迁移到 `migrations/`）
- `MIGRATION_IMPROVEMENTS.md`（之前的文档）

### 5. 迁移 Migration 文件

```bash
# 从
src/db/migrations/001_create_posts_table.sql
src/db/migrations/002_seed_posts.sql

# 到
migrations/1730000001_create-posts-table.sql
migrations/1730000002_seed-posts.sql
```

## 新的使用方式

### 常用命令

```bash
# 运行所有 pending migrations
pnpm migrate:up

# 回滚最后一个 migration
pnpm migrate:down

# 创建新的 migration
pnpm migrate:create add-users-table

# Dry run（预览但不执行）
pnpm migrate up --dry-run

# 查看帮助
pnpm migrate --help
```

### 创建 Migration

```bash
# 1. 创建文件
pnpm migrate:create add-users-table

# 2. 编辑生成的文件
# migrations/1699000000000_add-users-table.sql

# 3. 运行
pnpm migrate:up
```

### 应用启动时自动运行

代码无需修改，应用启动时仍会自动运行 migrations：

```typescript
// src/index.tsx
async function initialize() {
  await initDatabase()  // 调用 runMigrations()
  await connectRedis()
}
```

## 功能对比

| 功能 | 自定义实现 | node-pg-migrate |
|------|-----------|-----------------|
| 基础 migration | ✅ | ✅ |
| 事务支持 | ✅ | ✅ |
| 防重复执行 | ✅ | ✅ |
| 自动扫描文件 | ✅ | ✅ |
| CLI 工具 | ✅ | ✅ |
| Migration 生成器 | ✅ | ✅ |
| **Down migrations** | ❌ | ✅ |
| **Dry-run 模式** | ❌ | ✅ |
| **SQL + TS/JS** | ❌ (只支持 SQL) | ✅ |
| **社区支持** | ❌ | ✅ |
| **持续维护** | ❌ | ✅ |
| **文档完善** | ✅ | ✅ |
| 代码量 | ~300 行 | ~50 行 |

## 优势

### 1. 更少的代码
- **之前**：~300 行自定义代码
- **现在**：~50 行（只有配置和调用）

### 2. 更多的功能
- ✅ Down migrations（回滚）
- ✅ Dry-run 模式
- ✅ 支持 TypeScript/JavaScript
- ✅ 更灵活的配置

### 3. 更可靠
- 久经考验，bug 少
- 社区维护，持续更新
- 完善的测试

### 4. 更好的开发体验
- 文档完善
- 社区资源多
- 问题容易找到解决方案

## 迁移步骤（如果其他项目需要）

如果你有其他项目使用了类似的自定义 migration 系统，可以按以下步骤迁移：

1. **安装 node-pg-migrate**
   ```bash
   pnpm add node-pg-migrate
   ```

2. **创建配置文件**
   ```javascript
   // .node-pg-migrate.config.js
   export default {
     databaseUrl: process.env.DATABASE_URL,
     dir: 'migrations',
     migrationsTable: 'pgmigrations',
     // ...
   }
   ```

3. **迁移 migration 文件**
   - 将文件移到 `migrations/` 目录
   - 重命名为 node-pg-migrate 的格式

4. **简化 postgres.ts**
   - 删除自定义 migration 代码
   - 调用 node-pg-migrate 的 runner

5. **更新 package.json**
   ```json
   {
     "scripts": {
       "migrate:up": "node-pg-migrate up",
       "migrate:down": "node-pg-migrate down",
       "migrate:create": "node-pg-migrate create"
     }
   }
   ```

6. **更新文档**
   - 更新使用说明
   - 添加新功能介绍

7. **删除旧代码**
   - 删除自定义的 migrate.ts
   - 删除 create-migration.ts
   - 删除旧的 migrations 目录

## 注意事项

### Migration 表名不同

- 自定义系统使用：`migrations`
- node-pg-migrate 使用：`pgmigrations`

**如果数据库已有 migrations 记录：**

方案 1：保留两个表（推荐）
```javascript
// .node-pg-migrate.config.js
export default {
  migrationsTable: 'pgmigrations',  // 新表名
  // ...
}
```
这样新旧系统不会冲突，已运行的 migrations 不受影响。

方案 2：迁移数据
```sql
-- 将旧表数据迁移到新表
INSERT INTO pgmigrations (name, run_on)
SELECT name, executed_at FROM migrations;
```

### Migration 文件命名

node-pg-migrate 使用时间戳命名：
```
1730000001_create-posts-table.sql  # Unix 时间戳
```

而不是：
```
001_create_posts_table.sql  # 序号
```

## 总结

这次改进体现了"不要重复造轮子"的原则：

1. ✅ 使用成熟的第三方工具
2. ✅ 减少了维护成本
3. ✅ 获得了更多功能
4. ✅ 提高了可靠性
5. ✅ 改善了开发体验

**关键收获：**
- 在已有成熟解决方案的情况下，优先使用第三方工具
- 自定义实现只在特殊需求时才考虑
- 代码少不等于功能少，关键是选对工具
