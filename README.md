# Studio

个人项目的 monorepo，用于部署容器化应用到 Hetzner 服务器。

## 项目结构

```
studio-new/
├── js-apps/           # Node.js 应用 (hono-demo, proxy, blog, storefront, api, admin)
├── js-packages/       # 共享 TypeScript 包
├── infra-apps/        # 基础设施 (postgres, redis, caddy, backup, db-admin)
├── external-apps/     # 第三方服务 (meilisearch, owen-blog)
├── rust-packages/     # Rust 工具 (psenv - AWS Parameter Store 同步)
├── ansible/           # 部署 playbooks
├── docker/            # 共享 Dockerfiles
└── scripts/           # 构建和部署脚本
```

## 部署理念

### 环境自动检测

根据 git 分支自动决定部署目标：
- **main 分支** → 生产环境 (prod)
- **其他分支** → 预览环境 (preview)

无需手动指定环境，`mr deploy-hono` 会自动检测当前分支并部署到对应服务器。

### Preview 环境隔离

每个功能分支都有独立的预览环境（使用双分隔符便于解析）：
- **数据库隔离**: 分支 `feat-auth` → 数据库 `hono_demo__feat_auth`（双下划线）
- **域名隔离**: 分支 `feat-auth` → `https://hono-demo--feat-auth.preview.owenyoung.com`（双中划线）
- **容器隔离**: 分支 `feat-auth` → 容器 `hono-demo--feat-auth-hono-demo-1`
- **目录隔离**: 分支 `feat-auth` → `/srv/studio/js-apps/hono-demo--feat-auth`

### 环境变量模板渲染

使用 `psenv` (Rust 工具) 进行两阶段渲染：

```bash
# .env.example 示例
POSTGRES_USER=                                    # 源变量：从 AWS Parameter Store 获取
DB_HOST=${CTX_PG_HOST:-localhost}                 # 计算变量：根据环境自动替换
DATABASE_URL=postgresql://${POSTGRES_USER}@${DB_HOST}/${POSTGRES_DB}
```

- **源变量**: 敏感信息存储在 AWS Parameter Store，构建时拉取
- **计算变量**: 使用 `${VAR:-default}` 语法，`CTX_*` 上下文变量由构建脚本自动注入
- **本地开发**: 不设置 `CTX_*`，自动使用 localhost 默认值

详细文档: [docs/ENV_TEMPLATE_GUIDE.md](docs/ENV_TEMPLATE_GUIDE.md)

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

# 别名自动补全
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

mr dev-db-admin

# 首次启动 hono 应用, 生成数据库表

mr db-migrate-hono


```

### 开始开发


```
# 启动特定应用，或者全部应用

mr dev-hono

# 启动所有应用
mr dev

```

## 部署

详细部署文档请查看 [DEPLOYMENT.md](./DEPLOYMENT.md)


### 知识

ECR 镜像的生命周期规则会在首次构建时自动设置！ 无需手动操作。

**对于已有仓库**（首次迁移到此配置）：

```bash
# 为所有现有仓库设置生命周期规则（一次性）
mise run ecr-lifecycle
```

**镜像标签规则**：
- **生产环境** (main 分支)：
  - `prod-latest` - 最新版本
  - `prod-20251125143052` - 带时间戳的历史版本

- **预览环境** (其他分支)：
  - `preview-{branch}` - 分支的最新版本（如 `preview-feature-x`）
  - `preview-{branch}-20251125143052` - 带时间戳的版本

### 快速开始


#### 0. 在 <https://www.hetzner.com/> 创建服务器，并且绑定一个大小大于 10G volume, 用于所有的数据存储。

#### 0. 准备工作

```bash
# 安装 Ansible Galaxy 依赖（首次运行）
ansible-galaxy install -r ansible/requirements.yml
```

#### 1. 初始化服务器

```bash
# 第一步：在所有新服务器上创建 deploy 用户（在本地执行）
mr server-init-user <server-ip> [...server-ip]
mr server-init-user 138.199.157.194 5.78.126.18

# 第二步：在 ansible/inventory.yml 中更新服务器列表

# 第三步：配置服务器环境（安全加固、Docker、数据盘挂载等）
mr server-init
```

#### 2. 部署基础设施

> 注意： 在 main 分支支持将会部署生产服务器，在其他分支执行将会部署 preview 服务器，需要分别执行。

```bash
# 一次性部署所有基础设施（postgres, redis, caddy, backup）
mr deploy-infra

# 或分别部署
mr deploy-postgres
mr deploy-redis
mr deploy-caddy
mr deploy-backup
```

#### 2.1 创建所有需要的数据库

```
mr deploy-db-admin
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
# 是否已经创建数据库？如果没有，执行下面的命令(注意，每次切换分支，都需要执行一下 mr deploy-db-admin, 用于创建数据库)
mr deploy-db-admin
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

