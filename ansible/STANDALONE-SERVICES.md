# 独立服务架构指南

## 🎯 设计理念

每个服务完全独立，最小依赖，简单可控：

- ✅ **完全独立**: 每个服务有自己的目录、配置、密钥
- ✅ **共享网络**: 所有服务使用 `shared_network` 互通
- ✅ **统一存储**: 数据统一存储在 `/data/` 目录
- ✅ **最小配置**: 减少 Ansible 变量依赖，配置直接写在 docker-compose.yml 中
- ✅ **独立密钥**: 每个服务/应用有自己的 `.env` 文件

## 📁 目录结构

```
/data/                          # 数据目录（持久化）
├── postgres/                   # PostgreSQL 数据
├── redis/                      # Redis 数据
├── caddy/                      # Caddy 证书和数据
├── caddy-config/              # Caddy 配置缓存
└── myapp/                     # 应用数据

/opt/services/                  # 服务配置目录
├── postgres/
│   ├── docker-compose.yml     # 独立配置
│   ├── .env                   # PostgreSQL 密钥
│   └── init/                  # 初始化脚本
├── redis/
│   ├── docker-compose.yml     # 独立配置
│   ├── .env                   # Redis 密钥
│   └── logs/
├── caddy/
│   ├── docker-compose.yml     # 独立配置
│   ├── .env                   # Caddy 配置
│   ├── Caddyfile              # 主配置文件
│   └── logs/
├── apps/
│   └── myapp/
│       ├── docker-compose.yml # 应用配置
│       └── .env               # 应用密钥
# 密钥管理工具: /usr/local/bin/manage-secrets
```

## 🚀 快速开始

### 1. 基础设施准备

```bash
# 运行基础设施准备（包含 docker-rollout 安装）
ansible-playbook -i inventory/production playbooks/infra.yml
```

这会创建：
- 共享 Docker 网络 `shared_network`
- 所有数据目录 `/data/{postgres,redis,caddy}`
- 所有服务配置和数据目录 `/data/{postgres,redis,caddy}`
- 安装 docker-rollout 工具

### 2. 部署独立服务

#### 选项 A: 批量部署所有服务

```bash
ansible-playbook -i inventory/production playbooks/deploy-standalone-services.yml
```

#### 选项 B: 单独部署各服务

```bash
# 分别部署
mise deploy-infra postgres
mise deploy-infra redis
mise deploy-infra caddy
```

### 3. 部署应用

```bash
# 部署应用
ansible-playbook -i inventory/production playbooks/deploy-app-standalone.yml \
  -e app_name=myapp \
  -e app_port=3000 \
  -e app_domain=app.example.com
```

## 🔐 密钥管理工作流

### AWS Parameter Store 结构

```
/postgres/.env          # PostgreSQL 服务密钥
/redis/.env            # Redis 服务密钥  
/caddy/.env            # Caddy 配置
/myapp/.env            # myapp 应用密钥
/anotherapp/.env       # 其他应用密钥
```

### 密钥管理命令

```bash
# 上传服务密钥
manage-secrets upload postgres
manage-secrets upload redis
manage-secrets upload myapp

# 下载密钥
manage-secrets download postgres

# 批量操作
manage-secrets batch-upload
manage-secrets batch-download

# 查看状态
manage-secrets list-local
manage-secrets list-remote
```

## ⚙️ 服务配置示例

### PostgreSQL (.env 文件)

```bash
# /opt/services/postgres/.env
POSTGRES_PASSWORD=your-secure-password
```

### Redis (.env 文件)

```bash
# /opt/services/redis/.env  
REDIS_PASSWORD=your-redis-password
```

### Caddy (.env 文件)

```bash
# /opt/services/caddy/.env
ADMIN_EMAIL=admin@example.com
```

### 应用 (.env 文件)

```bash
# /opt/services/apps/myapp/.env
NODE_ENV=production
PORT=3000
SECRET_KEY=your-app-secret
JWT_SECRET=your-jwt-secret
DATABASE_URL=postgresql://postgres:password@postgres:5432/myapp
REDIS_URL=redis://:password@redis:6379/0
```

## 🛠️ 服务管理

### 基本操作

```bash
# 查看所有容器
docker ps

# 进入服务目录
cd /opt/services/postgres
cd /opt/services/redis  
cd /opt/services/caddy
cd /opt/services/apps/myapp

# 管理服务
docker compose ps                    # 查看状态
docker compose logs -f postgres     # 查看日志
docker compose restart postgres     # 重启服务
docker compose stop postgres        # 停止服务
docker compose up -d postgres       # 启动服务
```

### 零停机部署

```bash
# 零停机部署应用
cd /opt/services/apps/myapp
docker rollout myapp

# 或直接使用
docker rollout myapp
```

### 配置修改

```bash
# 修改 PostgreSQL 配置
vim /opt/services/postgres/docker-compose.yml
cd /opt/services/postgres && docker compose up -d

# 修改 Caddy 配置
vim /opt/services/caddy/Caddyfile
docker exec caddy caddy reload --config /etc/caddy/Caddyfile

# 修改应用配置
vim /opt/services/apps/myapp/docker-compose.yml
cd /opt/services/apps/myapp && docker rollout myapp
```

## 📊 网络通信

所有服务通过 `shared_network` 互通：

```bash
# 应用连接数据库
DATABASE_URL=postgresql://postgres:password@postgres:5432/myapp

# 应用连接 Redis  
REDIS_URL=redis://:password@redis:6379/0

# Caddy 代理应用
reverse_proxy myapp:3000
```

## 🔧 故障排除

### 网络问题

```bash
# 检查共享网络
docker network inspect shared_network

# 测试网络连通性
docker exec myapp ping postgres
docker exec myapp ping redis
```

### 服务启动问题

```bash
# 检查服务日志
docker logs postgres
docker logs redis
docker logs caddy
docker logs myapp

# 检查配置文件
docker compose config -q  # 验证 compose 文件语法
```

### 密钥问题

```bash
# 检查环境文件
cat /opt/services/postgres/.env
cat /opt/services/apps/myapp/.env

# 测试 AWS 连接
aws sts get-caller-identity
aws ssm get-parameter --name "/postgres/.env" --with-decryption
```

## 🚀 优势

### 简单可控
- 每个服务独立，易于理解和维护
- 配置直接写在 docker-compose.yml 中，减少模板复杂度
- Ansible 只负责 CI 流程，不过度介入服务配置

### 灵活部署
- 可以单独重启、更新任何服务
- 支持不同的部署策略（标准/零停机）
- 每个服务有独立的资源限制和监控

### 安全隔离
- 每个服务有独立的密钥文件
- 最小权限原则，服务间通过网络通信
- 敏感数据通过 AWS Parameter Store 管理

### 易于扩展
- 添加新服务只需创建新目录和配置
- 支持多个应用实例
- 服务间松耦合，便于替换和升级

---

这种架构让服务管理变得**简单、独立、可控**，是现代容器化部署的最佳实践！ 🎉
