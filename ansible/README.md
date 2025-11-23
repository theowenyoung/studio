# Ansible 部署架构

## 📁 目录结构

```
ansible/
├── inventory.yml              # 服务器清单
├── requirements.yml           # Ansible Galaxy 依赖
├── playbooks/                 # Playbook 目录
│   ├── init-server.yml       # 主初始化流程
│   ├── security.yml          # 安全加固（使用 Galaxy roles）
│   ├── mount.yml             # 数据盘自动挂载
│   ├── setup-docker.yml      # Docker 配置
│   ├── deploy-infra.yml      # 部署基础设施
│   ├── deploy-app.yml        # 部署后端应用
│   └── deploy-ssg.yml        # 部署 SSG 应用
└── tasks/                     # 可复用任务
    ├── install-docker-rollout.yml
    └── verify-services.yml
```

## 🎯 设计原则

1. **使用社区最佳实践**：优先使用 Ansible Galaxy 成熟角色
2. **保持简单**：每个 playbook 职责单一，易于理解
3. **模块化**：通过 import_playbook 组合功能
4. **可重用**：tasks 目录存放可复用任务

## 🔧 Playbook 说明

### init-server.yml（主初始化流程）

导入其他 playbook，按顺序执行：

```yaml
1. bootstrap            # 系统基础配置（robertdebock.bootstrap）
2. mount.yml            # 挂载数据盘
3. security.yml         # 安全加固（UFW、SSH、Fail2ban）
4. Docker 安装          # 使用 geerlingguy.docker
5. setup-docker.yml     # Docker 配置（网络、工具）
```

### security.yml（安全加固）

使用社区角色进行安全配置：
- `willshersystems.sshd` - SSH 强化
- `geerlingguy.security` - 系统安全（fail2ban, 自动更新）
- `geerlingguy.firewall` - UFW 防火墙

### mount.yml（数据盘挂载）

自动检测并挂载最大的未使用磁盘到 `/data`：
- 自动检测可用磁盘
- 格式化为 ext4（带 label）
- 挂载到 /data
- 添加到 /etc/fstab

### setup-docker.yml（Docker 配置）

配置 Docker 使用 /data/docker：
- 创建 /data/docker 目录
- 配置 daemon.json
- 创建 shared 网络
- 安装 docker-rollout

### deploy-*.yml（部署流程）

三个独立的部署 playbook：
- `deploy-infra.yml` - 基础设施（postgres, redis, caddy）
- `deploy-app.yml` - 后端应用（零停机部署）
- `deploy-ssg.yml` - SSG 应用（静态文件）

## 🚀 使用方式

### 首次安装

```bash
# 1. 安装 Ansible Galaxy 依赖
ansible-galaxy install -r ansible/requirements.yml

# 2. 创建 deploy 用户
mise run server-init-user <server-ip>

# 3. 初始化服务器
mise run server-init
```

### 部署应用

```bash
# 基础设施
mise run deploy-postgres
mise run deploy-redis
mise run deploy-caddy

# 后端应用
mise run deploy-hono

# SSG 应用
mise run deploy-storefront
```

### 选择性运行

使用 tags 只运行特定部分：

```bash
# 只运行安全加固
ansible-playbook -i inventory.yml playbooks/init-server.yml --tags security

# 跳过数据盘挂载
ansible-playbook -i inventory.yml playbooks/init-server.yml --skip-tags mount

# 只创建目录
ansible-playbook -i inventory.yml playbooks/init-server.yml --tags directories
```

## 📦 依赖的 Galaxy Roles

| Role | 用途 | 版本 |
|------|------|------|
| robertdebock.bootstrap | 系统基础配置 | 6.3.3 |
| robertdebock.update | 系统更新 | 2.2.3 |
| geerlingguy.docker | Docker 安装 | 7.4.1 |
| willshersystems.sshd | SSH 配置 | 1.6.1 |
| geerlingguy.security | 安全加固 | 3.0.0 |
| geerlingguy.firewall | 防火墙配置 | 3.2.0 |

## 🔍 调试

```bash
# 查看详细输出
ansible-playbook -i inventory.yml playbooks/init-server.yml -vvv

# 测试连接
ansible all -i inventory.yml -m ping

# 查看 facts
ansible all -i inventory.yml -m setup
```

## 🐛 故障排查

### Mount 问题

如果遇到 `/data` 挂载失败（例如 "Can't open blockdev" 错误），请参考：

📖 **[MOUNT_TROUBLESHOOTING.md](./MOUNT_TROUBLESHOOTING.md)** - 详细的 mount 问题排查指南

**快速修复**:

```bash
# 1. 检查磁盘状态
ansible -i inventory.yml all -m shell -a "bash -s" < scripts/check-disk.sh

# 2. 运行自动修复
ansible-playbook -i inventory.yml playbooks/fix-mount.yml

# 3. 手动指定设备（如果自动检测失败）
ansible-playbook -i inventory.yml playbooks/fix-mount.yml -e "data_disk=/dev/sdb1"
```

常见问题：
- ❌ 尝试挂载整个磁盘 `/dev/sdb` → ✅ 应该挂载分区 `/dev/sdb1`
- ❌ 设备已经挂载在其他位置 → ✅ 先卸载再重新挂载
- ❌ fstab 有冲突条目 → ✅ 清理旧条目

### 性能优化

如果服务器初始化太慢，请参考：

📖 **[PERFORMANCE_OPTIMIZATION.md](./PERFORMANCE_OPTIMIZATION.md)** - 性能优化指南

**快速优化**:
- 跳过系统更新（默认已启用，可节省 2-10 分钟）
- 使用 tags 只运行必要的步骤
- 启用 SSH 连接复用（已在 ansible.cfg 中配置）

## 📝 自定义配置

可以通过变量自定义行为：

```yaml
# 在 inventory.yml 或 group_vars 中设置
deploy_user: deploy                    # 部署用户名
security_fail2ban_enabled: true        # 启用 fail2ban
firewall_allowed_tcp_ports:            # 开放端口
  - "22"
  - "80"
  - "443"
```

## 🎯 最佳实践

1. **幂等性**：所有 playbook 可以重复运行
2. **标签使用**：为任务添加合适的 tags
3. **变量管理**：使用 inventory 和 group_vars 管理变量
4. **社区角色**：优先使用成熟的 Galaxy 角色
5. **错误处理**：使用 block/rescue 处理错误
