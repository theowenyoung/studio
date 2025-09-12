# Ansible 基础架构自动化

简单、独立、可控的 Docker 服务部署方案。

## 🎯 核心特性

- 🚀 **零停机部署**: 基于 [docker-rollout](https://github.com/wowu/docker-rollout) 
- 🐳 **独立服务**: 每个服务完全自包含，最小依赖
- 🔐 **简化密钥**: AWS Parameter Store 集成，每服务一个 `.env` 
- 📁 **统一存储**: 所有数据存储在 `/data` 目录
- 🌐 **共享网络**: 所有服务通过 `shared_network` 互通

## 🚀 快速开始

```bash
# 1. 基础设施准备（网络、目录、docker-rollout 工具）
ansible-playbook -i inventory/production playbooks/infra.yml

# 2. 部署独立服务（PostgreSQL + Redis + Caddy）
ansible-playbook -i inventory/production playbooks/deploy-standalone-services.yml

# 3. 部署应用
ansible-playbook -i inventory/production playbooks/deploy-app-standalone.yml \
  -e app_name=myapp -e app_port=3000
```

## 🔥 零停机部署演示

```bash
# 上传应用密钥到 AWS Parameter Store（一次性）
echo "SECRET_KEY=my-secret" > /data/myapp/.env
manage-secrets upload myapp

# 零停机部署应用
docker rollout myapp

# 批量部署所有应用
docker rollout
```

**结果**: 应用更新完成，用户零感知，无请求丢失！

## 📊 技术栈

| 组件 | 版本 | 用途 |
|------|------|------|
| **PostgreSQL** | 15 | 主数据库 |
| **Redis** | 7 | 缓存/会话 |
| **Caddy** | 2 | 反向代理 |
| **docker-rollout** | latest | 零停机部署 |

## 🗂️ 目录结构

```
ansible/
├── playbooks/
│   ├── infra.yml                      # 基础设施准备
│   ├── deploy-standalone-services.yml # 独立服务批量部署
│   ├── deploy-postgres-infra.yml      # PostgreSQL 基础设施部署
│   ├── deploy-redis-infra.yml         # Redis 基础设施部署
│   ├── deploy-caddy-infra.yml         # Caddy 基础设施部署
│   ├── deploy-database-tasks-infra.yml # Database Tasks 基础设施部署
│   └── deploy-app-standalone.yml      # 应用独立部署
├── templates/
│   ├── manage-standalone-secrets.sh.j2 # 密钥管理工具
│   └── docker-rollout-example.sh.j2   # 零停机部署示例
├── tasks/
│   ├── install-docker-rollout.yml     # 零停机部署工具
│   ├── ssh-keyscan.yml                # SSH 密钥扫描
│   ├── verify-services.yml            # 服务验证
│   └── wait-for-connection.yml        # 连接等待
└── STANDALONE-SERVICES.md             # 架构指南
```

## ⚙️ 架构

### 目录结构
```
/data/                  # 数据目录（配置+数据）
├── postgres/           # PostgreSQL 配置、数据、脚本
├── redis/              # Redis 配置和数据
├── caddy/              # Caddy 配置、证书、数据
└── myapp/              # 应用配置和数据
```

### 密钥管理
```bash
# 上传服务密钥到 AWS
manage-secrets upload postgres
manage-secrets upload myapp

# 从 AWS 下载密钥
manage-secrets download postgres
manage-secrets list-local
```

## 🛠️ 常用命令

### 独立服务管理

```bash
# 管理基础服务
cd /opt/services/postgres && docker compose ps
cd /opt/services/redis && docker compose restart redis
cd /opt/services/caddy && docker compose logs -f

# 管理应用
cd /opt/services/apps/myapp && docker compose ps
docker rollout myapp  # 零停机部署
```

### 密钥管理

```bash
# 服务密钥管理
manage-secrets upload postgres
manage-secrets download myapp
manage-secrets list-local

# 批量操作
manage-secrets batch-upload
```

### 服务状态

```bash
# 查看所有容器
docker ps

# 检查网络连通性
docker network inspect shared_network
docker exec myapp ping postgres
```

## 📚 文档

- **[STANDALONE-SERVICES.md](STANDALONE-SERVICES.md)** - 完整架构指南

## ⚡ 零停机部署

```
启动新实例 → 健康检查 → 流量切换 → 停止旧实例
    ↑           ↑         ↑
用户持续访问   自动验证   无感知更新 (0秒停机)
```

**简单、独立、可控的服务部署方案** 🚀
