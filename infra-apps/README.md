# Infrastructure Apps

简化的基础设施应用配置管理，支持本地开发和生产部署。

## 🏗️ 目录结构

```
infra-apps/
├── postgres/                   # PostgreSQL 数据库
│   ├── docker-compose.yml     # 本地开发配置（默认）
│   ├── docker-compose.prod.yml # 生产环境配置
│   ├── deploy.sh              # 统一部署脚本
│   ├── env-example            # 环境变量示例
│   └── init/                  # 初始化脚本
│       └── 01-extensions.sql
├── redis/                     # Redis 缓存
│   ├── docker-compose.yml
│   ├── docker-compose.prod.yml
│   ├── deploy.sh
│   └── env-example
├── caddy/                     # Caddy 反向代理
│   ├── docker-compose.yml
│   ├── docker-compose.prod.yml
│   ├── Caddyfile.local        # 本地开发配置
│   ├── Caddyfile.prod.template # 生产环境模板
│   ├── deploy.sh
│   └── env-example
├── database-tasks/            # 数据库任务执行器
│   ├── docker-compose.yml
│   ├── docker-compose.prod.yml
│   ├── deploy.sh
│   ├── env-example
│   └── tasks/                 # 数据库任务脚本
│       └── *.sql
├── app/                       # 应用服务
│   ├── docker-compose.yml
│   ├── docker-compose.prod.yml
│   ├── deploy.sh
│   ├── env-example
│   └── src/                   # 应用代码
└── README.md
```

## 🚀 部署架构

### 本地开发
- **配置**: 直接使用 `docker-compose.yml`（默认文件名）
- **域名**: 使用 localhost 子域名（app.localhost, admin.localhost 等，无需配置 hosts）
- **证书**: 使用 mkcert 生成的本地证书（自动受信任）
- **密码**: 硬编码在配置中，如 `local_dev_password_123`

### 生产环境  
- **配置**: 使用 `docker-compose.prod.yml` + `envsubst` 处理变量
- **域名**: 从环境变量获取
- **证书**: Let's Encrypt 自动生成
- **密码**: 从 AWS Parameter Store 获取

## 🎯 使用方法

### 本地开发
```bash
# 首次设置（一键安装 mkcert + 生成证书）
mise setup-local      # 安装 mkcert、生成证书、创建目录

# 启动完整开发环境  
mise service

# 或单独启动服务
mise dev-postgres     # PostgreSQL
mise dev-redis        # Redis  
mise dev-caddy        # Caddy
mise dev-app          # 应用

# 或直接使用 Docker
cd infra-apps/postgres
docker compose up -d
```

### 生产部署
```bash  
# 使用 mise（推荐）
mise deploy-postgres   # 单独部署
mise deploy-all        # 批量部署

# 使用 Ansible（向后兼容）
ansible-playbook ansible/playbooks/deploy-postgres-infra.yml

# 直接使用部署脚本
cd infra-apps/postgres
ENV_MODE=aws ./deploy.sh
```

### 数据库任务
```bash
# 列出可用任务
mise db-list

# 执行任务
mise db-task task_file=create-user.sql

# 或直接使用脚本
cd infra-apps/database-tasks
./deploy.sh list
./deploy.sh run create-user.sql
```

## 📝 配置文件说明

### Docker Compose 配置
- `docker-compose.yml` - 本地开发配置，硬编码密码和配置
- `docker-compose.prod.yml` - 生产配置，使用环境变量

### 环境变量文件
- `env-example` - 环境变量示例和说明
- 本地开发：大部分配置硬编码，无需环境文件
- 生产环境：敏感信息从 AWS Parameter Store 获取

### 部署脚本 (deploy.sh)
- 支持本地 (`ENV_MODE=local`) 和生产 (`ENV_MODE=aws`) 模式
- 统一的部署逻辑，彩色日志输出
- 完整的错误处理和健康检查

### Caddy 特殊配置
- `Caddyfile.local` - 本地开发，硬编码域名和路由
- `Caddyfile.prod.template` - 生产模板，使用 envsubst 处理

## ✨ 优势

1. **简化配置**: 取消复杂模板系统，直接编写配置文件
2. **本地友好**: 支持 HTTPS，一键启动完整开发环境  
3. **统一部署**: 本地和生产使用相同的部署脚本
4. **易于维护**: 每个服务自包含，配置清晰易懂
5. **向后兼容**: 原有 Ansible 工作流程仍然可用

## 🔄 从旧版本迁移

如果你之前使用模板文件 (*.j2)，现在已经简化为：
- ✅ 删除了所有 `.j2` 模板文件
- ✅ 统一使用 `env-example` 而不是 `env-template`  
- ✅ Ansible playbooks 现在调用 `deploy.sh` 脚本
- ✅ 保持向后兼容，原有命令仍然可用

