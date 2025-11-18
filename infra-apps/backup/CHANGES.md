# 更改说明：PostgreSQL 备份所有数据库

## 主要变化

### 1. 备份方式

| 项目 | 之前 | 现在 |
|------|------|------|
| 备份命令 | `pg_dump` | `pg_dumpall` |
| 备份范围 | 单个数据库 | 所有数据库 |
| 备份内容 | 指定数据库的数据和结构 | 所有数据库 + 角色 + 权限 + 表空间 |
| 文件命名 | `postgres-YYYYMMDD-HHMMSS.sql.gz` | `postgres-all-YYYYMMDD-HHMMSS.sql.gz` |

### 2. URL 格式

#### 之前（需要指定数据库名）
```bash
POSTGRES_ADMIN_URL=postgresql://postgres:password@postgres:5432/database_name
```

#### 现在（不需要数据库名）
```bash
POSTGRES_ADMIN_URL=postgresql://postgres:password@postgres:5432
```

### 3. 备份内容对比

#### 使用 `pg_dump`（单数据库）
```sql
-- 只包含指定数据库
CREATE TABLE users (...);
CREATE TABLE posts (...);
INSERT INTO users VALUES (...);
```

#### 使用 `pg_dumpall`（所有数据库）
```sql
-- 包含所有数据库、角色、权限
CREATE ROLE admin;
CREATE ROLE user1;
GRANT ...;

CREATE DATABASE app_db;
\connect app_db
CREATE TABLE users (...);

CREATE DATABASE analytics_db;
\connect analytics_db
CREATE TABLE events (...);
```

## 优势

1. **完整备份**: 包含所有数据库、用户、角色、权限
2. **简化配置**: 不需要指定数据库名
3. **易于恢复**: 一次恢复所有内容，无需多次操作
4. **保留权限**: 用户角色和权限也会被备份

## 注意事项

### 恢复时的影响

- ⚠️ 恢复 `pg_dumpall` 备份会覆盖现有的所有数据库
- ⚠️ 会覆盖现有的用户和角色
- ⚠️ 建议在恢复前停止所有应用

### 备份文件大小

- `pg_dumpall` 备份文件会比单个 `pg_dump` 大
- 包含所有数据库的数据
- 使用 gzip 压缩可以显著减小文件大小

## 示例对比

### 旧方式：备份单个数据库

```bash
# 配置
POSTGRES_ADMIN_URL=postgresql://postgres:password@localhost:5432/myapp

# 备份
pg_dump -h localhost -U postgres -d myapp > backup.sql

# 恢复
psql -h localhost -U postgres -d myapp < backup.sql
```

**问题**:
- 只备份了 `myapp` 数据库
- 其他数据库没有备份
- 用户和角色没有备份

### 新方式：备份所有数据库

```bash
# 配置
POSTGRES_ADMIN_URL=postgresql://postgres:password@localhost:5432

# 备份
pg_dumpall -h localhost -U postgres > backup-all.sql

# 恢复
psql -h localhost -U postgres -d postgres < backup-all.sql
```

**优势**:
- ✅ 所有数据库都备份了
- ✅ 用户和角色也备份了
- ✅ 权限和配置都保留了

## 迁移指南

如果你之前使用的是旧版本（单数据库备份），需要：

### 1. 更新环境变量

```bash
# 旧的 .env
POSTGRES_ADMIN_URL=postgresql://postgres:password@postgres:5432/mydb

# 新的 .env（移除数据库名）
POSTGRES_ADMIN_URL=postgresql://postgres:password@postgres:5432
```

### 2. 重新构建镜像

```bash
docker compose build backup
```

### 3. 重启服务

```bash
docker compose up -d
```

### 4. 手动测试备份

```bash
docker compose exec backup /usr/local/bin/backup-postgres.sh
```

### 5. 验证备份文件

```bash
# 查看备份文件
ls -lh ./.local/backups/postgres/

# 应该看到类似这样的文件：
# postgres-all-20250116-020000.sql.gz
```

## 兼容性

- ✅ 与现有的 Redis 备份兼容
- ✅ S3 上传逻辑保持不变
- ✅ 清理脚本保持不变
- ✅ 调度配置保持不变

## 常见问题

### Q: 会不会影响现有备份？

A: 不会。新的备份文件命名为 `postgres-all-*`，与旧的 `postgres-*` 不冲突。

### Q: 旧的备份文件怎么办？

A: 旧的备份文件仍然可以使用，可以手动保留或按照保留策略自动清理。

### Q: 恢复单个数据库怎么办？

A: 可以从 `pg_dumpall` 备份中提取单个数据库：

```bash
# 提取特定数据库
gunzip -c postgres-all-20250116-020000.sql.gz | \
  sed -n '/^\\connect mydb$/,/^\\connect /p' | \
  psql -U postgres -d mydb
```

### Q: 备份时间会变长吗？

A: 是的，因为要备份所有数据库。但通过 gzip 压缩和增量备份策略可以优化。
