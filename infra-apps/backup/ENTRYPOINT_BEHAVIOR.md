# Entrypoint 行为说明

## 问题

之前的 `entrypoint.sh` 会无条件启动 cron 守护进程，导致：
- ❌ `docker compose run --rm backup /command` 不会自动退出
- ❌ 一次性命令执行后容器会一直运行
- ❌ 用户体验不佳

## 解决方案

修改后的 `entrypoint.sh` 支持两种模式：

### 模式 1: 服务模式（无参数）

**使用场景**: 后台运行，定时自动备份

```bash
docker compose up -d
```

**行为**:
1. 创建备份目录
2. 配置 crontab
3. 显示配置信息
4. 启动 cron 守护进程（前台运行，不会退出）

### 模式 2: 命令模式（有参数）

**使用场景**: 手动执行一次性任务

```bash
docker compose run --rm backup /usr/local/bin/backup-all.sh
```

**行为**:
1. 创建备份目录
2. 直接执行传入的命令
3. 命令执行完毕后自动退出
4. `--rm` 参数会自动删除容器

## 实现原理

```bash
#!/bin/bash
set -e

# 创建备份目录
mkdir -p /backups/postgres /backups/redis

# 关键判断：如果有参数，直接执行命令并退出
if [ $# -gt 0 ]; then
    echo "Executing command: $@"
    exec "$@"  # exec 会替换当前进程，命令结束后容器就退出
fi

# 否则，启动 cron 服务（用于后台定时任务）
echo "Starting backup service..."
# ... 配置 cron ...
crond -f -l 2  # 前台运行，保持容器存活
```

## 使用示例

### 后台服务（定时备份）

```bash
# 启动服务
docker compose up -d

# 查看日志
docker compose logs -f backup

# 停止服务
docker compose down
```

### 一次性命令（手动备份）

```bash
# 完整备份（执行完自动退出）
docker compose run --rm backup /usr/local/bin/backup-all.sh

# 测试连接（执行完自动退出）
docker compose run --rm backup /usr/local/bin/test-connection.sh

# 清理旧备份（执行完自动退出）
docker compose run --rm backup /usr/local/bin/cleanup.sh
```

### 在运行中的容器执行命令

如果服务已经在运行（`docker compose up -d`），也可以使用 `exec`：

```bash
# 在运行中的容器内执行命令
docker compose exec backup /usr/local/bin/backup-all.sh
```

**注意**: `exec` 不会触发 entrypoint，直接在已有容器中执行命令。

## 对比

| 命令 | 启动新容器 | 自动清理 | 需要服务运行 | 触发 entrypoint |
|------|-----------|---------|------------|----------------|
| `docker compose run --rm backup /cmd` | ✅ | ✅ | ❌ | ✅ |
| `docker compose exec backup /cmd` | ❌ | N/A | ✅ | ❌ |
| `docker compose up -d` | ✅ | ❌ | N/A | ✅（无参数） |

## 推荐方式

### 手动备份推荐

使用 **`docker compose run --rm`**:
- ✅ 不依赖服务是否运行
- ✅ 自动清理容器
- ✅ 执行完自动退出

```bash
# 推荐
docker compose run --rm backup /usr/local/bin/backup-all.sh

# 或使用快捷脚本
./backup.sh all
```

### 查看日志推荐

使用 **`docker compose exec`**（如果服务在运行）:
- ✅ 更快（不创建新容器）
- ✅ 可以查看持久化的日志文件

```bash
# 推荐（服务运行时）
docker compose exec backup tail -f /var/log/backup.log

# 或使用快捷脚本
./backup.sh logs
```

## 快捷脚本已更新

`backup.sh` 和 `backup-prod.sh` 已更新为使用 `run --rm`：

```bash
# 开发环境
./backup.sh all      # 使用 docker compose run --rm
./backup.sh test     # 使用 docker compose run --rm
./backup.sh logs     # 使用 docker compose exec (如果服务运行)

# 生产环境
./backup-prod.sh all      # 使用 docker compose run --rm
./backup-prod.sh test     # 使用 docker compose run --rm
```

## 验证修复

```bash
# 1. 执行备份（应该自动退出）
time docker compose run --rm backup /usr/local/bin/test-connection.sh

# 2. 如果正确，命令会立即退出，不会挂起
# 3. 检查返回码
echo $?  # 应该是 0（成功）

# 4. 验证容器已被删除
docker compose ps -a | grep backup  # 不应该有 test-connection 相关的容器
```

## 故障排除

### 问题: 命令执行完不退出

**检查 entrypoint.sh**:
```bash
# 查看 entrypoint.sh 前几行
docker compose run --rm backup head -15 /entrypoint.sh
```

应该看到：
```bash
if [ $# -gt 0 ]; then
    echo "Executing command: $@"
    exec "$@"
fi
```

### 问题: 容器没有自动删除

确保使用了 `--rm` 参数：
```bash
# ✅ 正确
docker compose run --rm backup /usr/local/bin/backup-all.sh

# ❌ 错误（容器不会删除）
docker compose run backup /usr/local/bin/backup-all.sh
```

## 升级说明

如果你使用的是旧版本：

1. **更新代码**: 拉取最新代码
2. **重建镜像**: `docker compose build backup`
3. **重启服务**: `docker compose up -d --force-recreate`
4. **测试**: `./backup.sh test`
