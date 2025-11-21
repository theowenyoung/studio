# Proxy 部署文档

## 项目概述

Proxy 是一个基于 Hono 的 HTTP 代理服务，用于转发请求到指定的目标主机。

## 部署架构

- **应用类型**: Node.js 后端应用
- **框架**: Hono + @hono/node-server
- **端口**: 8002
- **域名**: proxy-demo.owenyoung.com
- **Docker 镜像**: ECR `studio/proxy`

## 部署文件结构

```
js-apps/proxy/
├── build.sh                           # 构建脚本
├── .env.example                       # 环境变量模板
├── templates/
│   └── docker-compose.prod.yml       # 生产环境 Docker Compose 模板
├── index.mjs                         # 应用入口文件
└── deploy-dist/                      # 部署产物（构建后生成）
    ├── docker-compose.yml
    ├── .env
    └── version.txt
```

## 环境变量

### 必需变量
无必需的外部环境变量，应用可以直接运行。

### 可选变量
- `NODE_ENV`: 运行环境（默认: production）
- `PORT`: 服务端口（默认: 8002）

## 部署流程

### 1. 构建和部署

使用 mise 任务一键部署：

```bash
# 构建并部署到生产环境
mise run deploy-proxy
```

该命令会自动执行：
1. 构建 Docker 镜像并推送到 ECR
2. 生成 docker-compose.yml
3. 部署到生产服务器

### 2. 手动构建（仅构建镜像）

```bash
mise run build-proxy
```

### 3. 单独部署步骤

如果需要分步执行：

```bash
# 1. 构建镜像和部署文件
bash js-apps/proxy/build.sh

# 2. 部署到服务器
ansible-playbook -i ansible/inventory.yml ansible/playbooks/deploy-app.yml -e service_name=proxy
```

## 部署后验证

### 检查服务状态

```bash
# SSH 到服务器
ssh deploy@<server-ip>

# 查看容器状态
docker ps --filter "name=proxy"

# 查看日志
docker logs -f current-proxy-1
```

### 测试服务

```bash
# 通过域名访问（需要在 _host 参数中指定目标主机）
curl "https://proxy-demo.owenyoung.com/?_host=example.com"

# 检查健康状态
curl -I https://proxy-demo.owenyoung.com/
```

## 服务管理

### 重启服务

```bash
ssh deploy@<server-ip>
cd /srv/studio/js-apps/proxy/current
docker compose restart proxy
```

### 查看日志

```bash
ssh deploy@<server-ip>
cd /srv/studio/js-apps/proxy/current
docker compose logs -f proxy
```

### 回滚版本

```bash
# 列出历史版本
ssh deploy@<server-ip>
ls -lt /srv/studio/js-apps/proxy/

# 回滚到上一个版本
ssh deploy@<server-ip>
cd /srv/studio/js-apps/proxy
PREV=$(ls -t | grep '^[0-9]\{14\}$' | sed -n 2p)
ln -sfn $PREV current
cd current && docker compose up -d
```

## Caddy 配置

Caddy 配置文件位于 `infra-apps/caddy/src/sites/proxy.caddy`：

```caddy
proxy-demo.owenyoung.com {
    import ../snippets/proxy-common.caddy proxy:8002
}
```

配置包含：
- 反向代理到 proxy:8002
- 静态资源缓存（1 年）
- 压缩（zstd, gzip）
- 安全头部
- 健康检查

更新 Caddy 配置后需要重新部署：

```bash
mise run deploy-caddy
```

## 监控和告警

### 健康检查

Docker Compose 配置了健康检查：
- 检查间隔: 30 秒
- 超时时间: 10 秒
- 重试次数: 3 次
- 启动等待: 40 秒

### 日志管理

日志配置：
- 驱动: json-file
- 最大文件大小: 10MB
- 保留文件数: 3 个

## 故障排查

### 容器无法启动

1. 检查日志：
   ```bash
   docker logs current-proxy-1
   ```

2. 检查端口占用：
   ```bash
   netstat -tlnp | grep 8002
   ```

3. 检查环境变量：
   ```bash
   cat /srv/studio/js-apps/proxy/current/.env
   ```

### 502 Bad Gateway

1. 确认容器正在运行：
   ```bash
   docker ps --filter "name=proxy"
   ```

2. 检查健康检查状态：
   ```bash
   docker inspect current-proxy-1 | grep -A 10 Health
   ```

3. 检查 Caddy 配置：
   ```bash
   docker exec current-caddy-1 caddy validate --config /etc/caddy/Caddyfile
   ```

## 性能优化

### 容器资源限制

如需限制资源使用，在 docker-compose.yml 中添加：

```yaml
services:
  proxy:
    deploy:
      resources:
        limits:
          cpus: '1'
          memory: 512M
        reservations:
          cpus: '0.5'
          memory: 256M
```

### 日志轮转

日志已配置自动轮转（10MB x 3 文件）。如需调整，修改 `templates/docker-compose.prod.yml` 中的 logging 配置。

## 相关链接

- [Hono Documentation](https://hono.dev/)
- [Docker Compose Reference](https://docs.docker.com/compose/compose-file/)
- [Caddy Server Documentation](https://caddyserver.com/docs/)
