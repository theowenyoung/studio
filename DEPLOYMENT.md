# Deployment Guide

快速参考指南，用于部署各类服务到生产环境。

## 目录结构

```
studio-new/
├── docker/
│   └── nodejs-ssg/          # 共享的 SSG Dockerfile
│       ├── Dockerfile       # 通用 SSG 构建文件
│       ├── nginx.conf       # 优化的 nginx 配置
│       └── README.md        # 详细使用说明
├── ansible/
│   └── playbooks/
│       ├── deploy-ssg.yml              # SSG 项目部署
│       ├── deploy-app.yml              # App 项目部署（已简化）
│       ├── deploy-infra-caddy.yml      # Caddy 部署（智能 reload）
│       ├── deploy-infra-postgres.yml   # PostgreSQL 部署
│       ├── deploy-infra-redis.yml      # Redis 部署
│       └── deploy-infra-backup.yml     # Backup 服务部署
└── mise.toml                # 任务配置
```

## 快速开始

### SSG 项目部署

```bash
# 1. 构建并推送到 ECR
mise run build-ssg-blog        # 或 build-ssg-storefront

# 2. 部署到生产
mise run deploy-ssg-blog       # 或 deploy-ssg-storefront
```

### App 项目部署

```bash
# 1. 构建并推送到 ECR
mise run build-app-hono        # 或 build-app-proxy

# 2. 部署到生产（自动运行迁移）
mise run deploy-app-hono-demo  # 或 deploy-app-proxy
```

### Infra 服务部署

```bash
# 部署单个服务
mise run deploy-infra-caddy    # Caddy (智能 reload)
mise run deploy-infra-postgres # PostgreSQL
mise run deploy-infra-redis    # Redis
mise run deploy-infra-backup   # Backup

# 或一次性部署所有
mise run deploy-infra
```

## 部署流程详解

### SSG 项目 (blog, storefront)

**特点**：使用共享 Dockerfile，自动识别框架

```bash
# 构建过程
build.sh →
  docker build -f docker/nodejs-ssg/Dockerfile --build-arg APP_NAME=blog →
  推送到 ECR (912951144733.dkr.ecr.us-west-2.amazonaws.com/blog:VERSION)

# 部署过程
ansible deploy-ssg.yml →
  sync docker-compose.yml →
  pull image from ECR →
  docker compose up -d --remove-orphans →
  health check
```

**支持的框架**：
- Remix (输出: `build/client/`)
- Next.js (输出: `out/`)
- Vite (输出: `dist/`)

### App 项目 (hono-demo, proxy)

**特点**：自动运行数据库迁移

```bash
# 构建过程
build.sh →
  docker build →
  推送到 ECR

# 部署过程
ansible deploy-app.yml →
  sync files →
  pull images →
  run migrations (if exists) →
  docker compose up -d --remove-orphans →
  health check
```

### Infra 服务

#### Caddy - 智能配置重载

**特点**：检测 Caddyfile 变更，自动优雅 reload

```bash
# 部署过程
ansible deploy-infra-caddy.yml →
  检测 Caddyfile checksum →
  sync files →
  docker compose up -d --remove-orphans →
  if config changed: caddy reload (优雅重载) →
  health check
```

**手动 reload**：
```bash
ssh deploy@server "cd /srv/studio/infra-apps/caddy/current && ./reload.sh"
```

#### PostgreSQL / Redis

**标准部署流程**：
```bash
ansible deploy-infra-{postgres,redis}.yml →
  sync files →
  docker compose up -d --remove-orphans →
  health check
```

#### Backup

**特点**：自动创建 /data/backups 目录

```bash
ansible deploy-infra-backup.yml →
  create /data/backups →
  sync files →
  docker compose up -d --remove-orphans
```

## 回滚策略

**新策略**：不在服务器上回滚，在 CI 中重新部署旧版本

```bash
# 方式 1: 在 CI 中使用旧版本号
VERSION=20250101120000 mise run deploy-ssg-blog

# 方式 2: 使用 git 回退到旧 commit 再部署
git checkout <old-commit>
mise run deploy-ssg-blog
```

**优势**：
- 简化部署逻辑
- 避免服务器存储多个版本
- CI 有完整的部署历史

## 健康检查

所有服务都包含健康检查：

```bash
# 等待容器进入 running 或 running (healthy) 状态
# 最多重试 12 次，每次等待 5 秒
docker compose ps <service> --format json | jq -r '.State'
```

**失败处理**：
- 显示容器日志（最近 50 行）
- 部署失败并退出

## 版本管理

- **版本格式**：`YYYYMMDDHHmmss` (例如: 20250121153000)
- **版本保留**：只保留最近 3 个版本
- **版本清理**：自动在部署结束时执行

```bash
# 在服务器上手动查看版本
ssh deploy@server ls -la /srv/studio/ssg-apps/blog/
```

## 环境变量

### 开发环境
```bash
# 获取所有开发环境变量
mise run dev-env

# 或单独获取
mise run dev-env-postgres
mise run dev-env-redis
mise run dev-env-hono
```

### 生产环境

生产环境变量在 build.sh 中自动从 AWS Parameter Store 获取：
```bash
psenv -t .env.example -p "/studio-prod/" -o .env
```

## 故障排查

### 镜像拉取失败
```bash
# 检查 ECR 登录
aws ecr get-login-password --region us-west-2 | \
  docker login --username AWS --password-stdin 912951144733.dkr.ecr.us-west-2.amazonaws.com

# 检查镜像是否存在
aws ecr describe-images --repository-name blog --region us-west-2
```

### 容器无法启动
```bash
# SSH 到服务器查看日志
ssh deploy@server
cd /srv/studio/ssg-apps/blog/current
docker compose logs --tail=100

# 检查容器状态
docker compose ps
```

### Caddy reload 失败
```bash
# 验证配置语法
docker compose exec caddy caddy validate --config /etc/caddy/Caddyfile

# 查看 Caddy 日志
docker compose logs caddy --tail=50

# 强制重启（最后手段）
./restart.sh
```

### 数据库迁移失败
```bash
# 查看迁移日志
ssh deploy@server
cd /srv/studio/js-apps/hono-demo/current
docker compose --profile migrate run --rm hono-demo-migrate

# 手动回滚迁移
docker compose exec postgres psql -U postgres -d your_db
```

## 最佳实践

1. **测试后再部署**
   ```bash
   # 在本地测试 Docker 构建
   docker build -f docker/nodejs-ssg/Dockerfile --build-arg APP_NAME=blog -t test:latest .
   docker run -p 8080:80 test:latest
   ```

2. **使用 CI/CD**
   - 在 CI 中运行 `mise run build-*`
   - 成功后运行 `mise run deploy-*`
   - 失败时自动通知

3. **监控部署**
   ```bash
   # 实时查看部署日志
   ansible-playbook ... | tee deploy.log

   # 部署后检查服务状态
   ssh deploy@server "cd /srv/studio/ssg-apps/blog/current && docker compose ps"
   ```

4. **Caddy 配置更新**
   - 先在本地测试配置
   - 使用 `caddy validate` 验证
   - 部署时自动 reload，无需重启

5. **数据库备份**
   ```bash
   # 在升级前备份
   mise run server-backup

   # 查看备份
   mise run server-backup-list
   ```

## 参考

- [MIGRATION.md](./MIGRATION.md) - 迁移指南和改进详情
- [docker/nodejs-ssg/README.md](./docker/nodejs-ssg/README.md) - 共享 Dockerfile 详细说明
- [mise.toml](./mise.toml) - 所有可用的任务命令
