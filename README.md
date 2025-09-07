# studio

A unified monorepo containing all my public projects, experiments, and deployments. Everything I build, in one place.

## Quickstart


```
# 先在 .ssh/config 里面添加你的服务器 ip 的快捷方式, like:

Host prodowen1
  HostName 1.2.3.4
  User deploy
  Port 22

# 初始化服务器
mise bootstrapserverwithoutpass
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

## Requirements

- [Mise](https://mise.jdx.dev/)



