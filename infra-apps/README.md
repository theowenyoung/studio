# Infrastructure Apps

统一的基础设施应用配置管理。

## 目录结构

```
infra-apps/
├── postgres/                   # PostgreSQL 配置
│   ├── docker-compose.yml.j2  # Docker Compose 模板
│   ├── env-template           # 环境变量模板
│   └── init/                  # 初始化脚本
│       └── 01-extensions.sql
├── redis/                     # Redis 配置
│   ├── docker-compose.yml.j2
│   └── env-template
├── caddy/                     # Caddy 配置
│   ├── docker-compose.yml.j2
│   ├── Caddyfile.j2          # Caddy 配置模板
│   └── env-template
├── database-tasks/            # 数据库任务执行器
│   ├── docker-compose.yml.j2
│   ├── env-template
│   └── tasks/
│       └── template-create-app-db.sql
└── README.md
```

## 部署架构

### 配置管理
- **源配置**: `infra-apps/` - 版本控制的配置模板
- **运行配置**: `/srv/` - 部署时生成的实际配置
- **持久化数据**: `/data/` - 数据文件和日志

### 部署流程
1. Ansible 从 `infra-apps/` 读取配置模板
2. 从 AWS Parameter Store 获取环境变量
3. 处理模板并复制到 `/srv/`
4. 启动 Docker Compose 服务

## 使用方法

### 部署服务
```bash
# 使用通用部署任务
mise deploy-infra postgres
mise deploy-infra redis
mise deploy-infra caddy
mise deploy-infra database-tasks

# 或使用旧的专用任务（向后兼容）
mise run postgres
mise run redis
mise run caddy
```

### 管理服务
```bash
# 查看服务状态
cd /srv/postgres && docker compose ps

# 查看日志
cd /srv/postgres && docker compose logs

# 重启服务
cd /srv/postgres && docker compose restart
```

### 数据库任务
```bash
# 创建数据库任务
mise create-db-task create-myapp-db

# 执行数据库任务
mise run-db-task 20250912-create-myapp-db

# 查看任务日志（日志保存在 /data/database-tasks/logs/）
mise view-db-task-log 20250912-create-myapp-db
```

## 配置文件说明

### Docker Compose 模板 (*.yml.j2)
- 使用 Jinja2 模板语法
- 支持条件判断和变量替换
- 部署时由 Ansible 处理

### 环境变量模板 (env-template)
- 定义各服务需要的环境变量
- 部署时从 AWS Parameter Store 获取实际值
- 使用 Ansible 变量语法 `{{ variable_name }}`

### 初始化和配置脚本
- PostgreSQL: `init/01-extensions.sql` - 数据库扩展和系统配置
- Caddy: `Caddyfile.j2` - Web 服务器配置
- Database Tasks: `tasks/template-*.sql` - 数据库管理任务模板

## 优势

1. **统一管理**: 所有基础设施配置集中在一个位置
2. **版本控制**: 配置模板可以版本控制，便于回滚和审计
3. **模板化**: 支持多环境部署，通过变量控制不同配置
4. **职责分离**: Ansible 专注部署逻辑，配置文件专注服务定义
5. **可扩展**: 添加新服务只需在 `infra-apps/` 添加相应目录和配置

