# 通用备份系统

基于 Docker 的通用备份系统，用于自动备份 PostgreSQL 和 Redis 数据库。支持本地备份和 S3 远程备份。

## 功能特性

- **自动化备份**: 使用 cron 定时任务自动执行备份
- **完整数据库备份**: PostgreSQL 使用 `pg_dumpall` 备份所有数据库（包括角色、权限）
- **多数据库支持**: 支持 PostgreSQL 和 Redis
- **URL 配置**: 使用简洁的 URL 格式配置数据库连接
- **本地备份**: 备份文件存储在本地目录
- **S3 远程备份**: 可选的 S3 云存储备份（支持 AWS S3、MinIO 等）
- **自动清理**: 根据配置的保留策略自动清理旧备份
- **灵活调度**: 支持自定义 cron 调度表达式
- **健康检查**: 内置健康检查机制
- **完整日志**: 完整的备份日志记录

## 目录结构

```
backup/
├── Dockerfile                  # Docker 镜像定义
├── docker-compose.yml          # 开发环境配置
├── docker-compose.prod.yml     # 生产环境配置
├── entrypoint.sh              # 容器入口脚本
├── .env.example               # 环境变量示例（仅敏感信息）
├── .gitignore                 # Git 忽略规则
├── README.md                  # 本文档
├── scripts/                   # 备份脚本目录
│   ├── parse-url.sh          # URL 解析工具
│   ├── backup-postgres.sh    # PostgreSQL 备份脚本
│   ├── backup-redis.sh       # Redis 备份脚本
│   ├── backup-all.sh         # 完整备份脚本
│   ├── cleanup-smart.sh      # 智能清理脚本 (本地 + S3)
│   ├── restore-postgres-local.sh  # 本地恢复脚本
│   └── restore-postgres-s3.sh     # S3 恢复脚本
└── .local/
    └── backups/              # 本地备份存储目录（开发环境）
        ├── postgres/
        └── redis/
```

## 快速开始

### 1. 配置环境变量

复制示例配置文件并修改：

```bash
cp .env.example .env
```

编辑 `.env` 文件，配置数据库连接：

```bash
# PostgreSQL URL（备份所有数据库，无需指定数据库名）
POSTGRES_ADMIN_URL=postgresql://postgres:your_password@postgres:5432

# Redis URL
REDIS_DOCKER_URL=redis://:your_password@redis:6379
```

### 2. 构建镜像

**重要**: 首次使用或修改脚本后需要构建镜像

```bash
# 使用快捷脚本
./build.sh

# 或使用 docker compose
docker compose build backup

# 完全重建（推荐）
docker compose build --no-cache backup
```

### 3. 启动备份服务

**开发环境:**

```bash
docker compose up -d
```

**生产环境:**

```bash
# 先构建镜像
docker build -t backup:latest .

# 使用生产配置启动
docker compose -f docker-compose.prod.yml up -d
```

### 4. 验证

```bash
docker compose logs -f backup
```

## 配置说明

### 环境变量（.env 文件）

**只需要配置敏感信息**，非敏感配置已在 `docker-compose.yml` 中设置。

`.env` 文件通过 `env_file` 自动加载，无需在 `docker-compose.yml` 中重复声明：

```bash
# 数据库连接 URL（必填）
# PostgreSQL: 备份所有数据库，无需指定数据库名
POSTGRES_ADMIN_URL=postgresql://user:password@host:port

# Redis: 指定主机和端口
REDIS_DOCKER_URL=redis://:password@host:port

# S3 配置（可选）
AWS_ACCESS_KEY_ID=your_access_key
AWS_SECRET_ACCESS_KEY=your_secret_key
S3_BUCKET=my-backup-bucket
S3_ENDPOINT=https://s3.example.com  # 可选，用于 MinIO 等
```

**配置原理：**
- `env_file: - .env` 会自动将 `.env` 中的所有变量加载到容器
- `environment:` 块只定义非敏感的配置（备份策略、调度时间等）
- 不需要在 `environment` 中重复声明 `.env` 中的变量

### URL 格式说明

#### PostgreSQL URL

**格式**（不需要指定数据库名，使用 `pg_dumpall` 备份所有数据库）:
```
postgresql://user:password@host:port
```

**示例**:
- `postgresql://postgres:secret123@localhost:5432`
- `postgresql://user:pass@postgres:5432`

**备份说明**:
- 使用 `pg_dumpall` 命令备份所有数据库
- 包括所有数据库、角色、权限、表空间等
- 备份文件命名: `postgres-all-YYYYMMDD-HHMMSS.sql.gz`

#### Redis URL

```
redis://:password@host:port
```

示例:
- `redis://:secret123@localhost:6379`
- `redis://localhost:6379` (无密码)

### 开发 vs 生产环境

| 配置项 | 开发环境 | 生产环境 |
|--------|---------|---------|
| 配置文件 | `docker-compose.yml` | `docker-compose.prod.yml` |
| 备份路径 | `./.local/backups` | `/data/backups` |
| 本地保留 | 3 天 | 7 天 |
| S3 保留 | 30 天 | 90 天 |
| 日志大小 | 10MB × 3 | 50MB × 5 |

### 自定义调度（可选）

如需修改备份时间，直接编辑 `docker-compose.yml` 或 `docker-compose.prod.yml` 中的 `environment` 块：

```yaml
environment:
  POSTGRES_SCHEDULE: "0 2 * * *"    # 每天凌晨2点
  REDIS_SCHEDULE: "0 3 * * *"       # 每天凌晨3点
  CLEANUP_SCHEDULE: "0 5 * * *"     # 每天凌晨5点
  FULL_BACKUP_SCHEDULE: "0 4 * * 0" # 每周日凌晨4点
```

这些是非敏感配置，直接写在 compose 文件中即可，**无需放在 .env 文件中**。

Cron 格式: `分 时 日 月 周`

常用示例:
- `0 2 * * *` - 每天凌晨2点
- `0 */6 * * *` - 每6小时
- `0 2 * * 0` - 每周日凌晨2点
- `0 2 1 * *` - 每月1号凌晨2点

## 手动执行备份

### 备份 PostgreSQL

```bash
docker compose exec backup /usr/local/bin/backup-postgres.sh
```

### 备份 Redis

```bash
docker compose exec backup /usr/local/bin/backup-redis.sh
```

### 执行完整备份

```bash
docker compose exec backup /usr/local/bin/backup-all.sh
```

### 手动清理旧备份

```bash
docker compose exec backup /usr/local/bin/cleanup-smart.sh
```

## 备份文件格式

### PostgreSQL

- 格式: `postgres-all-YYYYMMDD-HHMMSS.sql.gz`
- 示例: `postgres-all-20250116-020000.sql.gz`
- 内容: 使用 `pg_dumpall` 生成，包含所有数据库、角色、权限
- 压缩: gzip 压缩的 SQL 文件

### Redis

- 格式: `redis-YYYYMMDD-HHMMSS.rdb`
- 示例: `redis-20250116-030000.rdb`
- 格式: Redis RDB 快照文件

## S3 存储结构

备份文件在 S3 中按日期组织：

```
s3://bucket-name/
├── postgres/
│   ├── 20250116/
│   │   ├── postgres-all-20250116-020000.sql.gz
│   │   └── postgres-all-20250116-020005.sql.gz
│   └── 20250117/
│       └── postgres-all-20250117-020000.sql.gz
└── redis/
    ├── 20250116/
    │   └── redis-20250116-030000.rdb
    └── 20250117/
        └── redis-20250117-030000.rdb
```

## 数据恢复

### 恢复 PostgreSQL

**重要提示**: 使用 `pg_dumpall` 生成的备份包含所有数据库，恢复时会覆盖现有数据库。

**从本地备份恢复:**

```bash
# 解压并直接恢复到 PostgreSQL
gunzip -c postgres-all-20250116-020000.sql.gz | psql -h postgres_host -U postgres -d postgres

# 或者先解压，再恢复
gunzip postgres-all-20250116-020000.sql.gz
psql -h postgres_host -U postgres -d postgres -f postgres-all-20250116-020000.sql
```

**使用 Docker:**

```bash
# 开发环境
gunzip -c ./.local/backups/postgres/postgres-all-20250116-020000.sql.gz | \
  docker compose exec -T postgres psql -U postgres -d postgres

# 生产环境
gunzip -c /data/backups/postgres/postgres-all-20250116-020000.sql.gz | \
  docker compose -f docker-compose.prod.yml exec -T postgres psql -U postgres -d postgres
```

**从 S3 恢复:**

```bash
# 下载并直接恢复
aws s3 cp s3://bucket-name/postgres/20250116/postgres-all-20250116-020000.sql.gz - | \
  gunzip | psql -h postgres_host -U postgres -d postgres

# 或者先下载
aws s3 cp s3://bucket-name/postgres/20250116/postgres-all-20250116-020000.sql.gz .
gunzip -c postgres-all-20250116-020000.sql.gz | psql -U postgres -d postgres
```

**恢复说明**:
- `pg_dumpall` 备份包含所有数据库、用户、角色、权限
- 恢复时会自动创建数据库和用户
- 建议在恢复前先停止应用服务，避免数据冲突

### 恢复 Redis

**从本地备份恢复:**

```bash
# 1. 停止 Redis 服务
docker compose stop redis

# 2. 复制 RDB 文件到 Redis 数据目录
# 注意：具体路径取决于你的 Redis 配置

# 3. 启动 Redis 服务
docker compose start redis
```

**从 S3 恢复:**

```bash
# 下载备份
aws s3 cp s3://bucket-name/redis/20250116/redis-20250116-030000.rdb dump.rdb

# 复制到 Redis 数据目录并重启服务
```

## 生产环境部署

### 1. 准备环境

```bash
# 创建备份目录
sudo mkdir -p /data/backups/{postgres,redis}
sudo chown -R $(id -u):$(id -g) /data/backups
```

### 2. 构建镜像

```bash
docker build -t backup:latest .
```

### 3. 配置环境变量

```bash
cp .env.example .env
# 编辑 .env，填入生产环境的数据库 URL 和 S3 配置
```

### 4. 启动服务

```bash
docker compose -f docker-compose.prod.yml up -d
```

### 5. 验证

```bash
# 查看日志
docker compose -f docker-compose.prod.yml logs -f backup

# 手动执行一次备份测试
docker compose -f docker-compose.prod.yml exec backup /usr/local/bin/backup-all.sh

# 检查备份文件
ls -lh /data/backups/postgres/
ls -lh /data/backups/redis/
```

## 监控和日志

### 查看备份日志

```bash
docker compose exec backup tail -f /var/log/backup.log
```

### 检查备份状态

```bash
# 查看本地备份文件
docker compose exec backup ls -lh /backups/postgres
docker compose exec backup ls -lh /backups/redis

# 查看 S3 备份
docker compose exec backup aws s3 ls s3://your-bucket/postgres/
```

### 健康检查

```bash
docker compose ps
```

## 故障排除

### 备份失败

1. **检查日志:**
   ```bash
   docker compose logs backup
   docker compose exec backup tail -100 /var/log/backup.log
   ```

2. **验证数据库连接:**
   ```bash
   # 测试 PostgreSQL 连接
   docker compose exec backup sh -c 'source /usr/local/bin/parse-url.sh && parse_POSTGRES_ADMIN_URL "$POSTGRES_ADMIN_URL" && pg_isready -h $PG_HOST -U $PG_USER'
   
   # 测试 Redis 连接
   docker compose exec backup sh -c 'redis-cli -u "$REDIS_DOCKER_URL" ping'
   ```

3. **检查环境变量:**
   ```bash
   docker compose exec backup env | grep -E '(POSTGRES|REDIS|S3)'
   ```

### S3 上传失败

1. **验证 AWS 凭证:**
   ```bash
   docker compose exec backup aws s3 ls s3://$S3_BUCKET
   ```

2. **检查网络连接:**
   ```bash
   docker compose exec backup wget -O- $S3_ENDPOINT
   ```

### 磁盘空间不足

```bash
# 查看磁盘使用情况
docker compose exec backup df -h /backups

# 手动清理旧备份
docker compose exec backup /usr/local/bin/cleanup-smart.sh

# 或者调整保留策略（修改 docker-compose.yml）
```

### URL 格式错误

如果遇到 URL 解析错误，请检查格式：

```bash
# 正确的格式
POSTGRES_ADMIN_URL=postgresql://user:password@host:5432  # 不需要数据库名
REDIS_DOCKER_URL=redis://:password@host:6379

# 常见错误
❌ POSTGRES_ADMIN_URL=postgresql://user:password@host:5432/database  # 多余的数据库名
❌ POSTGRES_ADMIN_URL=postgres@host:5432           # 缺少协议和密码
❌ REDIS_DOCKER_URL=redis://password@host:6379      # Redis 密码前需要冒号
```

## 与现有服务集成

### 方式 1: 使用共享网络

```yaml
# 在你的主 docker-compose.yml 中
networks:
  shared:
    driver: bridge
    external: false

services:
  postgres:
    networks:
      - shared
  
  redis:
    networks:
      - shared
```

### 方式 2: 使用服务名称

如果 backup 服务与数据库在同一个 compose 文件中：

```yaml
services:
  postgres:
    # ...
  
  redis:
    # ...
  
  backup:
    depends_on:
      - postgres
      - redis
    environment:
      POSTGRES_ADMIN_URL: postgresql://postgres:password@postgres:5432/postgres
      REDIS_DOCKER_URL: redis://:password@redis:6379
```

## 安全建议

1. **保护 .env 文件**: 
   ```bash
   chmod 600 .env
   echo ".env" >> .gitignore
   ```

2. **使用强密码**: 为数据库使用强密码

3. **限制网络访问**: 仅允许备份服务访问数据库

4. **加密 S3 备份**: 启用 S3 服务端加密
   ```bash
   # AWS CLI 示例
   aws s3api put-bucket-encryption \
     --bucket my-backup-bucket \
     --server-side-encryption-configuration '{"Rules":[{"ApplyServerSideEncryptionByDefault":{"SSEAlgorithm":"AES256"}}]}'
   ```

5. **定期测试恢复**: 定期测试备份文件的恢复过程

6. **监控备份任务**: 设置告警监控备份任务的成功/失败状态

## 许可证

MIT
