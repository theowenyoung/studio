# 服务器运维快速参考

## 🚀 快速连接

```bash
mise ssh           # SSH 到服务器
mise ss            # SSH 并 cd 到 /srv/studio
```

## 📋 查看任务列表

```bash
mise tasks         # 或 mt 或 ml
```

## 🔥 常用操作

### 查看日志
```bash
mr logs            # 应用日志（实时）
mr postgres-logs   # PostgreSQL 日志
mr caddy-logs      # Caddy 日志
```

### 重启服务
```bash
mr restart         # 重启应用
mr restart-all     # 重启所有服务
```

### 容器管理
```bash
mr ps              # 查看容器状态
mr status          # 所有服务状态
mr app-shell       # 进入应用容器
```

### 数据库操作
```bash
mr db-restore-local    # 从本地备份恢复
mr db-restore-s3       # 从 S3 恢复
mr db-list-local       # 查看本地备份
mr db-backup-now       # 立即创建备份
mr postgres-shell      # 进入 psql
mr db-clean-all        # ⚠️ 删除所有数据（需确认）
```

### 系统监控
```bash
mr docker-stats    # Docker 资源使用
mr disk            # 磁盘使用
mr disk-data       # /data 目录详情
mr mem             # 内存使用
```

## 🔧 常用别名

### 目录切换
```bash
studio             # cd /srv/studio
app                # cd /srv/studio/infra-apps/app
backup             # cd /srv/studio/infra-apps/backup
postgres           # cd /srv/studio/infra-apps/postgres
redis              # cd /srv/studio/infra-apps/redis
caddy              # cd /srv/studio/infra-apps/caddy
```

### Docker
```bash
dc                 # docker compose
dps                # docker ps（格式化）
dlogs              # docker compose logs -f
dstats             # docker stats
dprune             # docker system prune
```

### 通用
```bash
ll                 # ls -lah
..                 # cd ..
...                # cd ../..
```

## 💡 Tips

- `mr` 命令支持 **Tab 补全**，输入 `mr db-<Tab>` 自动补全
- 组合使用: `app && dc logs -f`
- 查看所有任务: `mt` 或 `mise tasks`
- 重新加载配置: `source ~/.bashrc`

## 🔗 详细文档

完整文档见 [SERVER_OPERATIONS.md](./SERVER_OPERATIONS.md)
