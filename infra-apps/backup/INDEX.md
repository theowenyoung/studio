# 备份系统文档索引

## 快速导航

### 🚀 新手入门
- **[QUICK_START.md](QUICK_START.md)** - 5分钟快速开始指南

### 📖 核心文档
- **[README.md](README.md)** - 完整功能文档和使用指南
- **[MANUAL_BACKUP.md](MANUAL_BACKUP.md)** - 手动备份操作指南（⭐ 推荐阅读）
- **[CONFIGURATION.md](CONFIGURATION.md)** - 配置文件说明和最佳实践

### 📝 变更和升级
- **[CHANGES.md](CHANGES.md)** - 最新版本变更说明

### 🔧 配置文件
- **`.env.example`** - 环境变量配置模板
- **`docker-compose.yml`** - 开发环境配置
- **`docker-compose.prod.yml`** - 生产环境配置

### 🛠️ 快捷脚本
- **`backup.sh`** - 开发环境快捷操作脚本
- **`backup-prod.sh`** - 生产环境快捷操作脚本

## 按场景查找

### 场景 1: 第一次使用
1. [QUICK_START.md](QUICK_START.md) - 快速开始
2. [README.md](README.md) - 了解完整功能

### 场景 2: 需要手动备份
1. [MANUAL_BACKUP.md](MANUAL_BACKUP.md) - 手动备份完整指南
2. 或直接使用快捷脚本：`./backup.sh all`

### 场景 3: 遇到问题
1. [README.md](README.md) 的"故障排除"章节
2. [MANUAL_BACKUP.md](MANUAL_BACKUP.md) 的"故障排除"章节

### 场景 4: 配置问题
1. [CONFIGURATION.md](CONFIGURATION.md) - 理解配置原理
2. [.env.example](.env.example) - 查看配置模板

### 场景 5: 版本升级
1. [CHANGES.md](CHANGES.md) - 查看变更内容
2. [README.md](README.md) - 查看新功能说明

## 文档详情

### QUICK_START.md
- **目标读者**: 新用户
- **内容**: 最简化的开始指南
- **阅读时间**: 5 分钟
- **推荐场景**: 
  - ✅ 第一次使用
  - ✅ 快速部署

### README.md
- **目标读者**: 所有用户
- **内容**: 完整功能说明、配置详解、故障排除
- **阅读时间**: 20-30 分钟
- **推荐场景**:
  - ✅ 了解完整功能
  - ✅ 深入配置
  - ✅ 故障排除
  - ✅ 数据恢复

### MANUAL_BACKUP.md ⭐
- **目标读者**: 需要手动操作备份的用户
- **内容**: 手动备份的所有方法和场景
- **阅读时间**: 10-15 分钟
- **推荐场景**:
  - ✅ 升级前备份
  - ✅ 迁移前备份
  - ✅ 紧急备份
  - ✅ 测试备份功能

### CONFIGURATION.md
- **目标读者**: 需要理解配置原理的用户
- **内容**: 配置文件结构、环境变量说明
- **阅读时间**: 10 分钟
- **推荐场景**:
  - ✅ 自定义配置
  - ✅ 理解配置原理
  - ✅ 解决配置问题

### CHANGES.md
- **目标读者**: 从旧版本升级的用户
- **内容**: 版本变更说明、迁移指南
- **阅读时间**: 5-10 分钟
- **推荐场景**:
  - ✅ 版本升级
  - ✅ 了解新特性
  - ✅ 迁移旧配置

## 快捷命令速查

### 开发环境

```bash
# 使用快捷脚本
./backup.sh all      # 完整备份
./backup.sh test     # 测试连接
./backup.sh list     # 列出备份
./backup.sh logs     # 查看日志

# 使用原始命令
docker compose exec backup /usr/local/bin/backup-all.sh
docker compose exec backup /usr/local/bin/test-connection.sh
docker compose logs -f backup
```

### 生产环境

```bash
# 使用快捷脚本
./backup-prod.sh all      # 完整备份
./backup-prod.sh test     # 测试连接
./backup-prod.sh stats    # 存储统计

# 使用原始命令
docker compose -f docker-compose.prod.yml exec backup /usr/local/bin/backup-all.sh
docker compose -f docker-compose.prod.yml exec backup /usr/local/bin/test-connection.sh
```

## 常见问题快速链接

| 问题 | 查看文档 | 章节 |
|------|---------|------|
| 如何手动备份？ | [MANUAL_BACKUP.md](MANUAL_BACKUP.md) | 整个文档 |
| 环境变量怎么配置？ | [CONFIGURATION.md](CONFIGURATION.md) | "配置原理" |
| URL 格式是什么？ | [README.md](README.md) | "URL 格式说明" |
| 如何恢复数据？ | [README.md](README.md) | "数据恢复" |
| 备份失败怎么办？ | [README.md](README.md) | "故障排除" |
| 磁盘空间不足？ | [MANUAL_BACKUP.md](MANUAL_BACKUP.md) | "故障排除" |
| 如何测试连接？ | [MANUAL_BACKUP.md](MANUAL_BACKUP.md) | "测试连接" |
| 定时任务怎么配置？ | [README.md](README.md) | "自定义调度" |

## 脚本文件说明

### 备份脚本 (scripts/)
- `backup-postgres.sh` - PostgreSQL 备份（使用 pg_dumpall）
- `backup-redis.sh` - Redis 备份
- `backup-all.sh` - 备份所有服务
- `cleanup.sh` - 清理旧备份
- `test-connection.sh` - 测试数据库连接
- `parse-url.sh` - URL 解析工具

### 快捷脚本 (根目录)
- `backup.sh` - 开发环境快捷操作
- `backup-prod.sh` - 生产环境快捷操作

## 推荐阅读顺序

### 初次使用
1. [QUICK_START.md](QUICK_START.md) - 快速开始
2. [MANUAL_BACKUP.md](MANUAL_BACKUP.md) - 学会手动备份
3. [README.md](README.md) - 深入了解功能

### 深入使用
1. [CONFIGURATION.md](CONFIGURATION.md) - 理解配置
2. [README.md](README.md) 的"高级功能"章节
3. [MANUAL_BACKUP.md](MANUAL_BACKUP.md) 的"最佳实践"

### 问题排查
1. [MANUAL_BACKUP.md](MANUAL_BACKUP.md) - 故障排除
2. [README.md](README.md) - 故障排除
3. 查看日志: `./backup.sh logs`

## 获取帮助

### 使用帮助命令
```bash
# 查看快捷脚本帮助
./backup.sh
./backup-prod.sh

# 查看文档
cat README.md
cat MANUAL_BACKUP.md
```

### 在线文档
所有文档都在 `infra-apps/backup/` 目录中，可以随时查阅。
