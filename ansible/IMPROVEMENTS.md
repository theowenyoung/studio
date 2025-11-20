# Ansible 架构改进说明

## 🎯 主要改进

### 1. Docker 和 UFW 的 iptables 冲突解决

**问题原因：**
- Docker 需要修改 iptables 规则来管理容器网络
- UFW（Uncomplicated Firewall）也会修改 iptables
- 两者同时修改 iptables 可能产生冲突

**解决方案：**
```yaml
执行顺序调整（简化版）：
1. 挂载数据盘              # 准备 /data
2. 配置 UFW（安全加固）     # 先配置防火墙
3. 安装 Docker             # Docker 在 UFW 基础上配置 iptables
4. 配置 Docker（网络等）    # 创建 shared 网络
```

**优点：**
- 先配置 UFW，再安装 Docker，Docker 能正确适应已有的防火墙规则
- 无需重启 Docker
- 流程更简洁

**代码位置：**
- `playbooks/init-server.yml` 行 36-64
- 关键：UFW first → Docker installation → Docker setup

### 2. 应用目录按需创建，数据由 Docker Volume 管理

**改进：**
- ❌ 旧方案：在 `init-server.yml` 中预先创建所有目录（应用目录、数据目录）
- ✅ 新方案：应用目录在部署时自动创建，数据目录由 Docker Volume 管理

**好处：**
- 无需预先规划目录结构
- 减少初始化时的复杂度
- 支持动态添加新服务
- Docker Volume 自动管理，备份和迁移更方便

**实现：**
```yaml
# deploy-infra.yml, deploy-app.yml, deploy-ssg.yml
- name: Ensure service base directory exists
  file:
    path: "{{ remote_base }}"    # 如 /srv/studio/infra-apps/postgres
    state: directory
    mode: '0755'
```

**Docker Volume 配置：**
```yaml
# docker-compose.prod.yml
volumes:
  postgres_data:
    # Docker 管理的 volume，数据存储在 /data/docker/volumes/
    # (因为 Docker daemon 配置了 data-root=/data/docker)
```

使用 Docker Volume 的优点：
- 自动创建，无需手动管理
- 权限自动处理（由 Docker daemon 管理）
- 可使用 `docker volume backup` 备份
- 可在容器间共享

**目录权限设计：**
- `/data/` - **deploy:deploy** (方便 deploy 用户日常操作，无需 sudo)
- `/data/docker/` - **root:root** (Docker daemon 专属，由 setup-docker.yml 明确创建)
  - `/data/docker/volumes/` - Docker 管理的 volumes
  - `/data/docker/containers/` - 容器日志（通过 Docker logging driver）
- `/data/backups/` - **deploy:deploy** (deploy 可以直接访问备份文件)
- `/srv/studio/` - **deploy:deploy** (应用代码，由 deploy 用户部署)

**权限设计优点：**
- ✅ deploy 用户可以直接访问 `/data/backups/`，无需 sudo
- ✅ deploy 用户通过 docker 组权限使用 docker 命令
- ✅ Docker daemon 独占管理 `/data/docker/`（root:root 0710）
- ✅ 各司其职，互不干扰

**日志管理策略：**
- ✅ **推荐**：使用 Docker logging driver（已在所有 docker-compose 中配置）
  - 日志自动存储在 `/data/docker/containers/xxx/xxx-json.log`
  - 使用 `docker logs <container>` 查看
  - 自动轮转（max-size: 10m, max-file: 3）
  - 权限由 Docker daemon 自动管理
- ❌ **不推荐**：bind mount 日志目录到宿主机
  - 需要手动管理目录权限
  - 需要匹配容器内运行用户的 UID
  - 增加配置复杂度

### 3. 常用工具包配置

**新增功能：**
通过 `ansible/group_vars/all.yml` 统一管理常用工具包：

```yaml
common_packages:
  # 基础工具
  - curl
  - wget
  - vim
  - git
  - htop
  - tree
  - jq

  # 网络工具
  - net-tools
  - dnsutils

  # 系统监控
  - sysstat
  - iotop

  # 构建工具
  - build-essential
```

**使用方式：**
- 在 `init-server.yml` 自动安装
- 可以在 `group_vars/all.yml` 中自定义列表
- 支持不同环境使用不同的工具集（通过 host_vars）

## 📁 新增文件

### ansible/group_vars/all.yml
全局变量配置文件，包含：
- ✅ 用户配置（deploy_user）
- ✅ 常用工具包列表（common_packages）
- ✅ 防火墙配置（firewall_allowed_tcp_ports）
- ✅ 安全配置（security_ssh_*）
- ✅ Docker 配置（docker_daemon_options）
- ✅ SSH 配置（sshd）

## 🔄 执行流程对比

### 旧流程（有问题）
```
1. Bootstrap
2. Mount
3. Docker 安装
4. Docker 配置
5. Security (启用 UFW) ❌ 覆盖 Docker iptables
6. 重启 Docker ❓ 需要手动恢复 iptables
7. 创建所有目录 ❌ 提前创建不必要的目录
```

### 新流程（优化后）
```
1. Bootstrap + 安装 common_packages ✅
2. Mount (/data) ✅ 准备数据盘
3. Security (UFW) ✅ 先配置防火墙
4. Docker 安装 ✅ Docker 适应已有防火墙
5. Docker 配置（网络、工具） ✅ 无需重启
6. 部署时创建目录 ✅ 按需创建，服务自己声明
```

## 🎨 配置管理优化

### 集中化变量管理
所有可配置项都在 `group_vars/all.yml` 中：

```yaml
# 以前：硬编码在 playbook 中
- name: Install tools
  apt:
    name:
      - curl
      - wget
      - vim  # 要改工具需要修改 playbook

# 现在：变量化配置
- name: Install common packages
  apt:
    name: "{{ common_packages }}"  # 只需修改 group_vars/all.yml
```

### 环境特定配置
支持为不同环境定制配置：

```
ansible/
├── group_vars/
│   └── all.yml              # 所有环境的默认配置
├── host_vars/
│   ├── production.yml       # 生产环境特定配置
│   └── staging.yml          # 测试环境特定配置
```

## 🛠️ 使用示例

### 自定义工具包
编辑 `ansible/group_vars/all.yml`：

```yaml
common_packages:
  - curl
  - wget
  - vim
  - your-custom-tool  # 添加你需要的工具
```

### 自定义防火墙端口
```yaml
firewall_allowed_tcp_ports:
  - "22"
  - "80"
  - "443"
  - "8080"  # 添加自定义端口
```

### 部署新服务（自动创建目录）
```bash
# 无需预先创建任何目录，直接部署
mise run deploy-new-app

# Ansible 会自动：
# 1. 创建 /srv/studio/js-apps/new-app
# 2. 创建版本目录
# 3. 部署服务
# 4. Docker 自动创建和管理 volumes
```

### 配置新服务的数据持久化
使用 Docker Volume（推荐）：
```yaml
# docker-compose.prod.yml
services:
  myservice:
    volumes:
      - myservice_data:/app/data

volumes:
  myservice_data:
    # Docker 自动管理，数据在 /data/docker/volumes/
```

如果需要访问宿主机特定目录，使用 bind mount：
```yaml
volumes:
  - /srv/studio/myservice/data:/app/data
```

## 🔍 调试和验证

### 验证 Docker 网络
```bash
# 检查 Docker iptables 规则
ssh deploy@server sudo iptables -L -n -v | grep DOCKER

# 检查 shared 网络
ssh deploy@server docker network inspect shared

# 测试容器间通信
ssh deploy@server docker run --rm --network shared alpine ping -c 1 postgres
```

### 验证目录和 Volume
```bash
# 查看应用目录
ssh deploy@server ls -la /srv/studio/

# 查看 Docker volumes
ssh deploy@server docker volume ls

# 查看特定 volume 详情
ssh deploy@server docker volume inspect postgres_data

# 查看容器日志
ssh deploy@server docker logs postgres
ssh deploy@server docker logs --tail 100 -f caddy  # 实时查看最近 100 行
```

### 特殊情况：需要 bind mount 到 /data 的目录

如果新服务需要 bind mount 到 `/data/xxx`（类似 backup 的 `/data/backups`）：

**方案 1：在 deploy-infra.yml 中创建目录（推荐）**
```yaml
# ansible/playbooks/deploy-infra.yml
- name: Create /data bind mount directories
  become: yes
  become_user: root
  file:
    path: /data/myservice
    state: directory
    owner: "{{ deploy_user }}"
    group: "{{ deploy_user }}"
    mode: '0755'
  when: service_name == 'myservice'
```

**方案 2：让 Docker 自动创建，然后修正权限**
```bash
# 部署后手动执行一次
ssh deploy@server sudo chown -R deploy:deploy /data/myservice
```

**建议：**
- 如果容器以 root 运行且 deploy 需要访问 → 使用方案 1
- 如果容器以特定 UID 运行 → 需要匹配该 UID（检查 `docker compose exec <service> id`）
- 如果只是应用数据 → 考虑使用 Docker volume 代替 bind mount

### 只运行特定部分
```bash
# 只安装 common packages
ansible-playbook -i inventory.yml playbooks/init-server.yml --tags packages

# 跳过安全配置
ansible-playbook -i inventory.yml playbooks/init-server.yml --skip-tags security

# 只验证 Docker 网络
ansible-playbook -i inventory.yml playbooks/init-server.yml --tags network
```

## 📚 参考

### Docker 和 UFW 冲突
- [Docker and UFW](https://docs.docker.com/network/packet-filtering-firewalls/)
- [UFW with Docker](https://github.com/chaifeng/ufw-docker)

### Ansible 最佳实践
- [Ansible Best Practices](https://docs.ansible.com/ansible/latest/tips_tricks/ansible_tips_tricks.html)
- [Variable Precedence](https://docs.ansible.com/ansible/latest/playbook_guide/playbooks_variables.html#variable-precedence-where-should-i-put-a-variable)
