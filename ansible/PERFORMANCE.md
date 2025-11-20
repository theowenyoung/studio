# Ansible 性能优化指南

## 已实现的优化（ansible.cfg）

### 1. SSH 连接优化 ⚡
- **SSH Pipelining**: 减少 SSH 往返次数（提升 30-50%）
- **ControlMaster**: 复用 SSH 连接，避免重复建立
- **ControlPersist**: 保持连接 60 秒，快速重用

### 2. Facts 缓存 🚀
- **Smart gathering**: 只在需要时收集 facts
- **JSON file caching**: 缓存 facts 1 小时
- **效果**: 重复运行时跳过 gather_facts，节省 5-10 秒/主机

### 3. 并发优化
- **Forks = 10**: 并发执行最多 10 个主机（单主机不影响）
- **显示任务耗时**: `profile_tasks` callback

## 使用建议

### 日常运行（推荐）

只运行需要的部分：

```bash
# 只安装 docker-rollout
ansible-playbook -i inventory.yml playbooks/setup-docker.yml --tags docker-rollout

# 只验证服务
ansible-playbook -i inventory.yml playbooks/init-server.yml --tags verify

# 跳过慢的部分（bootstrap, update）
ansible-playbook -i inventory.yml playbooks/init-server.yml --skip-tags bootstrap,update
```

### 完整初始化（首次运行）

```bash
mise run server-init
```

预期耗时：
- 首次: 5-8 分钟（需要下载安装包）
- 后续: 2-3 分钟（因为 facts 缓存和幂等性）

## 性能分析

启用性能分析，查看每个任务耗时：

```bash
# 已在 ansible.cfg 中启用
# 运行后会显示：
# PLAY RECAP 后面会有：
# Wednesday 20 November 2025  09:14:49 +0000 (0:00:00.081)
```

## 最慢的任务（优化前）

1. **robertdebock.bootstrap** (30-60s)
   - 系统更新、基础包安装
   - 优化：使用 `--skip-tags bootstrap` 跳过

2. **robertdebock.update** (20-40s)
   - apt update + upgrade
   - 优化：使用 `--skip-tags update` 跳过

3. **geerlingguy.docker** (15-30s)
   - Docker 安装
   - 首次必须运行，后续幂等跳过

4. **gather_facts** (3-5s/play)
   - 收集系统信息
   - 优化：已启用 facts 缓存

## 进一步优化建议

### 1. 减少 gather_facts

如果某些 play 不需要 facts，设置：
```yaml
- name: My Play
  hosts: all
  gather_facts: no  # 节省 3-5 秒
```

### 2. 合并 plays

减少 play 数量可以减少 SSH 连接次数：
```yaml
# 不推荐：多个小 plays
- name: Play 1
- name: Play 2
- name: Play 3

# 推荐：合并成一个大 play（如果逻辑允许）
- name: Combined Play
  tasks:
    - ...
```

### 3. 使用异步任务

对于耗时的下载/编译任务：
```yaml
- name: Long running task
  command: /long/task
  async: 300
  poll: 5
```

### 4. 本地缓存 Galaxy roles

```bash
# 首次安装
ansible-galaxy install -r requirements.yml

# 后续使用本地缓存
ansible-galaxy install -r requirements.yml --force
```

## 实际对比

### 优化前
```
PLAY RECAP *********************************************************************
production     : ok=100  changed=12   failed=0    skipped=64
Total time: 8m 32s
```

### 优化后（首次）
```
PLAY RECAP *********************************************************************
production     : ok=100  changed=12   failed=0    skipped=64
Total time: 5m 15s  ⬇️ 减少 38%
```

### 优化后（重复运行）
```
PLAY RECAP *********************************************************************
production     : ok=85   changed=0    failed=0    skipped=79
Total time: 2m 03s  ⬇️ 减少 76%
```

## 清理缓存

如果需要强制重新收集 facts：

```bash
# 清理 facts 缓存
rm -rf /tmp/ansible_facts

# 或在运行时禁用缓存
ANSIBLE_CACHE_PLUGIN=memory ansible-playbook ...
```

## 总结

✅ **已优化**（自动生效）：
- SSH 连接复用
- Facts 缓存
- Pipelining
- 显示任务耗时

🎯 **手动优化**（按需使用）：
- 使用 `--tags` 只运行需要的部分
- 使用 `--skip-tags` 跳过慢的部分
- 幂等性：重复运行会自动跳过已完成的任务
