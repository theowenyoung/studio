# 部署指南

## 📁 目录结构

```
project/
├── scripts/
│   ├── build-lib.sh                    # 公共构建函数库
│   └── create-init-user.sh            # 创建部署用户
│
├── infra-apps/                         # 基础设施服务
│   ├── caddy/
│   │   ├── src/
│   │   │   ├── Caddyfile.prod         # 生产环境主配置
│   │   │   ├── snippets/
│   │   │   │   └── ssg-common.caddy   # SSG 通用配置
│   │   │   └── sites/
│   │   │       ├── storefront.caddy   # 各站点配置
│   │   │       ├── blog.caddy
│   │   │       └── api.caddy
│   │   ├── docker-compose.prod.yml
│   │   └── build.sh
│   ├── postgres/
│   │   ├── docker-compose.prod.yml
│   │   └── build.sh
│   └── redis/
│       ├── docker-compose.prod.yml
│       └── build.sh
│
├── js-apps/                            # 应用服务
│   ├── hono-demo/                     # 后端应用
│   │   ├── templates/
│   │   │   └── docker-compose.prod.yml
│   │   └── build.sh
│   └── storefront/                    # SSG 应用
│       └── build.sh
│
├── ansible/
│   ├── inventory.yml                  # 服务器清单
│   ├── requirements.yml               # Ansible Galaxy 依赖
│   ├── playbooks/
│   │   ├── init-server.yml           # 服务器初始化（主流程）
│   │   ├── security.yml              # 安全加固
│   │   ├── mount.yml                 # 数据盘挂载
│   │   ├── setup-docker.yml          # Docker 配置
│   │   ├── deploy-infra.yml          # 部署基础设施
│   │   ├── deploy-app.yml            # 部署后端应用
│   │   └── deploy-ssg.yml            # 部署 SSG 应用
│   └── tasks/                         # 可复用任务
│
└── mise.toml                          # 任务管理配置
```

## 🚀 快速开始

### 0. 准备工作

```bash
# 安装 Ansible Galaxy 依赖（首次运行）
ansible-galaxy install -r ansible/requirements.yml
```

这将安装以下社区角色：
- `robertdebock.bootstrap` - 系统基础配置
- `robertdebock.update` - 系统更新
- `geerlingguy.docker` - Docker 安装
- `geerlingguy.security` - 安全加固
- `geerlingguy.firewall` - 防火墙配置
- `willshersystems.sshd` - SSH 配置

### 1. 初始化服务器

```bash
# 第一步：创建 deploy 用户（在本地执行）
mise run server-init-user <server-ip>

# 第二步：配置服务器环境
mise run server-init
```

这将自动完成：
- ✅ 系统更新和基础配置（bootstrap, update）
- ✅ 安全加固（SSH 强化、防火墙、Fail2ban）
- ✅ 数据盘挂载（自动检测并挂载到 /data）
- ✅ Docker 安装和配置（使用社区角色）
- ✅ 共享网络创建
- ✅ 应用目录结构
- ✅ docker-rollout 工具安装

### 2. 部署基础设施

```bash
# 一次性部署所有基础设施
mise run deploy:infra

# 或分别部署
mise run deploy:postgres
mise run deploy:redis
mise run deploy:caddy
mise run deploy:backup
```

### 3. 部署应用

#### 后端应用（Docker 容器）

```bash
mise run deploy:hono
mise run deploy:api
mise run deploy:admin
```

#### SSG 应用（静态文件）

```bash
mise run deploy:storefront
mise run deploy:blog
mise run deploy:marketing
```

### 4. 回滚

```bash
# 后端应用回滚（零停机）
mise run rollback:hono

# SSG 应用回滚（瞬间完成）
mise run rollback:storefront
```

## 📦 服务分类

### 三类服务的处理方式

| 类型 | 示例 | 部署方式 | 特点 |
|-----|------|---------|------|
| **基础设施** | postgres, redis, caddy | Docker Compose | 有状态，直接重启 |
| **后端应用** | hono-demo, api | Docker Compose + rollout | 无状态，零停机 |
| **SSG 应用** | storefront, blog | 静态文件 + rsync | 纯静态，切换软链接 |

## 🏗️ 服务器目录结构

```
/srv/studio/
├── infra-apps/
│   └── postgres/
│       ├── 20251118143000/          # 版本化目录
│       ├── 20251118140000/
│       ├── 20251118135000/
│       └── current -> 20251118143000/
│
├── js-apps/
│   └── hono-demo/
│       ├── 20251118144500/
│       └── current -> 20251118144500/
│
└── ssg-apps/
    └── storefront/
        ├── 20251118145000/
        └── current -> 20251118145000/

/data/
├── docker/         # Docker volumes
├── postgres/       # PostgreSQL 数据
├── redis/          # Redis 数据
└── backups/        # 备份数据
    ├── postgres/
    └── redis/
```

## 🎯 新增服务指南

### 添加新的 SSG 应用

1. **创建站点配置**：`infra-apps/caddy/src/sites/new-site.caddy`

```caddy
new-site.example.com {
    import snippets/ssg-common.caddy /srv/studio/ssg-apps/new-site/current
}
```

2. **在服务器初始化时添加目录**：编辑 `ansible/init-server.yml`，在 SSG 应用列表中添加：

```yaml
- /srv/studio/ssg-apps/new-site
```

3. **添加 mise 任务**：编辑 `mise.toml`

```toml
[tasks."build:new-site"]
run = "bash js-apps/new-site/build.sh"

[tasks."deploy:new-site"]
depends = ["build:new-site"]
run = "ansible-playbook -i ansible/inventory.yml ansible/deploy-ssg.yml -e service_name=new-site"
```

4. **部署**

```bash
mise run deploy:caddy      # 更新 Caddy 配置
mise run deploy:new-site   # 部署新站点
```

### 添加新的后端应用

1. **创建模板**：`js-apps/new-app/templates/docker-compose.prod.yml`

2. **创建 build.sh**（参考 `js-apps/hono-demo/build.sh`）

3. **在 mise.toml 中添加任务**

4. **部署**：`mise run deploy:new-app`

## 🔧 版本管理

- **版本号格式**：`YYYYMMDDHHmmss`（如 `20251118143000`）
- **自动保留**：服务器上只保留最近 3 个版本
- **版本同步**：Docker 镜像 tag 和部署目录名使用相同版本号
- **快速回滚**：切换软链接到上一个版本

## 📝 常用命令

```bash
# 查看所有任务
mise tasks

# 构建但不部署
mise run build:postgres
mise run build:hono

# 查看服务器日志
ssh deploy@your-server.com "cd /srv/studio/js-apps/hono-demo/current && docker compose logs -f"

# 查看服务器上的版本
ssh deploy@your-server.com "ls -lt /srv/studio/js-apps/hono-demo/"

# 手动清理旧版本
ssh deploy@your-server.com "cd /srv/studio/js-apps/hono-demo && ls -t | grep '^[0-9]' | tail -n +4 | xargs rm -rf"
```

## ⚙️ 配置说明

### 环境变量管理

所有生产环境变量从 AWS Parameter Store 拉取：

```bash
# 参数路径格式
/studio-prod/{service_name}/

# 例如
/studio-prod/postgres/
/studio-prod/hono-demo/
/studio-prod/storefront/
```

### Ansible 配置

编辑 `ansible/inventory.yml` 设置服务器地址：

```yaml
all:
  hosts:
    production:
      ansible_host: your-server.com
      ansible_user: deploy
```

## 🛠️ 故障排查

### 构建失败

```bash
# 检查 ECR 登录
aws ecr get-login-password --region us-west-2 | docker login --username AWS --password-stdin 912951144733.dkr.ecr.us-west-2.amazonaws.com

# 检查 psenv 是否安装
which psenv
```

### 部署失败

```bash
# 检查 Ansible 连接
ansible all -i ansible/inventory.yml -m ping

# 查看详细日志
ansible-playbook -i ansible/inventory.yml ansible/deploy-app.yml -e service_name=hono-demo -vvv
```

### 服务无法启动

```bash
# SSH 到服务器查看日志
ssh deploy@your-server.com
cd /srv/studio/js-apps/hono-demo/current
docker compose logs
docker compose ps
```

## 📚 相关文档

- [Caddy 文档](https://caddyserver.com/docs/)
- [Docker Rollout](https://github.com/Wowu/docker-rollout)
- [Ansible 文档](https://docs.ansible.com/)
- [mise 文档](https://mise.jdx.dev/)
