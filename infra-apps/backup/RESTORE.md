# 数据恢复指南

## 快速恢复

### 从最新备份恢复

```bash
cd infra-apps/backup

# 方式 1: 使用恢复脚本（推荐）
./restore-postgres.sh ./.local/backups/postgres/postgres-all-YYYYMMDD-HHMMSS.sql.gz

# 方式 2: 手动恢复
gunzip -c ./.local/backups/postgres/postgres-all-*.sql.gz | \
  docker compose run --rm -T -e PGPASSWORD=your_password backup \
  psql -h postgres -U postgres -d postgres
```

### 查找最新备份

```bash
ls -lt ./.local/backups/postgres/ | head -5
```

## 恢复步骤详解

### 1. 准备工作

**检查备份文件**:
```bash
# 查看可用备份
ls -lh ./.local/backups/postgres/

# 查看备份内容
gunzip -c ./.local/backups/postgres/postgres-all-*.sql.gz | head -30
```

**停止应用服务**（推荐）:
```bash
# 避免数据冲突
docker compose down  # 在应用目录
```

**备份当前数据**（可选但推荐）:
```bash
cd infra-apps/backup
./backup.sh all  # 创建当前数据的备份，以防需要回滚
```

### 2. 执行恢复

**使用恢复脚本**（有确认提示）:
```bash
./restore-postgres.sh ./.local/backups/postgres/postgres-all-20251116-095831.sql.gz
```

脚本会：
1. 显示备份文件信息
2. 要求确认（输入 yes）
3. 执行恢复
4. 显示结果

**手动恢复**（直接执行）:
```bash
# 设置密码环境变量
export PGPASSWORD=your_password

# 恢复数据库
gunzip -c ./.local/backups/postgres/postgres-all-20251116-095831.sql.gz | \
  docker compose run --rm -T -e PGPASSWORD=$PGPASSWORD backup \
  psql -h postgres -U postgres -d postgres
```

### 3. 验证恢复

**检查数据库列表**:
```bash
docker compose -f ../postgres/docker-compose.yml exec postgres \
  psql -U postgres -d postgres -c "\l"
```

**检查角色**:
```bash
docker compose -f ../postgres/docker-compose.yml exec postgres \
  psql -U postgres -d postgres -c "\du"
```

**检查表和数据**:
```bash
# 查看表
docker compose -f ../postgres/docker-compose.yml exec postgres \
  psql -U postgres -d demo -c "\dt"

# 统计记录数
docker compose -f ../postgres/docker-compose.yml exec postgres \
  psql -U postgres -d demo -c "SELECT COUNT(*) FROM posts;"
```

## 从 S3 恢复

### 下载备份

```bash
# 列出 S3 备份
docker compose run --rm backup aws s3 ls s3://$S3_BUCKET/postgres/

# 下载最新备份
docker compose run --rm backup aws s3 cp \
  s3://$S3_BUCKET/postgres/20251116/postgres-all-20251116-095831.sql.gz \
  /backups/postgres/
```

### 恢复

```bash
# 从下载的文件恢复
./restore-postgres.sh ./.local/backups/postgres/postgres-all-20251116-095831.sql.gz
```

## 恢复到不同环境

### 恢复到测试环境

如果你想在测试环境测试恢复：

```bash
# 1. 启动测试 PostgreSQL 容器
docker run --name postgres-test -e POSTGRES_PASSWORD=test123 -d postgres:18-alpine

# 2. 恢复到测试容器
gunzip -c ./.local/backups/postgres/postgres-all-*.sql.gz | \
  docker exec -i postgres-test psql -U postgres -d postgres

# 3. 验证
docker exec postgres-test psql -U postgres -d postgres -c "\l"

# 4. 清理
docker stop postgres-test && docker rm postgres-test
```

## 常见问题

### Q: 恢复时出现 "relation already exists" 错误

**A**: 这是正常的，不影响恢复。表示对象已经存在，PostgreSQL 会跳过创建步骤。

### Q: 恢复后数据不完整

**A**: 检查：
1. 备份文件大小是否正常（> 2KB）
2. 备份文件是否损坏：`gunzip -t backup-file.sql.gz`
3. 恢复过程是否有严重错误（ERROR 而非 NOTICE）

### Q: 密码认证失败

**A**: 确保使用正确的密码：
```bash
# 从 .env 文件获取密码
grep POSTGRES_ADMIN_URL .env

# 或设置环境变量
export PGPASSWORD=your_password
```

### Q: 恢复后无法连接数据库

**A**: 
1. 检查 PostgreSQL 服务状态：`docker compose ps postgres`
2. 重启服务：`docker compose restart postgres`
3. 检查日志：`docker compose logs postgres`

### Q: 想要回滚恢复

**A**: 如果你在恢复前创建了备份：
```bash
# 使用恢复前的备份重新恢复
./restore-postgres.sh ./.local/backups/postgres/postgres-all-BEFORE-RESTORE.sql.gz
```

## 部分恢复

### 只恢复特定数据库

`pg_dumpall` 的备份包含所有数据库，如果只想恢复特定数据库：

```bash
# 1. 从备份中提取特定数据库的 SQL
gunzip -c backup.sql.gz | sed -n '/^\\connect demo$/,/^\\connect /p' > demo-only.sql

# 2. 恢复到特定数据库
psql -U postgres -d demo < demo-only.sql
```

### 只恢复角色和权限

```bash
# 提取角色定义
gunzip -c backup.sql.gz | sed -n '/^CREATE ROLE/,/^ALTER ROLE/p' > roles-only.sql

# 执行角色创建
psql -U postgres -d postgres < roles-only.sql
```

## 自动化恢复

### 定时测试恢复

创建定时任务测试备份恢复（验证备份可用性）：

```bash
# 添加到 crontab
0 3 * * 0 cd /path/to/backup && ./test-restore.sh
```

## 最佳实践

1. **恢复前备份**: 始终在恢复前创建当前数据的备份
2. **测试环境验证**: 先在测试环境验证恢复流程
3. **停止应用**: 恢复前停止所有连接到数据库的应用
4. **验证数据**: 恢复后验证关键数据完整性
5. **监控日志**: 关注恢复过程中的错误日志
6. **保留多个备份**: 不要只依赖最新的备份
7. **定期测试**: 定期测试恢复流程确保备份可用

## 紧急恢复检查清单

- [ ] 确定要恢复的备份文件
- [ ] 验证备份文件完整性
- [ ] 停止应用服务
- [ ] 备份当前数据（如果需要）
- [ ] 执行恢复
- [ ] 验证数据库列表
- [ ] 验证角色和权限
- [ ] 验证关键表和数据
- [ ] 启动应用服务
- [ ] 测试应用功能
