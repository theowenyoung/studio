# 回滚安全性改进文档

## 问题

之前的回滚逻辑只检查 `previous_version` 变量是否为空，但没有验证该版本目录是否真实存在。这会导致以下问题：

### 场景 1：首次部署失败

```bash
# 首次部署，没有历史版本
/srv/studio/js-apps/hono-demo/
└── 20251121050000/  # 新版本（部署失败）
```

**问题**:
- `previous_version` 为空字符串
- 尝试创建符号链接到空路径
- 可能导致 Ansible 任务失败

### 场景 2：符号链接指向已删除的版本

```bash
# current 指向一个已被清理的版本
/srv/studio/js-apps/hono-demo/
├── 20251121050000/  # 新版本（部署失败）
└── current -> 20251121030000  # 指向已删除的目录！
```

**问题**:
- `previous_version = "20251121030000"`
- 但 `20251121030000/` 目录不存在
- 尝试启动不存在的版本会失败

### 场景 3：版本目录被手动删除

```bash
# 管理员手动清理了旧版本
/srv/studio/js-apps/hono-demo/
├── 20251121040000/  # 被手动删除
├── 20251121050000/  # 新版本（部署失败）
└── current -> 20251121040000  # 悬空链接
```

## 解决方案

### 改进后的回滚检查

```yaml
# 1. 检查上一版本目录是否存在
- name: Check if previous version directory exists
  stat:
    path: "{{ remote_base }}/{{ previous_version }}"
  register: previous_version_dir
  when: previous_version != ''

# 2. 综合判断是否可以回滚
- name: Check if rollback is possible
  set_fact:
    needs_rollback: >-
      {{
        (container_state.stdout != 'running' and container_state.stdout != 'running (healthy)')
        and previous_version != ''
        and previous_version_dir.stat.exists | default(false)
      }}
```

### 判断条件详解

回滚需要**同时满足**以下条件：

| 条件 | 说明 | 目的 |
|------|------|------|
| 容器未运行 | `container_state.stdout != 'running'` | 确认部署失败 |
| 有上一版本 | `previous_version != ''` | 有回滚目标 |
| 目录存在 | `previous_version_dir.stat.exists` | 确保可以回滚 |

### 处理不同场景

#### 场景 1：可以回滚

```yaml
- previous_version = "20251121040000"
- previous_version_dir.stat.exists = true
- needs_rollback = true

输出：
⚠️ Deployment failed! Rolling back to previous version: 20251121040000
✅ Rollback completed. Service is running on version 20251121040000
❌ Deployment of version 20251121050000 failed! Rolled back to 20251121040000.
```

#### 场景 2：首次部署失败（无历史版本）

```yaml
- previous_version = ""
- needs_rollback = false

输出：
❌ Deployment failed and no previous version available to rollback to!
❌ Deployment of version 20251121050000 failed! No previous version to rollback to.
```

#### 场景 3：历史版本目录不存在

```yaml
- previous_version = "20251121030000"
- previous_version_dir.stat.exists = false
- needs_rollback = false

输出：
❌ Deployment failed and no previous version available to rollback to!
❌ Deployment of version 20251121050000 failed! No previous version to rollback to.
```

## 完整流程图

```
部署失败
    ↓
检查 previous_version 是否为空？
    ├─ 是 → 无法回滚，直接失败 ❌
    └─ 否 → 继续
         ↓
    检查版本目录是否存在？
         ├─ 否 → 无法回滚，直接失败 ❌
         └─ 是 → 继续
              ↓
         执行回滚
              ├─ 停止失败容器
              ├─ 恢复符号链接
              ├─ 启动上一版本
              └─ 验证成功
                   ├─ 成功 → 回滚完成，标记部署失败 ❌
                   └─ 失败 → 回滚失败，标记部署失败 ❌
```

## 代码对比

### 之前（不安全）

```yaml
- name: Check if rollback is needed
  set_fact:
    needs_rollback: >-
      {{
        container_state.stdout != 'running'
        and previous_version != ''
      }}

- name: Restore previous version symlink
  file:
    src: "{{ remote_base }}/{{ previous_version }}"
    dest: "{{ remote_base }}/current"
    state: link
  when: needs_rollback
  # 如果目录不存在，这里会失败！
```

### 现在（安全）

```yaml
- name: Check if previous version directory exists
  stat:
    path: "{{ remote_base }}/{{ previous_version }}"
  register: previous_version_dir
  when: previous_version != ''

- name: Check if rollback is possible
  set_fact:
    needs_rollback: >-
      {{
        container_state.stdout != 'running'
        and previous_version != ''
        and previous_version_dir.stat.exists | default(false)
      }}

- name: Display no rollback available message
  debug:
    msg: "❌ Deployment failed and no previous version available to rollback to!"
  when: >-
    container_state.stdout != 'running'
    and (previous_version == '' or not (previous_version_dir.stat.exists | default(false)))

- name: Restore previous version symlink
  file:
    src: "{{ remote_base }}/{{ previous_version }}"
    dest: "{{ remote_base }}/current"
    state: link
  when: needs_rollback
  # 现在保证目录存在
```

## 用户体验改进

### 首次部署失败

**之前**:
```
TASK [Restore previous version symlink] ***
fatal: [production]: FAILED! => {
    "msg": "Path /srv/studio/js-apps/hono-demo/ does not exist"
}
```
用户困惑：为什么回滚失败？

**现在**:
```
TASK [Display no rollback available message] ***
ok: [production] => {
    "msg": "❌ Deployment failed and no previous version available to rollback to!"
}

TASK [Fail deployment without rollback] ***
fatal: [production]: FAILED! => {
    "msg": "❌ Deployment of version 20251121050000 failed! No previous version to rollback to. Check logs above."
}
```
清晰的错误信息！

### 版本目录被删除

**之前**:
```
TASK [Start previous version] ***
fatal: [production]: FAILED! => {
    "msg": "Docker compose file not found"
}
```
用户困惑：回滚为什么失败？

**现在**:
```
TASK [Display no rollback available message] ***
ok: [production] => {
    "msg": "❌ Deployment failed and no previous version available to rollback to!"
}

TASK [Fail deployment without rollback] ***
fatal: [production]: FAILED! => {
    "msg": "❌ Deployment of version 20251121050000 failed! No previous version to rollback to."
}
```
明确告知无法回滚！

## 防御性编程

### 使用 default() 过滤器

```yaml
previous_version_dir.stat.exists | default(false)
```

**原因**:
- 当 `previous_version == ''` 时，stat 任务会跳过
- `previous_version_dir` 可能未定义
- `default(false)` 确保总是有值

### 分离失败消息

```yaml
# 有回滚
- name: Fail deployment after rollback
  fail:
    msg: "Rolled back to {{ previous_version }}"
  when: needs_rollback

# 无回滚
- name: Fail deployment without rollback
  fail:
    msg: "No previous version to rollback to"
  when: deployment_failed and not needs_rollback
```

**好处**:
- 清晰区分两种失败情况
- 提供有针对性的错误信息

## 测试场景

### 测试 1：首次部署失败

```bash
# 清空服务目录
ssh deploy@server
rm -rf /srv/studio/js-apps/test-service/*

# 部署一个会失败的版本
# 修改 docker-compose.yml 使用错误的镜像
mise run deploy-test-service

# 预期：
# ✓ 显示 "no previous version available"
# ✓ 部署标记为失败
# ✓ 不尝试回滚
```

### 测试 2：回滚成功

```bash
# 部署第一个版本（成功）
mise run deploy-test-service

# 部署第二个版本（失败）
mise run deploy-test-service

# 预期：
# ✓ 检测到上一版本存在
# ✓ 自动回滚到上一版本
# ✓ 服务恢复运行
# ✓ 部署标记为失败
```

### 测试 3：手动删除历史版本后部署失败

```bash
# 部署第一个版本
mise run deploy-test-service

# 手动删除版本目录
ssh deploy@server
rm -rf /srv/studio/js-apps/test-service/20251121*

# 部署第二个版本（失败）
mise run deploy-test-service

# 预期：
# ✓ 检测到符号链接存在但目录不存在
# ✓ 显示 "no previous version available"
# ✓ 不尝试回滚
# ✓ 部署标记为失败
```

## 最佳实践

### 1. 保留足够的历史版本

```yaml
# 保留最近 3 个版本（当前配置）
- name: Keep only latest 3 versions
  shell: |
    cd {{ remote_base }}
    ls -t | grep -E '^[0-9]{14}$' | tail -n +4 | xargs -r rm -rf
```

**建议**: 至少保留 2-3 个版本

### 2. 定期检查悬空符号链接

```bash
# 添加到 cron 或监控
ssh deploy@server

cd /srv/studio
find . -type l ! -exec test -e {} \; -print
# 输出悬空的符号链接
```

### 3. 手动清理时先检查

```bash
# 不好：直接删除
rm -rf /srv/studio/js-apps/service/20251121030000

# 好：检查是否是 current 指向的版本
CURRENT=$(readlink /srv/studio/js-apps/service/current)
if [ "$(basename $CURRENT)" != "20251121030000" ]; then
  rm -rf /srv/studio/js-apps/service/20251121030000
else
  echo "Error: Cannot delete current version!"
fi
```

### 4. 部署前备份关键数据

```bash
# 在部署脚本中添加
- name: Backup database before deployment
  shell: |
    docker compose run --rm backup /usr/local/bin/backup-postgres.sh
  when: has_database
```

## 相关文件

- `ansible/playbooks/deploy-app.yml` - 应用部署
- `ansible/playbooks/deploy-infra.yml` - 基础设施部署
- `docs/DEPLOYMENT-ROLLBACK.md` - 回滚功能文档
- `docs/HEALTH-CHECK-SIMPLIFIED.md` - 健康检查简化文档

## 总结

通过添加版本目录存在性检查：

1. ✅ **防止首次部署失败时的错误回滚尝试**
2. ✅ **避免回滚到不存在的版本**
3. ✅ **提供清晰的错误信息**
4. ✅ **使部署流程更健壮**
5. ✅ **改善用户体验**

安全的回滚是可靠部署的基础！
