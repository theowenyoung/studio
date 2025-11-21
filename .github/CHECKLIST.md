# GitHub Actions 部署配置检查清单

## ✅ 已完成的配置

### 1. Workflow 文件

- [x] `.github/workflows/deploy-apps.yml` - 应用自动部署
  - 支持 push 自动触发
  - 支持手动触发（auto/all/单个服务）
  - 使用 paths-filter 智能检测变更
  - 并行部署多个服务
  - 完整的缓存策略

- [x] `.github/workflows/deploy-infra.yml` - 基础设施手动部署
  - 仅手动触发
  - 支持单独部署或全部部署

### 2. 文档

- [x] `.github/workflows/README.md` - Workflow 说明文档
- [x] `.github/DEPLOYMENT.md` - 完整部署指南
- [x] `.github/CHECKLIST.md` - 此检查清单

### 3. 工具脚本

- [x] `scripts/setup-github-secrets.sh` - GitHub Secrets 配置助手

### 4. 核心特性

- [x] 基于 mise 的统一部署命令
- [x] 智能路径检测（只部署变更的服务）
- [x] 多层缓存（mise tools + pnpm store + Docker layers）
- [x] 并行部署支持
- [x] 失败隔离（一个服务失败不影响其他）
- [x] 部署摘要和日志

## 📋 部署前准备清单

### 第一次使用时

- [ ] 1. 安装 GitHub CLI
  ```bash
  brew install gh
  gh auth login
  ```

- [ ] 2. 配置 GitHub Secrets（只需 2 个）
  ```bash
  ./scripts/setup-github-secrets.sh
  ```

  需要配置的 secrets：
  - [ ] `CI_AWS_ACCESS_KEY_ID` - CI 用的 AWS 访问密钥 ID
  - [ ] `CI_AWS_SECRET_ACCESS_KEY` - CI 用的 AWS 访问密钥

- [ ] 3. 配置 AWS Parameter Store
  ```bash
  ./scripts/setup-parameter-store.sh
  ```

  需要配置的参数：
  - [ ] `/studio-prod/DEPLOY_HOST` - 生产服务器地址
  - [ ] `/studio-prod/DEPLOY_USER` - 部署用户名
  - [ ] `/studio-prod/DEPLOY_SSH_KEY` - SSH 私钥（SecureString）

- [ ] 4. 配置 CI IAM 权限
  确保 CI 用户有访问 Parameter Store 和 ECR 的权限
  参考 `.github/SECRETS.md` 中的 IAM 策略

- [ ] 5. 验证 mise.toml 中的部署任务
  ```bash
  mise tasks ls | grep deploy
  ```

- [ ] 6. 确保服务器已配置好
  - [ ] deploy 用户已创建
  - [ ] SSH 密钥已添加到服务器
  - [ ] Docker 已安装
  - [ ] 必要的目录已创建（/srv/studio）

- [ ] 7. 测试本地部署（可选但推荐）
  ```bash
  mise run deploy-app-hono-demo
  ```

### 每次部署前

- [ ] 代码通过本地测试
  ```bash
  mise run dev    # 开发测试
  mise run lint   # 代码检查
  ```

- [ ] 提交信息清晰明确
  ```bash
  git commit -m "feat: add user profile page"
  ```

- [ ] 已合并最新的 main 分支
  ```bash
  git pull origin main
  git merge main
  ```

- [ ] 如有数据库变更，已准备好迁移脚本

## 🚀 部署流程

### 自动部署（推荐）

```bash
# 1. 推送到 main 分支
git push origin main

# 2. 监控部署状态
gh run watch

# 3. 验证部署结果
# 访问应用 URL 或查看服务器日志
```

### 手动部署

```bash
# 部署单个服务
gh workflow run deploy-apps.yml -f target=hono-demo

# 部署所有服务
gh workflow run deploy-apps.yml -f target=all

# 自动检测变更并部署
gh workflow run deploy-apps.yml -f target=auto
```

## 🔍 部署后验证

- [ ] 检查 GitHub Actions 运行状态
  ```bash
  gh run list --workflow=deploy-apps.yml
  ```

- [ ] 验证服务是否正常运行
  ```bash
  ssh deploy@your-server
  docker ps
  docker compose -f /srv/studio/js-apps/hono-demo/current/docker-compose.prod.yml ps
  ```

- [ ] 检查应用日志
  ```bash
  docker logs <container-id>
  ```

- [ ] 访问应用 URL 测试功能

## 🐛 常见问题排查

### Workflow 未触发

- [ ] 检查是否推送到 main 分支
- [ ] 检查是否修改了 js-apps/* 或 js-packages/*
- [ ] 查看 Actions 页面是否有错误信息

### SSH 连接失败

- [ ] 验证 DEPLOY_HOST 是否正确
- [ ] 验证 DEPLOY_USER 是否正确
- [ ] 验证 DEPLOY_SSH_KEY 格式（应包含完整的私钥）
- [ ] 测试本地 SSH 连接
  ```bash
  ssh -i ~/.ssh/id_rsa deploy@your-server
  ```

### Docker 构建失败

- [ ] 检查 Dockerfile 语法
- [ ] 本地测试 docker build
- [ ] 检查 ECR 凭证是否有效
- [ ] 查看详细的构建日志

### 部署成功但应用未更新

- [ ] 检查镜像标签是否正确
- [ ] 验证服务器上的镜像版本
- [ ] 检查 docker-compose.yml 配置
- [ ] 查看应用日志排查启动问题

## 📊 性能优化建议

- [ ] 监控缓存命中率
  - pnpm store 缓存应该在 90%+ 命中率
  - Docker layer 缓存应该节省 50%+ 构建时间

- [ ] 优化 Dockerfile
  - 合理排序 COPY 和 RUN 指令
  - 使用 .dockerignore 排除不必要的文件

- [ ] 定期清理
  - 清理服务器上的旧版本目录
  - 清理 ECR 中的旧镜像

## 🔒 安全检查

- [ ] Secrets 不在代码中出现
- [ ] SSH 密钥权限正确（600）
- [ ] AWS IAM 权限最小化
- [ ] 定期轮换凭证（建议 3-6 个月）
- [ ] 审查 GitHub Actions 日志，确保无敏感信息泄露

## 📝 维护计划

### 每周

- [ ] 检查部署日志
- [ ] 监控缓存效率
- [ ] 查看失败的 workflow runs

### 每月

- [ ] 清理服务器上的旧部署
- [ ] 清理 ECR 旧镜像
- [ ] 审查 GitHub Actions 使用量

### 每季度

- [ ] 轮换 SSH 密钥
- [ ] 轮换 AWS 凭证
- [ ] 更新依赖版本
- [ ] 审查部署流程效率

## 🎯 优化目标

当前性能指标：
- 首次部署：8-15 分钟
- 缓存命中后：2-5 分钟
- 无变更重部署：1-2 分钟

优化目标：
- [ ] 首次部署 < 10 分钟
- [ ] 缓存命中后 < 3 分钟
- [ ] 缓存命中率 > 90%

## 📚 相关资源

- [GitHub Actions 文档](https://docs.github.com/actions)
- [Docker Buildx 缓存](https://docs.docker.com/build/cache/)
- [pnpm 缓存](https://pnpm.io/cli/store)
- [mise 文档](https://mise.jdx.dev/)
- [Ansible 文档](https://docs.ansible.com/)

## ✨ 下一步改进

可选的增强功能（暂未实现）：

- [ ] 添加部署通知（Slack/Email）
- [ ] 添加部署审批流程
- [ ] 添加 staging 环境
- [ ] 添加自动回滚机制
- [ ] 添加性能监控集成
- [ ] 添加安全扫描（Docker 镜像）
- [ ] 添加 E2E 测试在部署前运行

---

**最后更新：** 2025-11-21
**维护者：** @green
