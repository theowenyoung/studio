# 服务器运维指南

## 概览

本项目使用 **mise** 作为任务管理工具，分为两套配置：
- **本地 `mise.toml`**: 本地开发、构建、部署触发
- **服务器 `server-mise.toml`**: 服务器上的运维任务

## 快速开始

### 从本地连接服务器

```bash
# 普通 SSH 连接
mise ssh

# SSH 并自动 cd 到项目目录
mise ssh-studio
# 或使用别名
mise ss
```

### 首次初始化服务器

```bash
# 1. 创建 deploy 用户
mise server-init-user <server-ip>

# 2. 完整初始化服务器（包含 mise、aliases）
mise server-init

# 3. 验证
mise ss
mise tasks    # 查看所有服务器任务
ll            # 测试别名
```

### 同步配置到服务器

当你修改了 `server-mise.toml` 或 `ansible/files/bash_aliases` 后：

```bash
mise server-sync-config
```

## 本地任务（mise.toml）

### 开发相关
```bash
mise dev              # 启动所有开发服务器
mise dev-hono         # 启动单个应用
mise up               # 启动本地基础设施
mise down             # 停止本地基础设施
```

### 部署相关
```bash
mise deploy-postgres   # 部署 PostgreSQL
mise deploy-redis      # 部署 Redis
mise deploy-caddy      # 部署 Caddy
mise deploy-hono       # 部署应用
```

### 服务器管理
```bash
mise ssh               # SSH 到服务器
mise ss               # SSH 到服务器（自动 cd /srv/studio）
mise server-init       # 初始化服务器
mise server-update     # 更新服务器配置
mise server-sync-config # 同步 mise 和 aliases 配置
mise backup            # 触发备份（通过 Ansible）
mise resize            # 调整磁盘大小
```

## 服务器任务（server-mise.toml）

SSH 到服务器后可用的任务。

### 数据库操作

```bash
# 恢复数据库
mise run db-restore-local    # 从本地备份恢复
mise run db-restore-s3       # 从 S3 恢复

# 查看备份
mise run db-list-local       # 查看本地备份
mise run db-list-s3          # 查看 S3 备份

# 创建备份
mise run db-backup-now       # 立即创建备份
```

### 应用管理

```bash
# 日志
mise run logs                # 查看应用日志（实时）
mise run app-logs-tail       # 查看最近 100 行

# 容器管理
mise run restart             # 重启应用
mise run stop                # 停止应用
mise run start               # 启动应用
mise run ps                  # 查看容器状态

# 进入容器
mise run app-shell           # 进入应用容器
```

### 基础设施服务

```bash
# PostgreSQL
mise run postgres-logs       # 查看日志
mise run postgres-shell      # 进入 psql

# Redis
mise run redis-logs          # 查看日志
mise run redis-cli           # 进入 Redis CLI

# Caddy
mise run caddy-logs          # 查看日志
mise run caddy-reload        # 重载配置
```

### 全局监控

```bash
mise run status              # 查看所有服务状态
mise run restart-all         # 重启所有服务
mise run docker-stats        # 查看 Docker 资源使用
mise run disk                # 查看磁盘使用
mise run mem                 # 查看内存使用
```

### 清理

```bash
mise run docker-prune        # 清理未使用的 Docker 资源
mise run disk-data           # 查看 /data 目录使用情况
```

## Shell 别名（bash_aliases）

### 通用别名

```bash
ll                  # ls -lah
la                  # ls -A
..                  # cd ..
...                 # cd ../..
```

### Docker 快捷方式

```bash
dc                  # docker compose
dps                 # docker ps（格式化输出）
dlogs               # docker compose logs -f
dstats              # docker stats
dprune              # docker system prune
```

### 目录快捷方式

```bash
studio              # cd /srv/studio
app                 # cd /srv/studio/infra-apps/app
backup              # cd /srv/studio/infra-apps/backup
postgres            # cd /srv/studio/infra-apps/postgres
redis               # cd /srv/studio/infra-apps/redis
caddy               # cd /srv/studio/infra-apps/caddy
```

### mise 快捷方式

```bash
mr <task>            # mise run <task> - 支持 Tab 补全！
mt                  # mise tasks（列出所有任务）
ml                  # mise tasks（同上）
```

**Tab 补全支持**: `mr` 命令支持 Tab 补全，可以自动补全任务名称。
```bash
mr db-<Tab>         # 自动补全 db-restore-local, db-list-local 等
mr log<Tab>         # 自动补全 logs, logs-app 等
```

### 实用函数

```bash
# 查看端口占用
port 3000

# 查找大文件
findlarge 100M /data

# Docker 日志（带时间戳）
dlogs-ts

# 快速备份文件
backupfile file.txt # 创建 file.txt.backup.20250123_143000
bak file.txt        # 同上（使用别名）
```

## 常用工作流

### 查看应用日志

```bash
# 方式 1: 使用 mise 任务
mise ss
mr logs              # 或 mise run logs

# 方式 2: 使用别名
mise ss
app && dlogs        # cd /srv/studio/infra-apps/app && docker compose logs -f
```

### 恢复数据库

```bash
mise ss

# 1. 查看可用备份
mr db-list-local     # 或 mr db-list-s3

# 2. 恢复最新备份
mr db-restore-local  # 或 mr db-restore-s3

# 3. 验证
mr postgres-shell    # 进入数据库检查
```

### 重启服务

```bash
mise ss

# 重启单个服务
mr restart           # 重启应用

# 重启所有服务
mr restart-all

# 查看状态
mr status
```

### 监控资源使用

```bash
mise ss

# 查看 Docker 容器资源
mr docker-stats

# 查看磁盘
mr disk
mr disk-data         # /data 目录详情

# 查看内存
mr mem
```

## 配置文件位置

**本地：**
- `mise.toml` - 本地开发任务
- `server-mise.toml` - 服务器任务源文件（同步到服务器时重命名为 `mise.toml`）
- `ansible/files/bash_aliases` - Shell 别名（同步到服务器）

**服务器：**
- `/srv/studio/mise.toml` - mise 任务配置（从 `server-mise.toml` 同步而来）
- `/home/deploy/.bash_aliases` - Shell 别名
- `/home/deploy/.bashrc` - 包含 mise 激活和配置路径

**注意**：`server-mise.toml` 在同步到服务器时会被重命名为 `mise.toml`，这样在服务器上使用更简洁。

## 故障排查

### mise tasks 命令不可用

```bash
# 检查 mise 是否安装
which mise

# 重新加载 bashrc
source ~/.bashrc

# 检查配置文件
cat /srv/studio/mise.toml
```

### mise 提示配置文件未信任

如果看到错误：`Config files in /srv/studio/mise.toml are not trusted`

```bash
# 手动信任配置文件
mise trust

# 或者重新同步配置（会自动 trust）
# 从本地运行
mise server-sync-config
```

**自动化**：`mise server-sync-config` 会自动执行 `mise trust`，无需手动操作。

### 别名不生效

```bash
# 重新加载 aliases
source ~/.bash_aliases

# 检查文件是否存在
cat ~/.bash_aliases
```

### Tab 补全不工作

```bash
# 检查 mise 是否已激活
type mise

# 重新加载 bashrc（包含 mise activation）
source ~/.bashrc

# 手动加载补全（临时）
source <(mise completion bash --include-bash-completion-lib)

# 测试补全
mr <Tab><Tab>        # 应该显示所有任务
```

### 任务执行失败

```bash
# 查看任务定义
mise tasks

# 手动运行命令调试
cd /srv/studio/infra-apps/app
docker compose logs -f api
```

## 最佳实践

1. **优先使用 mise 任务**: 有清晰的描述和错误处理
2. **使用别名作为补充**: 对于简单快速的操作
3. **定期同步配置**: 修改 server-mise.toml 后记得 `mise server-sync-config`
4. **查看任务列表**: 不确定时运行 `mise tasks` 查看所有可用操作
5. **使用 SSH 快捷方式**: `mise ss` 比手动输入 SSH 命令快很多

## 相关文档

- [Ansible 部署架构](../ansible/README.md)
- [Mount 问题排查](../ansible/MOUNT_TROUBLESHOOTING.md)
- [性能优化](../ansible/PERFORMANCE_OPTIMIZATION.md)
