# UTC 时区标准化文档

## 问题背景

在分布式系统中，如果构建机器、服务器和备份系统使用不同的时区，会导致：

1. **版本号不一致**：同一时刻构建的版本在不同机器上产生不同的版本号
2. **备份时间混乱**：备份文件的时间戳难以比较和排序
3. **清理策略错误**：基于日期的保留策略可能因时区差异而出错
4. **日志时间不准**：跨系统的日志难以关联

## 解决方案

统一使用 **UTC 时区**进行所有时间戳和版本号生成。

## 修改清单

### 1. 构建系统 (scripts/build-lib.sh)

**修改前**:
```bash
get_version() {
  date +%Y%m%d%H%M%S
}
```

**修改后**:
```bash
# 使用 UTC 时区避免不同机器时区差异
get_version() {
  date -u +%Y%m%d%H%M%S
}
```

**影响**:
- 所有应用的版本号（Docker 镜像标签、部署目录名）
- 确保全球任何位置构建的版本号一致

### 2. 备份系统

#### 2.1 backup-postgres.sh

**修改**:
```bash
# 使用 UTC 时区避免不同机器时区差异
TIMESTAMP=$(date -u +%Y%m%d-%H%M%S)
DATE=$(date -u +%Y%m%d)
```

**影响**:
- PostgreSQL 备份文件名和 S3 路径
- 例如：`postgres-all-20251121032005.sql.gz` 使用 UTC 时间

#### 2.2 backup-redis.sh

**修改**:
```bash
# 使用 UTC 时区避免不同机器时区差异
TIMESTAMP=$(date -u +%Y%m%d-%H%M%S)
DATE=$(date -u +%Y%m%d)
```

**影响**:
- Redis 备份文件名和 S3 路径

#### 2.3 restore-postgres-s3.sh

**修改**:
```bash
# 使用 UTC 时间戳避免时区差异
TEMP_FILE="/tmp/restore-$(date -u +%s).sql.gz"
```

**影响**:
- 临时恢复文件名（使用 Unix 时间戳）

### 3. 清理系统

#### 3.1 cleanup-s3-smart.sh

**修改**:
```bash
# 计算关键日期（使用 UTC 时区）
TODAY=$(date -u +%Y%m%d)
SEVEN_DAYS_AGO=$(date -u -d "7 days ago" +%Y%m%d 2>/dev/null || date -u -v-7d +%Y%m%d)
THIRTY_DAYS_AGO=$(date -u -d "30 days ago" +%Y%m%d 2>/dev/null || date -u -v-30d +%Y%m%d)
NINETY_DAYS_AGO=$(date -u -d "90 days ago" +%Y%m%d 2>/dev/null || date -u -v-90d +%Y%m%d)

# 星期计算
DAY_OF_WEEK=$(date -u -d "$folder_date" +%w 2>/dev/null || \
              date -u -j -f "%Y%m%d" "$folder_date" +%w 2>/dev/null || echo "")
```

**影响**:
- 备份保留策略计算
- 确保在任何时区的服务器上运行都得到相同的清理结果

#### 3.2 list-s3-postgres.sh

**修改**:
```bash
# 计算距今天数（使用 UTC 时区）
TODAY=$(date -u +%Y%m%d)
DAYS_AGO=$(( ($(date -u +%s) - $(date -u -d "$date" +%s 2>/dev/null || date -u -j -f "%Y%m%d" "$date" +%s)) / 86400 ))
```

**影响**:
- 备份列表显示的天数计算
- "today", "yesterday", "N days ago" 的判断

## 验证方法

### 1. 验证版本号使用 UTC

```bash
# 在不同时区测试
TZ=America/New_York bash -c 'source scripts/build-lib.sh && get_version'
TZ=Asia/Shanghai bash -c 'source scripts/build-lib.sh && get_version'
TZ=Europe/London bash -c 'source scripts/build-lib.sh && get_version'

# 应该返回相同的版本号（±1秒内）
```

### 2. 验证备份时间戳

```bash
# 检查备份文件名使用 UTC
docker compose -f infra-apps/backup/docker-compose.yml run --rm backup /usr/local/bin/backup-postgres.sh

# 查看 S3 备份路径
mise run restore-postgres-s3-list

# 路径应该是 YYYYMMDD 格式，基于 UTC
```

### 3. 验证清理策略

```bash
# 在不同时区测试清理脚本
TZ=Asia/Tokyo docker compose -f infra-apps/backup/docker-compose.yml run --rm backup /usr/local/bin/cleanup-s3-smart.sh

# 清理决策应该一致
```

## 注意事项

### 1. 日志时间戳

**未修改**: 脚本中的日志时间戳 `[$(date)]` 仍使用本地时区

**原因**:
- 日志时间戳主要用于人类可读性
- 服务器日志通常在同一时区查看
- 如果需要跨时区关联，可以查看 Docker 日志的 UTC 时间戳

**如需修改**:
```bash
# 将所有 echo "[$(date)]" 改为
echo "[$(date -u '+%Y-%m-%d %H:%M:%S UTC')]"
```

### 2. Cron 任务时区

Cron 任务的执行时间基于服务器本地时区，但：
- 备份文件使用 UTC 命名
- 清理策略基于 UTC 计算
- 两者互不影响

**示例**:
```cron
# 服务器时间 CST (UTC+8) 凌晨 2 点执行
0 2 * * * /usr/local/bin/backup-postgres.sh
# 但生成的文件名是 UTC 时间（前一天 18:00）
# 例如：postgres-all-20251120-180000.sql.gz
```

### 3. 跨平台兼容性

脚本支持 Linux (GNU date) 和 macOS (BSD date)：

```bash
# Linux
date -u -d "7 days ago" +%Y%m%d

# macOS
date -u -v-7d +%Y%m%d

# 脚本使用 fallback
date -u -d "7 days ago" +%Y%m%d 2>/dev/null || date -u -v-7d +%Y%m%d
```

## 迁移指南

### 对于现有系统

如果系统已经在运行，切换到 UTC 后：

1. **版本号变化**:
   - 新构建的版本号会使用 UTC 时间
   - 旧版本号（本地时区）仍然有效
   - 版本保留策略会继续工作

2. **备份文件**:
   - 新备份使用 UTC 时间戳
   - 旧备份（本地时区）仍然可以列出和恢复
   - S3 路径按字典序排列，两种格式兼容

3. **清理策略**:
   - 首次运行可能会根据 UTC 重新评估保留
   - 建议在低峰期首次运行
   - 可以先用 dry-run 模式测试

### 检查清单

升级前检查：

- [ ] 备份当前所有版本列表
- [ ] 记录当前 S3 备份路径
- [ ] 测试新版本号生成
- [ ] 验证备份脚本
- [ ] 验证清理脚本（dry-run）

## 最佳实践

### 1. 文档中明确标注时区

```bash
# 好的做法：注释中说明使用 UTC
TIMESTAMP=$(date -u +%Y%m%d-%H%M%S)  # UTC timestamp

# 避免：让人猜测是什么时区
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
```

### 2. 日志输出包含时区信息

```bash
echo "[$(date -u '+%Y-%m-%d %H:%M:%S UTC')] Starting backup..."
# 输出：[2025-11-21 03:20:05 UTC] Starting backup...
```

### 3. S3 路径设计

```
s3://bucket/{environment}/{service}/{YYYYMMDD}/{filename}
                                    ^^^^^^^^^ UTC date
```

### 4. 版本号格式

```
YYYYMMDDHHmmss  (14 位，UTC)
例如：20251121032005 = 2025-11-21 03:20:05 UTC
```

## 故障排查

### 问题：版本号在不同机器上不同

**检查**:
```bash
# 确认 get_version 使用 -u 参数
grep "date -u" scripts/build-lib.sh

# 测试
source scripts/build-lib.sh && get_version
```

### 问题：备份文件时间不对

**检查**:
```bash
# 确认备份脚本使用 -u
grep "date -u" infra-apps/backup/scripts/backup-*.sh

# 查看最新备份时间
mise run restore-postgres-s3-list | head -20
```

### 问题：清理策略不正确

**检查**:
```bash
# 测试清理计算（不实际删除）
docker compose run --rm backup bash -c '
  TODAY=$(date -u +%Y%m%d)
  echo "Today (UTC): $TODAY"
  SEVEN_DAYS_AGO=$(date -u -d "7 days ago" +%Y%m%d 2>/dev/null || date -u -v-7d +%Y%m%d)
  echo "7 days ago (UTC): $SEVEN_DAYS_AGO"
'
```

## 参考资料

- [ISO 8601 标准](https://en.wikipedia.org/wiki/ISO_8601)
- [Unix 时间戳](https://en.wikipedia.org/wiki/Unix_time)
- [GNU Coreutils date](https://www.gnu.org/software/coreutils/manual/html_node/date-invocation.html)
- [Docker 日志时区](https://docs.docker.com/config/containers/logging/)

## 相关文件

- `scripts/build-lib.sh` - 构建系统版本号生成
- `infra-apps/backup/scripts/backup-*.sh` - 备份时间戳
- `infra-apps/backup/scripts/cleanup-*.sh` - 清理策略
- `infra-apps/backup/scripts/list-*.sh` - 列表显示
