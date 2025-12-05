# Owen Blog

个人博客，使用 Zola 静态站点生成器构建。

源仓库：https://github.com/theowenyoung/blog

## 构建流程

1. 从 GitHub 拉取源码（`--depth 1`）
2. 使用 `zola build` 构建静态文件到 `public/`
3. 使用 `docker/static-site/Dockerfile` 打包成 nginx 镜像
4. 推送到 ECR

## 部署

```bash
# 构建
mise run build-owen-blog

# 部署到生产环境
mise run deploy-owen-blog
```

## 技术栈

- **生成器**: Zola
- **Web 服务器**: Nginx (Alpine，复用 `docker/nodejs-ssg/nginx.conf`）
- **端口**: 3000
- **Docker 配置**: 复用 `docker/nodejs-ssg/docker-compose.template.yml`

## 环境变量

- `OWEN_GH_TOKEN`: GitHub token（从 AWS Parameter Store `/studio-prod/OWEN_GH_TOKEN` 获取）

## 复用的配置

此项目复用了以下共享配置：
- `docker/static-site/Dockerfile` - 静态站点 Dockerfile
- `docker/nodejs-ssg/nginx.conf` - Nginx 配置
- `docker/nodejs-ssg/docker-compose.template.yml` - Docker Compose 模板
