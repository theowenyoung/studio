# 快速开始指南

## 1. 创建配置文件

```bash
cd infra-apps/backup
cp .env.example .env
```

## 2. 编辑配置（只需要 3 个变量）

```bash
# .env
POSTGRES_ADMIN_URL=postgresql://postgres:your_password@postgres:5432
REDIS_DOCKER_URL=redis://:your_password@redis:6379

# S3 可选
S3_BUCKET=my-backups
```

## 3. 启动备份服务

**开发环境:**
```bash
docker compose up -d
```

**生产环境:**
```bash
# 构建镜像
docker build -t backup:latest .

# 启动服务
docker compose -f docker-compose.prod.yml up -d
```

## 4. 验证

```bash
# 查看日志
docker compose logs -f backup

# 测试连接
docker compose exec backup /usr/local/bin/test-connection.sh

# 手动执行备份
docker compose exec backup /usr/local/bin/backup-all.sh

# 查看备份文件
ls -lh ./.local/backups/postgres/
ls -lh ./.local/backups/redis/
```

## 重要说明

### PostgreSQL 备份特性

- ✅ 使用 `pg_dumpall` 备份**所有数据库**
- ✅ 包括所有角色、权限、表空间
- ✅ URL **不需要**指定数据库名
- ✅ 文件名: `postgres-all-YYYYMMDD-HHMMSS.sql.gz`

### 配置特点

- ✅ 敏感信息在 `.env` 文件
- ✅ 非敏感配置在 `docker-compose.yml`
- ✅ 无需重复声明环境变量
- ✅ 支持开发/生产环境分离

### URL 格式

```bash
# PostgreSQL（不需要数据库名）
postgresql://user:password@host:port

# Redis
redis://:password@host:port
```

## 默认调度

- Postgres: 每天凌晨 2 点
- Redis: 每天凌晨 3 点
- 清理: 每天凌晨 5 点
- 完整备份: 每周日凌晨 4 点

## 手动备份

### 使用快捷脚本（推荐）

**开发环境:**
```bash
./backup.sh all       # 备份所有服务
./backup.sh postgres  # 只备份 PostgreSQL
./backup.sh redis     # 只备份 Redis
./backup.sh test      # 测试连接
./backup.sh logs      # 查看日志
./backup.sh list      # 列出备份文件
./backup.sh status    # 查看服务状态
```

**生产环境:**
```bash
./backup-prod.sh all      # 备份所有服务
./backup-prod.sh postgres # 只备份 PostgreSQL
./backup-prod.sh redis    # 只备份 Redis
./backup-prod.sh test     # 测试连接
./backup-prod.sh stats    # 查看存储统计
./backup-prod.sh status   # 查看服务状态
```

### 使用原始命令

**开发环境:**
```bash
# 完整备份
docker compose exec backup /usr/local/bin/backup-all.sh

# 只备份 PostgreSQL
docker compose exec backup /usr/local/bin/backup-postgres.sh

# 只备份 Redis
docker compose exec backup /usr/local/bin/backup-redis.sh

# 测试连接
docker compose exec backup /usr/local/bin/test-connection.sh

# 查看日志
docker compose exec backup tail -f /var/log/backup.log
```

**生产环境:**
```bash
# 完整备份
docker compose -f docker-compose.prod.yml exec backup /usr/local/bin/backup-all.sh

# 只备份 PostgreSQL
docker compose -f docker-compose.prod.yml exec backup /usr/local/bin/backup-postgres.sh
```

📖 **详细手动备份指南**: 查看 [MANUAL_BACKUP.md](MANUAL_BACKUP.md)

## 故障排除

### 连接失败

```bash
# 检查环境变量
docker compose exec backup env | grep -E '(POSTGRES|REDIS)'

# 测试连接
docker compose exec backup /usr/local/bin/test-connection.sh
```

### URL 格式错误

```bash
# ✅ 正确
POSTGRES_ADMIN_URL=postgresql://postgres:pass@host:5432

# ❌ 错误（有数据库名）
POSTGRES_ADMIN_URL=postgresql://postgres:pass@host:5432/mydb
```

## 下一步

- 阅读 [README.md](README.md) 了解详细功能
- 阅读 [CHANGES.md](CHANGES.md) 了解最新变化
- 阅读 [CONFIGURATION.md](CONFIGURATION.md) 了解配置原理
