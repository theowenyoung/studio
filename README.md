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

# 安装 mkcert 的证书到本地系统，并且信任它。
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

mise run db:init

# 启动特定应用，或者全部应用

mise run dev:hono

# 启动所有应用
make dev

```

