# 故障排除指南

## 问题: `docker compose run` 不退出

### 症状
```bash
docker compose run --rm backup /usr/local/bin/backup-all.sh
# 命令执行完后容器一直运行，不自动退出
```

### 原因
旧版本的 `entrypoint.sh` 会无条件启动 cron 守护进程，导致容器一直运行。

### 解决方案

**1. 重新构建镜像**（最重要！）
```bash
cd infra-apps/backup
docker compose build --no-cache backup
```

**2. 验证修复**
```bash
# 应该立即退出（<1秒）
time docker compose run --rm backup echo "Test"
```

**3. 检查 entrypoint**
```bash
docker compose run --rm backup head -15 /entrypoint.sh
```

应该看到：
```bash
if [ $# -gt 0 ]; then
    echo "Executing command: $@"
    exec "$@"
fi
```

### 为什么需要重建？

Docker 镜像包含的是**构建时**的文件内容，不是实时文件系统：
- ❌ 修改 `entrypoint.sh` 不会影响已有镜像
- ✅ 必须重新构建镜像才能应用更改

## 问题: mise 任务挂起

### 症状
```bash
mise run dev:backup
# 一直挂起不退出
```

### 解决方案

```bash
# 1. 重建镜像
cd infra-apps/backup
docker compose build --no-cache backup

# 2. 再次运行 mise 任务
mise run dev:backup  # 现在应该正常退出了
```

## 问题: 修改脚本没有生效

### 症状
修改了 `scripts/backup-postgres.sh` 但运行时还是旧的逻辑。

### 原因
脚本在构建时被复制到镜像中，修改后需要重建。

### 解决方案
```bash
# 重建镜像
docker compose build backup

# 或完全重建
docker compose build --no-cache backup
```

## 问题: 查看日志失败

### 症状
```bash
./backup.sh logs
# 错误: Backup service is not running
```

### 原因
`logs` 命令需要服务在运行中（使用 `docker compose exec`）。

### 解决方案

**方式 1**: 启动服务
```bash
docker compose up -d
./backup.sh logs
```

**方式 2**: 查看一次性任务的输出
```bash
# 一次性任务直接输出到控制台
./backup.sh all  # 输出会直接显示
```

## 问题: 容器无法连接数据库

### 症状
```bash
./backup.sh test
# ERROR: POSTGRES_HOST or POSTGRES_ADMIN_URL not set
```

### 原因
1. `.env` 文件配置错误
2. 网络问题
3. 数据库服务未启动

### 解决方案

**1. 检查配置**
```bash
# 查看 .env 文件
cat .env

# 检查环境变量是否加载
docker compose run --rm backup env | grep POSTGRES
```

**2. 测试网络连接**
```bash
# 测试 PostgreSQL 端口
docker compose run --rm backup sh -c 'nc -zv postgres 5432'

# 测试 Redis 端口
docker compose run --rm backup sh -c 'nc -zv redis 6379'
```

**3. 确保数据库服务运行**
```bash
# 检查 postgres 服务
docker compose ps postgres

# 检查 redis 服务
docker compose ps redis
```

## 问题: 权限错误

### 症状
```bash
./backup.sh all
# ERROR: Permission denied: /backups/postgres/...
```

### 解决方案

**开发环境**:
```bash
# 检查本地目录权限
ls -la ./.local/backups/

# 修复权限
chmod -R 755 ./.local/backups/
```

**生产环境**:
```bash
# 确保目录存在且有权限
sudo mkdir -p /data/backups/{postgres,redis}
sudo chown -R $(id -u):$(id -g) /data/backups
```

## 问题: 磁盘空间不足

### 症状
```bash
./backup.sh all
# ERROR: No space left on device
```

### 解决方案

**1. 检查磁盘使用**
```bash
df -h
du -sh ./.local/backups/*
```

**2. 清理旧备份**
```bash
./backup.sh cleanup
```

**3. 调整保留策略**
编辑 `docker-compose.yml`:
```yaml
environment:
  BACKUP_RETENTION_LOCAL: 1  # 减少到1天
  BACKUP_RETENTION_S3: 7     # 减少到7天
```

**4. 启用 S3 备份**
配置 `.env`:
```bash
S3_BUCKET=my-backups
AWS_ACCESS_KEY_ID=xxx
AWS_SECRET_ACCESS_KEY=xxx
```

然后清理本地旧文件：
```bash
./backup.sh cleanup
```

## 问题: S3 上传失败

### 症状
```bash
./backup.sh all
# ERROR: Failed to upload to S3
```

### 解决方案

**1. 验证 S3 凭证**
```bash
docker compose run --rm backup aws s3 ls s3://$S3_BUCKET
```

**2. 检查网络**
```bash
docker compose run --rm backup ping -c 3 s3.amazonaws.com
```

**3. 检查配置**
```bash
# 查看 S3 配置
docker compose run --rm backup env | grep -E '(AWS|S3)'
```

## 快速诊断命令

```bash
# 1. 检查服务状态
docker compose ps

# 2. 测试连接
./backup.sh test

# 3. 查看配置
docker compose run --rm backup env | grep -E '(POSTGRES|REDIS|S3)'

# 4. 测试自动退出
time docker compose run --rm backup echo "Test"

# 5. 验证 entrypoint
docker compose run --rm backup head -15 /entrypoint.sh

# 6. 查看最近日志
docker compose logs --tail=50 backup
```

## 获取帮助

1. **查看文档**
   - [README.md](README.md) - 完整文档
   - [MANUAL_BACKUP.md](MANUAL_BACKUP.md) - 手动备份指南
   - [BUILD.md](BUILD.md) - 构建说明
   - [ENTRYPOINT_BEHAVIOR.md](ENTRYPOINT_BEHAVIOR.md) - Entrypoint 行为

2. **检查日志**
   ```bash
   ./backup.sh logs
   docker compose logs backup
   ```

3. **测试基础功能**
   ```bash
   ./backup.sh test
   ./backup.sh status
   ```
