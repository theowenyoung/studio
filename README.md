# Studio

## 原则


- 需要构建的，放在 `src`, 不需要的，可以放在根目录
- 统一使用 [mise](https://mise.dev) 作为软件版本/任务管理工具，只在每一个 app 项目内部使用 `package.json` 的 scripts, 根目录的任务管理统一用 mise 的 tasks 来管理，便于所有语言项目统一操作。


## 本地开发


为了简单方便，本地开发也采用 https 证书，


### 只需要一次

```
# brew 安装 mkcert 本地证书管理工具
brew install mkcert

# 安装 mkcert 的证书到本地系统，并且c信任它。
mkcert -install

# 生成本地域名证书
mkdir -p infra-apps/caddy/.local/certs
mkcert -cert-file infra-apps/caddy/.local/certs/_wildcard.studio.localhost.pem \
       -key-file infra-apps/caddy/.local/certs/_wildcard.studio.localhost-key.pem \
       "*.studio.localhost"

# 从 AWS Parameter Store 远程同步 .env 文件
mr env

# 创建共享网络
docker network create shared

# 启动 service，比如postgres, redis, caddy
mise run up

# 创建数据库和用户

mise run db-init

# 首次启动 hono 应用, 生成数据库表

mise run migrate-hono


```

### 开始开发


```
# 启动特定应用，或者全部应用

mise run dev-hono

# 启动所有应用
make dev

```

## 部署

详细部署文档请查看 [DEPLOYMENT.md](./DEPLOYMENT.md)

### AWS ECR 设置

请在 ECR 编辑 JSON Rule 规则：

```
{
  "rules": [
    {
      "rulePriority": 1,
      "description": "删除3天前的未标记镜像",
      "selection": {
        "tagStatus": "untagged",
        "countType": "sinceImagePushed",
        "countUnit": "days",
        "countNumber": 3
      },
      "action": {
        "type": "expire"
      }
    },
    {
      "rulePriority": 2,
      "description": "保留最新5个标记镜像",
      "selection": {
        "tagStatus": "any",
        "countType": "imageCountMoreThan",
        "countNumber": 5
      },
      "action": {
        "type": "expire"
      }
    }
  ]
}
```

### 快速开始

#### 0. 在 <https://www.hetzner.com/> 创建服务器，并且绑定一个大小大于 10G volume, 用于所有的数据存储。

#### 0. 准备工作

```bash
# 安装 Ansible Galaxy 依赖（首次运行）
ansible-galaxy install -r ansible/requirements.yml
```

#### 1. 初始化服务器

```bash
# 第一步：创建 deploy 用户（在本地执行）
mise run server-init-user <server-ip>

# 第二步：配置服务器环境（安全加固、Docker、数据盘挂载等）
mise run server-init
```

#### 2. 部署基础设施

```bash
# 一次性部署所有基础设施（postgres, redis, caddy, backup, 数据库）
mise run deploy-infra

# 或分别部署
mise run deploy-postgres
mise run deploy-redis
mise run deploy-caddy
mise run deploy-backup
```

#### 3. 创建数据库和数据库用户

```
mise run deploy-infra-db-admin
```

#### 3. 部署应用

```bash
# 后端应用（Docker 容器 + 零停机）
mise run deploy-hono

# 外部应用（Docker 容器 + 零停机）
mise run deploy-owen-blog

# SSG 应用（静态文件）
mise run deploy-storefront
```

#### 4. 回滚

在 git 切换到某个 commit, 然后重新 deploy.


### 服务器目录结构

```
/srv/studio/
├── infra-apps/          # 基础设施（postgres, redis, caddy）
├── js-apps/             # 后端应用（hono-demo）
└── ssg-apps/            # SSG 应用（storefront, blog）

/data/
├── docker/              # Docker volumes（自动管理）
└── backups/             # 备份数据（deploy 用户可访问）
```

### 版本管理

- 版本格式：`YYYYMMDDHHmmss`（如 `20251120174405`）
- 自动保留最近 3 个版本
- 快速回滚：切换软链接到上一版本


