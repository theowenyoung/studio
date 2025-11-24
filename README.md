# Studio

## 原则


- 需要构建的，放在 `src`, 不需要的，可以放在根目录
- 统一使用 [mise](https://mise.dev) 作为软件版本/任务管理工具，只在每一个 app 项目内部使用 `package.json` 的 scripts, 根目录的任务管理统一用 mise 的 tasks 来管理，便于所有语言项目统一操作。

## Tips

推荐的 mise bashrc 配置（主要是配置自动补全和别名）

```
# check mise is exist
if command -v mise >/dev/null 2>&1; then
  eval "$(mise activate bash)"
fi

source <(mise completion bash --include-bash-completion-lib)

# 别人自动补全
function mr() {
  mise run "$@"
}

```



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
mr up

# 创建数据库和用户

mr db-init

# 首次启动 hono 应用, 生成数据库表

mr migrate-hono


```

### 开始开发


```
# 启动特定应用，或者全部应用

mr dev-hono

# 启动所有应用
make dev

```

## 部署

详细部署文档请查看 [DEPLOYMENT.md](./DEPLOYMENT.md)

### AWS ECR 设置

请在 ECR 编辑 JSON Rule 规则：

```json
{
  "rules": [
    {
      "rulePriority": 1,
      "description": "删除1天前的未标记镜像",
      "selection": {
        "tagStatus": "untagged",
        "countType": "sinceImagePushed",
        "countUnit": "days",
        "countNumber": 1
      },
      "action": {
        "type": "expire"
      }
    },
    {
      "rulePriority": 2,
      "description": "生产环境：保留最新5个 prod-* 镜像",
      "selection": {
        "tagStatus": "tagged",
        "tagPrefixList": ["prod-"],
        "countType": "imageCountMoreThan",
        "countNumber": 5
      },
      "action": {
        "type": "expire"
      }
    },
    {
      "rulePriority": 3,
      "description": "预览环境：删除3天前的 preview-* 镜像",
      "selection": {
        "tagStatus": "tagged",
        "tagPrefixList": ["preview-"],
        "countType": "sinceImagePushed",
        "countUnit": "days",
        "countNumber": 3
      },
      "action": {
        "type": "expire"
      }
    }
  ]
}
```

**镜像标签规则**：
- **生产环境** (main 分支)：
  - `prod-latest` - 最新版本
  - `prod-20251125143052` - 带时间戳的历史版本
  - 策略：保留最新 5 个版本（支持快速回滚）

- **预览环境** (其他分支)：
  - `preview-{branch}` - 分支的最新版本（如 `preview-feature-x`）
  - `preview-{branch}-20251125143052` - 带时间戳的版本
  - 策略：删除 3 天前的镜像（支持多分支并行开发，自动清理过期分支）
  - 注意：preview 服务器已缓存镜像，ECR 删除不影响运行中的容器

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
# prod
mr server-init-user <server-ip>
# preview
mr server-init-user <server-ip>

# 第二步：配置服务器环境（安全加固、Docker、数据盘挂载等）
mr server-init
```

#### 2. 部署基础设施

```bash
# 一次性部署所有基础设施（postgres, redis, caddy, backup, 数据库）
mr deploy-infra

# 或分别部署
mr deploy-postgres
mr deploy-redis
mr deploy-caddy
mr deploy-backup
mr deploy-infra-db-admin
```

#### 2.5 是否从以前的数据库中恢复?

```
# ssh 登陆服务器
mr ssh

cd /srv/studio
mr db-restore-s3
```

#### 3. 部署应用

```bash
# 后端应用（Docker 容器 + 零停机）
mr deploy-hono

# 外部应用（Docker 容器 + 零停机）
mr deploy-owen-blog

# SSG 应用（静态文件）
mr deploy-storefront
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


### 如何恢复数据库备份

```
# 连接到服务器
mr ssh
```

```
# 备份现有的，如果有需要
mr db-backup-now
# 恢复的时候，postgres 需要是一个全新的示例，并且已经创建了响应的数据库和用户，可以在本地运行 mr deploy-db-admin 来创建用户

# 接下来 restore 最新的 s3 备份
mr db-restore-s3
```

