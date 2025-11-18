# 修复总结

## 已解决的问题

### 1. 命令不自动退出 ✅

**问题**: `docker compose run --rm backup` 执行完不退出

**原因**: `entrypoint.sh` 无条件启动 cron 守护进程

**解决**:
```bash
# entrypoint.sh 现在支持两种模式
if [ $# -gt 0 ]; then
    exec "$@"  # 有参数：直接执行命令并退出
fi
# 无参数：启动 cron 服务
```

**验证**:
```bash
time docker compose run --rm backup echo "Test"
# 应该 <1 秒退出
```

### 2. localhost 连接问题 ✅

**问题**: 
```
Connection refused to localhost:5432
Connection refused to localhost:6379
```

**原因**: 在 Docker 容器内，`localhost` 指容器自己，不是宿主机

**解决**: 修改 `.env` 使用正确的地址
```bash
# ❌ 错误
POSTGRES_ADMIN_URL=postgresql://postgres:password@localhost:5432
REDIS_DOCKER_URL=redis://default:password@localhost:6379

# ✅ 正确（数据库在 Docker 中）
POSTGRES_ADMIN_URL=postgresql://postgres:password@postgres:5432
REDIS_DOCKER_URL=redis://:password@redis:6379

# ✅ 正确（数据库在宿主机）
POSTGRES_ADMIN_URL=postgresql://postgres:password@host.docker.internal:5432
REDIS_DOCKER_URL=redis://:password@host.docker.internal:6379
```

### 3. Redis URL 格式错误 ✅

**问题**: 
```
Could not connect to Redis at default:password@localhost:6379
```

**原因**: Redis URL 格式错误，Redis 没有 username

**解决**:
```bash
# ❌ 错误（有 username）
REDIS_DOCKER_URL=redis://default:password@redis:6379

# ✅ 正确（密码前有冒号）
REDIS_DOCKER_URL=redis://:password@redis:6379
```

### 4. PostgreSQL 版本不匹配 ✅

**问题**: 
```
pg_dumpall: error: server version mismatch
server version: 18.0; pg_dumpall version: 17.7
```

**原因**: Alpine 默认安装 PostgreSQL 17 客户端，但服务器是 18.0

**解决**: 修改 Dockerfile 使用 edge 仓库获取 PostgreSQL 18
```dockerfile
# 添加 edge 仓库
RUN echo "https://dl-cdn.alpinelinux.org/alpine/edge/main" >> /etc/apk/repositories

# 安装 PostgreSQL 18 客户端
RUN apk add --no-cache postgresql18-client
```

## 最终配置

### .env 文件
```bash
# 数据库连接（使用 Docker 服务名）
POSTGRES_ADMIN_URL=postgresql://postgres:root123456@postgres:5432
REDIS_DOCKER_URL=redis://:dev_password_change_in_production@redis:6379

# S3 配置
S3_BUCKET=owen-studio-dev
S3_ENDPOINT=https://s3.us-east-005.backblazeb2.com
AWS_ACCESS_KEY_ID=xxx
AWS_SECRET_ACCESS_KEY=xxx
```

### Dockerfile
```dockerfile
FROM alpine:latest

# 添加 edge 仓库获取 PostgreSQL 18
RUN echo "https://dl-cdn.alpinelinux.org/alpine/edge/main" >> /etc/apk/repositories

# 安装 PostgreSQL 18 客户端
RUN apk add --no-cache \
    postgresql18-client \
    redis \
    aws-cli \
    dcron \
    bash \
    gzip \
    coreutils \
    findutils
```

## 验证步骤

### 1. 测试连接
```bash
docker compose run --rm backup /usr/local/bin/test-connection.sh
```

应该看到：
```
✅ Connected
  Databases:
    - postgres
    - demo

✅ Connected
  Version: 8.2.2
```

### 2. 测试备份
```bash
docker compose run --rm backup /usr/local/bin/backup-all.sh
```

应该看到：
```
Postgres backup: SUCCESS  (文件大小 > 2KB)
Redis backup: SUCCESS     (文件大小 > 200B)
Full backup completed successfully
```

### 3. 验证自动退出
```bash
time docker compose run --rm backup echo "Test"
```

应该 < 1 秒退出

### 4. 检查备份文件
```bash
ls -lh ./.local/backups/postgres/
ls -lh ./.local/backups/redis/
```

PostgreSQL 备份应该 > 2KB（不是 20 bytes）

## 使用 mise 任务

现在可以正常使用：
```bash
mise run dev:backup
```

应该：
- ✅ 正常连接数据库
- ✅ 成功备份 PostgreSQL（所有数据库）
- ✅ 成功备份 Redis
- ✅ 上传到 S3
- ✅ 命令自动退出

## 备份文件大小参考

- **PostgreSQL**: 
  - 空数据库：~2-3 KB
  - 有数据：根据实际数据量
  - ⚠️ 如果是 20 bytes，说明备份失败

- **Redis**:
  - 空数据库：~200 bytes
  - 有数据：根据实际数据量

## 常见问题

### Q: 修改脚本后没有生效？

**A**: 需要重建镜像
```bash
docker compose build --no-cache backup
```

### Q: 还是连接不上数据库？

**A**: 检查 `.env` 中的地址：
- 数据库在 Docker 中：使用服务名（`postgres`, `redis`）
- 数据库在宿主机：使用 `host.docker.internal`

### Q: PostgreSQL 版本还是不匹配？

**A**: 确认已重建镜像，并检查版本：
```bash
docker compose run --rm backup pg_dump --version
# 应该显示：pg_dump (PostgreSQL) 18.0
```

### Q: Redis URL 格式总是错误？

**A**: 记住 Redis 密码前必须有冒号：
```bash
redis://:password@host:port  # ✅ 正确
redis://password@host:port   # ❌ 错误
```

## 下一步

1. **定时备份**: 服务已配置自动备份
   ```bash
   docker compose up -d  # 启动定时备份服务
   ```

2. **查看日志**: 监控备份执行情况
   ```bash
   ./backup.sh logs
   ```

3. **配置保留策略**: 根据需要调整（在 `docker-compose.yml`）
   ```yaml
   BACKUP_RETENTION_LOCAL: 3   # 本地保留3天
   BACKUP_RETENTION_S3: 30     # S3保留30天
   ```

4. **测试恢复**: 定期测试备份恢复
   ```bash
   gunzip -c backups/postgres/postgres-all-*.sql.gz | head -20
   ```
