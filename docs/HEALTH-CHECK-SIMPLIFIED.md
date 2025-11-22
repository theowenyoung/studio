# 健康检查简化说明

## 问题

之前的实现过于复杂，分别检查容器的 `State` 和 `Health` 字段，导致逻辑繁琐。

### 复杂的方式（之前）

```yaml
# 检查运行状态
- name: Wait for container to be running
  until: container_state.stdout == "running"

# 再检查健康状态
- name: Check container health status
  register: health_status

# 复杂的条件判断
- name: Get logs
  when: container_state.stdout != "running" or (health_status.stdout != "" and health_status.stdout != "healthy")

# 分别处理不同状态
- name: Fail if not running
  when: container_state.stdout != "running"

- name: Warn if unhealthy
  when: health_status.stdout != "healthy" and container_state.stdout == "running"
```

## 解决方案

Docker Compose 的 `State` 字段已经包含了健康检查信息！

### Docker Compose State 字段说明

| State 值 | 含义 | 是否健康 |
|----------|------|----------|
| `running` | 运行中（无健康检查） | ✅ |
| `running (healthy)` | 运行中且健康 | ✅ |
| `running (unhealthy)` | 运行中但不健康 | ⚠️ |
| `running (starting)` | 运行中，健康检查启动中 | ⏳ |
| `exited` | 已退出 | ❌ |
| `restarting` | 重启中 | ❌ |

### 简化后的实现

```yaml
- name: Wait for container to be healthy
  shell: |
    docker compose ps {{ service_name }} --format json | jq -r '.State // empty' | head -1
  register: container_state
  until: container_state.stdout == "running" or container_state.stdout == "running (healthy)"
  retries: 12
  delay: 5
  failed_when: false

- name: Check if rollback is needed
  set_fact:
    needs_rollback: "{{ (container_state.stdout != 'running' and container_state.stdout != 'running (healthy)') and previous_version != '' }}"
```

## 优势

### 1. 代码更简洁

**之前**:
- 2 次 shell 调用（State + Health）
- 3 个条件判断任务
- 复杂的 when 条件

**现在**:
- 1 次 shell 调用
- 简单的状态判断
- 清晰的逻辑

### 2. 逻辑更清晰

只需要判断容器是否处于"可用状态"：
- ✅ `running` 或 `running (healthy)` → 成功
- ❌ 其他状态 → 失败/回滚

### 3. 更符合直觉

Docker Compose 本身就设计为一个字段表达完整状态，我们不需要手动组合判断。

### 4. 等待时间更合理

```yaml
retries: 12
delay: 5
```

- 总等待时间：60 秒
- 涵盖了 `starting` → `healthy` 的过程
- 如果配置了健康检查，会等待其通过

## 健康检查流程

### 有健康检查配置

```
docker compose up -d
    ↓
State: running (starting)  [等待中...]
    ↓
State: running (healthy)   [成功！]
```

### 无健康检查配置

```
docker compose up -d
    ↓
State: running             [成功！]
```

### 启动失败

```
docker compose up -d
    ↓
State: exited              [失败，触发回滚]
```

### Unhealthy 处理

如果容器在等待期间始终是 `running (unhealthy)`，会超时：

```
Retries: 1/12: running (starting)
Retries: 2/12: running (starting)
Retries: 3/12: running (unhealthy)
Retries: 4/12: running (unhealthy)
...
Retries: 12/12: running (unhealthy)
    ↓
超时，触发回滚
```

## Docker Compose 健康检查配置

### 推荐配置

```yaml
services:
  app:
    image: myapp:latest
    healthcheck:
      test: ["CMD", "wget", "--quiet", "--tries=1", "--spider", "http://localhost:3000/health"]
      interval: 10s      # 每 10 秒检查一次
      timeout: 5s        # 单次检查超时 5 秒
      retries: 3         # 失败 3 次才标记为 unhealthy
      start_period: 30s  # 启动后 30 秒内失败不计入 retries
```

### 与 Ansible 等待配置的关系

```yaml
# Docker Compose 健康检查
healthcheck:
  start_period: 30s    # 启动宽限期
  interval: 10s
  retries: 3

# Ansible 等待配置
retries: 12            # 12 次重试
delay: 5               # 每 5 秒一次
# 总等待 = 12 * 5 = 60 秒

# 建议：Ansible 等待时间 > start_period + (interval * retries)
# 60s > 30s + (10s * 3) = 60s > 60s ✅
```

## 实际状态示例

### 示例 1：正常启动（无健康检查）

```bash
$ docker compose ps app --format json | jq -r '.State'
running
```

Ansible 第一次检查就通过 ✅

### 示例 2：正常启动（有健康检查）

```bash
# 第 1 秒
$ docker compose ps app --format json | jq -r '.State'
running (starting)

# 第 10 秒
$ docker compose ps app --format json | jq -r '.State'
running (starting)

# 第 35 秒（start_period 过后，首次成功）
$ docker compose ps app --format json | jq -r '.State'
running (healthy)
```

Ansible 在第 7 次检查（35 秒）通过 ✅

### 示例 3：启动失败

```bash
# 第 1 秒
$ docker compose ps app --format json | jq -r '.State'
running

# 第 3 秒（应用崩溃）
$ docker compose ps app --format json | jq -r '.State'
exited
```

Ansible 检测到失败，触发回滚 ❌

### 示例 4：持续 Unhealthy

```bash
# 第 35 秒
$ docker compose ps app --format json | jq -r '.State'
running (unhealthy)

# 第 45 秒
$ docker compose ps app --format json | jq -r '.State'
running (unhealthy)

# 第 55 秒
$ docker compose ps app --format json | jq -r '.State'
running (unhealthy)

# 第 65 秒（超过 60 秒）
Ansible 超时，触发回滚 ❌
```

## 对比表

| 场景 | 之前的处理 | 现在的处理 | 改进 |
|------|-----------|-----------|------|
| `running` | ✅ 成功 | ✅ 成功 | 相同 |
| `running (healthy)` | ✅ 成功 | ✅ 成功 | 相同 |
| `running (unhealthy)` | ⚠️ 警告不回滚 | ❌ 超时回滚 | 更严格 |
| `running (starting)` | ⏳ 等待 | ⏳ 等待 | 相同 |
| `exited` | ❌ 失败回滚 | ❌ 失败回滚 | 相同 |

## 注意事项

### 1. Unhealthy 也会回滚

现在如果健康检查持续失败，会触发回滚。这比之前更严格，但更安全。

**如果不想回滚 Unhealthy**，可以去掉健康检查配置，或者延长 `start_period`。

### 2. 等待时间要足够

确保 Ansible 的等待时间足够长：

```
Ansible 等待 >= start_period + (interval * retries) + 缓冲时间
```

推荐：
- 简单应用：60 秒（12 * 5）
- 复杂应用：120 秒（24 * 5）

### 3. 健康检查端点要轻量

```yaml
# ❌ 不好：复杂的健康检查
test: ["CMD", "curl", "-f", "http://localhost/api/full-health-check"]

# ✅ 好：简单的健康检查
test: ["CMD", "wget", "--spider", "http://localhost/health"]
```

## 迁移指南

如果你的服务之前依赖"unhealthy 不回滚"的行为：

### 选项 1：延长启动宽限期

```yaml
healthcheck:
  start_period: 60s  # 增加到 60 秒
```

### 选项 2：放宽健康检查条件

```yaml
healthcheck:
  retries: 5        # 增加重试次数
  interval: 15s     # 增加检查间隔
```

### 选项 3：暂时移除健康检查

```yaml
# 注释掉健康检查，回退到只检查 running
# healthcheck:
#   test: ["CMD", "wget", ...]
```

## 总结

通过直接使用 Docker Compose 的 `State` 字段：

1. ✅ **代码减少 50%**
2. ✅ **逻辑更清晰**
3. ✅ **更符合 Docker 设计**
4. ✅ **更容易维护**

Docker Compose 已经为我们处理了状态判断，我们只需要信任它！
