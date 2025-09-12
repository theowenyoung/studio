# 本地开发环境指南

简单、统一的本地开发环境，支持 HTTPS 和完整的服务栈。

## 🚀 快速开始

### 1. 首次设置

```bash
# 一键设置本地开发环境（安装证书、配置域名等）
./setup-local-dev.sh

# 或者使用 mise
mise setup-local
```

### 2. 启动开发环境

```bash
# 启动完整开发环境
mise dev

# 或单独启动服务
mise dev-postgres    # PostgreSQL 数据库
mise dev-redis       # Redis 缓存
mise dev-caddy       # Caddy 反向代理
mise dev-app         # 应用服务
```

### 3. 访问应用

- **主应用**: https://app.local
- **管理后台**: https://admin.local
- **API 服务**: https://api.local
- **数据库管理**: https://db.local

## 📊 服务连接信息

### PostgreSQL
- **地址**: `localhost:5432`
- **用户**: `postgres`
- **密码**: `local_dev_password_123`
- **连接**: `psql -h localhost -U postgres -d postgres`

### Redis
- **地址**: `localhost:6379`
- **密码**: `local_redis_password_123`
- **连接**: `redis-cli -h localhost -p 6379 -a local_redis_password_123`

## 🛠️ 常用命令

### 环境管理
```bash
mise dev           # 启动完整环境
mise stop-dev      # 停止所有服务
mise restart-dev   # 重启所有服务
mise status        # 查看服务状态
```

### 日志查看
```bash
mise logs service=app        # 查看应用日志
mise logs service=postgres   # 查看数据库日志
mise logs service=caddy      # 查看代理日志
```

### 数据库任务
```bash
mise db-list                              # 列出可用任务
mise db-task task_file=example-task.sql   # 执行数据库任务
```

## 📁 项目结构

```
infra-apps/
├── postgres/           # PostgreSQL 数据库
│   ├── docker-compose.yml
│   ├── deploy.sh
│   └── init/
├── redis/              # Redis 缓存
│   ├── docker-compose.yml
│   └── deploy.sh
├── caddy/              # Caddy 反向代理
│   ├── docker-compose.yml
│   ├── Caddyfile.local
│   └── deploy.sh
├── database-tasks/     # 数据库任务
│   ├── docker-compose.yml
│   ├── deploy.sh
│   └── tasks/
└── app/                # 应用服务
    ├── docker-compose.yml
    ├── deploy.sh
    └── src/
```

## 🔧 自定义配置

### 修改本地域名
编辑 `infra-apps/caddy/Caddyfile.local` 添加新的域名配置。

### 添加新应用
在 `infra-apps/app/docker-compose.yml` 中添加新的服务定义。

### 数据库任务
在 `infra-apps/database-tasks/tasks/` 目录创建 `.sql` 文件。

## 🌐 HTTPS 支持

本地环境使用 `mkcert` 生成的受信任证书：
- 证书位置: `infra-apps/caddy/certs/`
- 自动配置域名解析到 `127.0.0.1`
- 浏览器显示绿锁，完全模拟生产环境

## 🚫 故障排除

### 服务启动失败
```bash
# 检查 Docker 服务
docker ps

# 检查日志
mise logs service=<服务名>

# 重新创建网络
docker network rm shared_network
docker network create shared_network
```

### 证书问题
```bash
# 重新生成证书
cd infra-apps/caddy
rm -rf certs
./setup-local-dev.sh
```

### 域名无法访问
```bash
# 检查 hosts 文件
cat /etc/hosts | grep -E "(app|admin|api|db)\.local"

# 重新添加（需要 sudo）
echo "127.0.0.1 app.local admin.local api.local db.local" | sudo tee -a /etc/hosts
```

## 📈 性能优化

本地环境使用较小的资源配置，适合开发：
- PostgreSQL: 256MB shared_buffers
- Redis: 128MB max_memory
- 应用服务：动态资源分配

如需调整，编辑对应的 `docker-compose.yml` 文件。

---

**简单、高效、接近生产的本地开发体验！** 🎉
