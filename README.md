# Studio

个人项目的 monorepo，用于部署容器化应用到裸机（如 Hetzner 服务器）

## 项目结构

```
studio/
├── js-apps/           # Node.js 应用 (hono-demo, proxy, blog, storefront, api, admin)
├── js-packages/       # 共享 TypeScript 包
├── infra-apps/        # 基础设施 (postgres, redis, caddy, backup, db-prepare)
├── external-apps/     # 第三方服务 (meilisearch, owen-blog)
├── rust-packages/     # Rust 工具 (psenv - AWS Parameter Store 同步)
├── ansible/           # 部署 playbooks
├── docker/            # 共享 Dockerfiles
└── scripts/           # 构建和部署脚本
```

## 快速开始

### 前置要求

- 在 `ansible/inventory.yml` 里配置服务器 IP 地址
- 统一使用 [mise](https://mise.dev) 管理任务，根目录用 `mise run`（别名 `mr`），应用内部用 `pnpm`

<details>
<summary>推荐的 mise bashrc 配置</summary>

```bash
if command -v mise >/dev/null 2>&1; then
  eval "$(mise activate bash)"
fi

source <(mise completion bash --include-bash-completion-lib)

function mr() {
  mise run "$@"
}
```

</details>

### 首次设置

```bash
# 1. 安装本地 HTTPS 证书
brew install mkcert
mkcert -install
mkdir -p infra-apps/caddy/.local/certs
mkcert -cert-file infra-apps/caddy/.local/certs/_wildcard.studio.localhost.pem \
       -key-file infra-apps/caddy/.local/certs/_wildcard.studio.localhost-key.pem \
       "*.studio.localhost"

# 2. 初始化环境
mr env                    # 从 AWS Parameter Store 同步 .env 文件
docker network create shared
mr up                     # 启动基础设施 (postgres, redis, caddy)
mr dev-db-prepare         # 创建数据库和用户

# 3. 安装依赖并初始化应用
pnpm install
mr dev-db-migrate         # 运行应用数据库迁移
```

### 日常开发

```bash
mr up                     # 启动基础设施（如果未启动）
mr dev-hono               # 启动单个应用
mr dev                    # 启动所有应用
mr down                   # 停止基础设施
```

## 架构设计

### 环境自动检测

根据 git 分支自动决定部署目标，无需手动指定：

- **main 分支** → 生产环境 (prod)
- **其他分支** → 预览环境 (preview)

### Preview 环境隔离

每个功能分支都有独立的预览环境（使用双分隔符便于解析）：

| 资源   | 分支 `feat-auth` 示例                                    |
| ------ | -------------------------------------------------------- |
| 数据库 | `hono_demo__feat_auth`（双下划线）                       |
| 域名   | `hono-demo--feat-auth.preview.owenyoung.com`（双中划线） |
| 容器   | `hono-demo--feat-auth-hono-demo-1`                       |
| 目录   | `/srv/studio/js-apps/hono-demo--feat-auth`               |

### 环境变量模板

使用 `psenv` (Rust 工具) 进行两阶段渲染：

```bash
# .env.example 示例
POSTGRES_USER=                                    # 源变量：从 AWS Parameter Store 获取
DB_HOST=${CTX_PG_HOST:-localhost}                 # 计算变量：CTX_* 由构建脚本注入
DATABASE_URL=postgresql://${POSTGRES_USER}@${DB_HOST}/${POSTGRES_DB}
```

- **源变量**: 敏感信息存储在 AWS Parameter Store，构建时拉取
- **计算变量**: `${VAR:-default}` 语法，本地开发不设置 `CTX_*` 则使用默认值

### 多服务器部署

生产环境支持多台服务器，每台有独立的基础设施。

**服务器配置** (`ansible/inventory.yml`)：`prod1`（主）、`prod2`（副，按需启用）、`preview`

**指定应用部署目标**：在 `.env.example` 中添加 `DEPLOY_SERVER=prod2`

**数据库迁移分离**：

```
infra-apps/db-prepare/
├── migrations/           # 通用（001-099，所有服务器）
├── migrations-prod1/     # prod1 专属（101-199）
├── migrations-prod2/     # prod2 专属（201-299）
└── migrations-prod3/     # prod3 专属（301-399）
```

<details>
<summary>添加新服务器步骤</summary>

1. 在 `ansible/inventory.yml` 添加服务器配置
2. 创建 `migrations-prodN/` 目录
3. `mr server-init` 初始化服务器
4. `mr deploy-infra` 部署基础设施
5. `mr deploy-db-prepare --server=prodN` 创建数据库
6. 在应用 `.env.example` 中设置 `DEPLOY_SERVER=prodN`

</details>

## 部署指南

### 1. 准备服务器

```bash
# 安装 Ansible 依赖（首次）
ansible-galaxy install -r ansible/requirements.yml

# 在 Hetzner 创建服务器，绑定 >10G volume 用于数据存储

# 创建 deploy 用户
mr server-init-user <server-ip> [<server-ip>...]

# 更新 ansible/inventory.yml 后初始化服务器
mr server-init
```

### 2. 部署基础设施

> 在 main 分支执行部署到生产，其他分支部署到 preview，需分别执行。

```bash
mr deploy-infra           # 部署所有基础设施
mr deploy-db-prepare      # 创建数据库
```

### 3. 部署应用

```bash
mr deploy-hono            # 后端应用（Docker + 零停机）
mr deploy-storefront      # SSG 应用（静态文件）
mr deploy-owen-blog       # 外部应用
```

### 4. 数据库备份与恢复

```bash
# 连接服务器
mr ssh

# 在服务器上执行
mr db-backup-now          # 手动备份
mr db-restore-s3          # 从 S3 恢复最新备份
```

### 5. 回滚

切换到目标 commit 后重新 deploy 即可。

### 服务器目录结构

```
/srv/studio/
├── infra-apps/          # 基础设施
├── js-apps/             # 后端应用
└── ssg-apps/            # SSG 应用

/data/
├── docker/              # Docker volumes
└── backups/             # 备份数据
```

### ECR 镜像标签

- **生产**: `prod-latest`, `prod-20251125143052`
- **预览**: `preview-{branch}`, `preview-{branch}-20251125143052`

生命周期规则在首次构建时自动设置，已有仓库可执行 `mr ecr-lifecycle`。
