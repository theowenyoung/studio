# studio

A unified monorepo containing all my public projects, experiments, and deployments. Everything I build, in one place.



## 本地开发


```
# brew 安装 mkcert 本地证书管理工具，然后安装

mkcert -install
make setup-local
```



## Quickstart


```
# 先在服务器挂载可变云盘，不需要自动挂载，待会儿初始化的时候会ansible会自动挂载，以后有状态的数据统一存储在这里。

# 先在服务器创建 deploy 用户
mise pre 1.2.3.4

# 在 .ssh/config 里面添加你的服务器 ip 的快捷方式, like:

Host prodowen1
  HostName 1.2.3.4
  User deploy
  Port 22

# 初始化服务器
mise bootstrapserverwithoutpass

# 上面的部署会自动把 block 挂载在 /data 目录下，以后目录就都放在 /data 下即可
```


## 生产环境

```
# 1. 安装依赖
ansible-galaxy install -r requirements.yml

# 2. 配置生产服务器信息
vim inventory/production/hosts.yml

# 3. 部署生产环境
ansible-playbook playbooks/site.yml

# 仅更新应用
ansible-playbook playbooks/deploy-app.yml
```


## 测试环境

```
# 创建测试环境（自动生成配置）
./scripts/create-test-env.sh test-pr-123 feature-branch 192.168.1.100

# 仅部署应用到测试环境
ansible-playbook -i inventory/testing/hosts-test-pr-123/hosts.yml playbooks/deploy-app.yml

# 销毁测试环境
./scripts/destroy-test-env.sh test-pr-123
```

## CI/CD 

```
# .gitlab-ci.yml 示例
deploy_test:
  stage: test
  script:
    - TEST_ID="test-${CI_COMMIT_SHORT_SHA}"
    - ./scripts/create-test-env.sh "$TEST_ID" "$CI_COMMIT_SHA" "$TEST_SERVER_IP"
  environment:
    name: test/$CI_COMMIT_REF_NAME
    url: http://test-$CI_COMMIT_SHORT_SHA.dev.example.com
    on_stop: destroy_test

destroy_test:
  stage: cleanup
  script:
    - TEST_ID="test-${CI_COMMIT_SHORT_SHA}"
    - ./scripts/destroy-test-env.sh "$TEST_ID"
  when: manual
```

## 🚀 新增功能: 零停机部署

基于 [docker-rollout](https://github.com/wowu/docker-rollout) 的现代化零停机部署方案现已集成：

```bash
# 完整技术栈部署（PostgreSQL + Redis + Caddy + 应用）
cd ansible
ansible-playbook -i inventory/production playbooks/deploy-full-stack.yml

# 零停机应用更新
docker rollout myapp

# 简化密钥管理（每应用一个 .env 文件）
./scripts/manage-secrets.sh upload myapp
```

### 核心特性

- 🔥 **零停机部署**: 用户无感知的应用更新
- 🔐 **简化密钥**: AWS Parameter Store 集成，每应用一个 `.env`
- ❤️ **健康检查**: 自动检测应用就绪状态
- 🛡️ **优雅停机**: 完整的请求排空机制
- 📁 **统一存储**: 所有数据存储在 `/data` 目录

详细文档：
- [零停机部署指南](ansible/ZERO-DOWNTIME-DEPLOYMENT.md)
- [基础设施文档](ansible/DOCKER-SERVICES-README.md)
- [密钥管理工作流](ansible/AWS-SECRETS-WORKFLOW.md)

## Requirements

- [Mise](https://mise.jdx.dev/)



