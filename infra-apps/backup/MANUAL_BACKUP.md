# 手动备份操作指南

## 开发环境

### 前提条件
确保备份服务已启动：
```bash
cd infra-apps/backup
docker compose ps backup
```

### 方式 1: 在运行的容器中执行（推荐）

```bash
# 备份所有服务（PostgreSQL + Redis）
docker compose exec backup /usr/local/bin/backup-all.sh

# 只备份 PostgreSQL
docker compose exec backup /usr/local/bin/backup-postgres.sh

# 只备份 Redis
docker compose exec backup /usr/local/bin/backup-redis.sh

# 清理旧备份
docker compose exec backup /usr/local/bin/cleanup-smart.sh
```

### 方式 2: 创建临时容器执行

如果服务未启动，可以创建临时容器：

```bash
# 备份所有服务
docker compose run --rm backup /usr/local/bin/backup-all.sh

# 只备份 PostgreSQL
docker compose run --rm backup /usr/local/bin/backup-postgres.sh

# 只备份 Redis
docker compose run --rm backup /usr/local/bin/backup-redis.sh
```

### 查看备份结果

```bash
# 查看 PostgreSQL 备份
ls -lh ./.local/backups/postgres/

# 查看 Redis 备份
ls -lh ./.local/backups/redis/

# 查看最新的备份
ls -lt ./.local/backups/postgres/ | head -5
ls -lt ./.local/backups/redis/ | head -5
```

## 生产环境

### 方式 1: 从本地触发（推荐）

使用 Ansible 从本地触发生产环境备份，无需 SSH：

```bash
# 使用 mise 快捷命令
mise run backup

# 或直接使用 ansible-playbook
ansible-playbook -i ansible/inventory.yml ansible/playbooks/run-backup.yml
```

### 方式 2: 在服务器上执行

SSH 到生产服务器后：

```bash
# 进入备份目录
cd /srv/studio/infra-apps/backup

# 确保服务已启动
docker compose ps backup

# 在运行的容器中执行（推荐）
docker compose exec backup /usr/local/bin/backup-all.sh
docker compose exec backup /usr/local/bin/backup-postgres.sh
docker compose exec backup /usr/local/bin/backup-redis.sh

# 或创建临时容器执行
docker compose run --rm backup /usr/local/bin/backup-all.sh
```

### 查看备份结果

```bash
# 查看备份文件（在服务器上）
ls -lh /data/backups/postgres/
ls -lh /data/backups/redis/

# 查看最新的备份
ls -lt /data/backups/postgres/ | head -5
ls -lt /data/backups/redis/ | head -5

# 查看备份文件大小统计
du -sh /data/backups/*
```

## 快捷脚本

为了方便操作，可以创建快捷脚本。

### 开发环境快捷脚本

创建 `infra-apps/backup/backup.sh`:

```bash
#!/bin/bash
set -e

cd "$(dirname "$0")"

case "$1" in
  all)
    docker compose exec backup /usr/local/bin/backup-all.sh
    ;;
  postgres)
    docker compose exec backup /usr/local/bin/backup-postgres.sh
    ;;
  redis)
    docker compose exec backup /usr/local/bin/backup-redis.sh
    ;;
  cleanup)
    docker compose exec backup /usr/local/bin/cleanup-smart.sh
    ;;
  test)
    docker compose exec backup /usr/local/bin/test-connection.sh
    ;;
  logs)
    docker compose exec backup tail -f /var/log/backup.log
    ;;
  list)
    echo "PostgreSQL backups:"
    ls -lh ./.local/backups/postgres/
    echo ""
    echo "Redis backups:"
    ls -lh ./.local/backups/redis/
    ;;
  *)
    echo "Usage: $0 {all|postgres|redis|cleanup|test|logs|list}"
    echo ""
    echo "Commands:"
    echo "  all      - Backup all services (PostgreSQL + Redis)"
    echo "  postgres - Backup PostgreSQL only"
    echo "  redis    - Backup Redis only"
    echo "  cleanup  - Clean up old backups"
    echo "  test     - Test database connections"
    echo "  logs     - View backup logs"
    echo "  list     - List backup files"
    exit 1
    ;;
esac
```

使用方法：

```bash
chmod +x backup.sh

# 备份所有服务
./backup.sh all

# 只备份 PostgreSQL
./backup.sh postgres

# 查看日志
./backup.sh logs

# 列出备份文件
./backup.sh list
```

### 生产环境操作

#### 从本地触发（推荐）

使用 Ansible 从本地触发生产环境备份：

```bash
# 触发完整备份
mise run backup

# 或直接使用 ansible-playbook
ansible-playbook -i ansible/inventory.yml ansible/playbooks/run-backup.yml
```

#### 直接在服务器上操作

SSH 到生产服务器后：

```bash
cd /srv/studio/infra-apps/backup

# 完整备份
docker compose run --rm backup /usr/local/bin/backup-all.sh

# PostgreSQL 备份
docker compose run --rm backup /usr/local/bin/backup-postgres.sh

# Redis 备份
docker compose run --rm backup /usr/local/bin/backup-redis.sh

# 智能清理
docker compose run --rm backup /usr/local/bin/cleanup-smart.sh

# 测试连接
docker compose run --rm backup /usr/local/bin/test-connection.sh

# 查看日志
docker compose exec backup tail -f /var/log/backup.log

# 列出备份文件
ls -lh /data/backups/postgres/
ls -lh /data/backups/redis/
```

## 查看备份日志

### 实时查看日志

```bash
# 本地开发环境
docker compose exec backup tail -f /var/log/backup.log

# 生产服务器上（SSH 后）
cd /srv/studio/infra-apps/backup
docker compose exec backup tail -f /var/log/backup.log
```

### 查看最近的日志

```bash
# 本地开发环境
docker compose exec backup tail -100 /var/log/backup.log

# 生产服务器上（SSH 后）
cd /srv/studio/infra-apps/backup
docker compose exec backup tail -100 /var/log/backup.log
```

### 搜索日志中的错误

```bash
# 本地开发环境
docker compose exec backup grep -i error /var/log/backup.log

# 生产服务器上（SSH 后）
cd /srv/studio/infra-apps/backup
docker compose exec backup grep -i error /var/log/backup.log
```

## 测试连接

在执行备份前，建议先测试数据库连接：

```bash
# 本地开发环境
docker compose exec backup /usr/local/bin/test-connection.sh

# 生产服务器上（SSH 后）
cd /srv/studio/infra-apps/backup
docker compose exec backup /usr/local/bin/test-connection.sh
```

## 常见场景

### 场景 1: 升级前备份

```bash
# 1. 测试连接
docker compose exec backup /usr/local/bin/test-connection.sh

# 2. 执行完整备份
docker compose exec backup /usr/local/bin/backup-all.sh

# 3. 验证备份文件
ls -lh ./.local/backups/postgres/
ls -lh ./.local/backups/redis/

# 4. 继续升级操作...
```

### 场景 2: 定期手动备份

```bash
# 每周执行一次完整备份
docker compose exec backup /usr/local/bin/backup-all.sh

# 上传到 S3（如果配置了 S3）
# 备份脚本会自动上传
```

### 场景 3: 迁移前备份

```bash
# 1. 完整备份
docker compose exec backup /usr/local/bin/backup-all.sh

# 2. 下载备份文件到本地
scp user@server:/data/backups/postgres/postgres-all-*.sql.gz ./
scp user@server:/data/backups/redis/redis-*.rdb ./

# 3. 在新服务器恢复
```

### 场景 4: 紧急备份

```bash
# 快速创建备份（使用临时容器，不依赖服务状态）
docker compose run --rm backup /usr/local/bin/backup-all.sh
```

## 故障排除

### 备份失败

```bash
# 1. 查看详细日志
docker compose exec backup tail -100 /var/log/backup.log

# 2. 测试连接
docker compose exec backup /usr/local/bin/test-connection.sh

# 3. 检查环境变量
docker compose exec backup env | grep -E '(POSTGRES|REDIS|S3)'

# 4. 手动测试 PostgreSQL 连接
docker compose exec backup sh -c 'pg_isready -h $POSTGRES_HOST -p ${POSTGRES_PORT:-5432} -U $POSTGRES_USER'

# 5. 手动测试 Redis 连接
docker compose exec backup sh -c 'redis-cli -h $REDIS_HOST -p ${REDIS_PORT:-6379} ping'
```

### 磁盘空间不足

```bash
# 1. 查看磁盘使用情况
df -h

# 2. 查看备份目录大小
du -sh /data/backups/*

# 3. 手动清理旧备份
docker compose exec backup /usr/local/bin/cleanup-smart.sh

# 4. 查看清理后的结果
ls -lh /data/backups/postgres/
```

## 最佳实践

1. **备份前测试连接**
   ```bash
   docker compose exec backup /usr/local/bin/test-connection.sh
   ```

2. **验证备份文件**
   ```bash
   # 检查文件是否存在且不为空
   ls -lh ./.local/backups/postgres/
   ```

3. **保留重要备份**
   ```bash
   # 在重要操作前，手动复制备份到安全位置
   cp ./.local/backups/postgres/postgres-all-*.sql.gz /safe/location/
   ```

4. **定期测试恢复**
   ```bash
   # 定期测试备份文件能否正常恢复
   gunzip -t postgres-all-20250116-020000.sql.gz
   ```

5. **监控备份任务**
   ```bash
   # 定期检查日志
   docker compose exec backup tail -50 /var/log/backup.log
   ```
