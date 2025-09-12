# 简化后的使用指南

按照你的建议，现在的架构更加简洁实用！

## 🎯 核心改进

1. **统一 .env 文件管理**：本地使用 `.env` 文件包含所有敏感变量
2. **简化 deploy.sh 脚本**：删除过度复杂的逻辑分支
3. **统一本地和远程逻辑**：最大程度复用代码
4. **envsubst 处理 SQL**：database-tasks 使用简单的变量替换

## 🚀 使用流程

### 1. 本地开发设置

```bash
# 1. 首次设置（安装证书等）
./setup-local-dev.sh

# 2. 复制并配置环境变量
cp infra-apps/postgres/env-example infra-apps/postgres/.env
cp infra-apps/redis/env-example infra-apps/redis/.env
cp infra-apps/app/env-example infra-apps/app/.env

# 3. 修改 .env 文件中的密码
# POSTGRES_PASSWORD=my-local-postgres-password
# REDIS_PASSWORD=my-local-redis-password

# 4. 启动服务
mise dev
```

### 2. 单独管理服务

```bash
# 进入服务目录，直接使用 Docker Compose
cd infra-apps/postgres
docker compose up -d              # 启动
docker compose logs -f            # 查看日志
docker compose restart            # 重启

# 或使用简化的部署脚本
./deploy.sh                       # 一键部署和健康检查
```

### 3. 数据库任务管理

```bash
# 列出可用任务
cd infra-apps/database-tasks
./deploy.sh list

# 执行任务（使用 envsubst 处理变量）
./deploy.sh run create-user.sql

# SQL 文件中可以使用环境变量
# CREATE USER ${TEST_DEMO_PASSWORD};  <- 会被替换成实际值
```

### 4. 生产部署

```bash
# 远程服务器上，环境变量从 AWS Parameter Store 获取
# 但使用相同的部署脚本
cd infra-apps/postgres
ENV_MODE=aws ./deploy.sh

# 或使用 Ansible（内部调用相同脚本）
ansible-playbook ansible/playbooks/deploy-postgres-infra.yml
```

## 📁 新的文件结构

```
infra-apps/<service>/
├── docker-compose.yml      # 本地配置（默认）+ 引用 .env
├── docker-compose.prod.yml # 生产配置（如果有差异）
├── deploy.sh              # 简化的部署脚本
├── env-example            # 环境变量示例
└── .env                   # 本地实际环境变量（gitignored）
```

## 🔧 环境变量策略

### 本地开发
- **公开配置**：直接写在 `docker-compose.yml` 中
- **敏感信息**：放在 `.env` 文件中
- **默认值**：使用 `${VAR:-default}` 语法提供后备值

### 生产环境
- **公开配置**：写在 `docker-compose.prod.yml` 中
- **敏感信息**：从 AWS Parameter Store 获取到 `.env`
- **域名等**：使用 `envsubst` 处理模板

## 📝 配置示例

### postgres/.env（本地）
```bash
POSTGRES_PASSWORD=my-local-postgres-password
```

### database-tasks/tasks/create-user.sql
```sql
-- 创建用户，密码从环境变量获取
CREATE USER myapp_user WITH PASSWORD '${TEST_DEMO_PASSWORD}';
GRANT ALL PRIVILEGES ON DATABASE myapp TO myapp_user;
```

### app/.env（本地）
```bash
POSTGRES_PASSWORD=my-local-postgres-password
REDIS_PASSWORD=my-local-redis-password
APP_SECRET_KEY=local-development-secret
JWT_SECRET=local-jwt-secret
```

## ✨ 优势

1. **极简化**：删除了过度复杂的脚本逻辑
2. **统一性**：本地和远程使用相同的 deploy.sh
3. **实用性**：.env 文件包含所有必要变量
4. **灵活性**：仍然支持环境变量默认值
5. **维护性**：代码更少，逻辑更清晰

## 🛠️ 日常工作流

```bash
# 启动开发环境
mise dev

# 查看服务状态  
mise status

# 执行数据库任务
cd infra-apps/database-tasks
./deploy.sh run my-task.sql

# 重启单个服务
cd infra-apps/postgres
docker compose restart

# 生产部署
mise deploy-postgres
```

---

**现在的架构更符合实际使用需求，简单而强大！** 🎉
