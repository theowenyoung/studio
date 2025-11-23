# 零停机部署指南

## 概述

本项目已配置使用 `docker-rollout` 实现零停机部署。每次部署时：

1. **扩容**: 启动新版本容器，与旧版本容器并行运行
2. **健康检查**: 等待新容器通过 healthcheck（最长 90 秒）
3. **流量切换**: 新容器就绪后，代理（Caddy）自动将流量分发到新容器
4. **清理**: 移除旧版本容器

## 工作原理

### docker-rollout 部署流程

```
时间轴:
T0: [旧容器 v1] ← 100% 流量
    ↓
T1: [旧容器 v1] [新容器 v2] ← 流量分发到两个容器
    ↓ (等待 healthcheck)
T2: [新容器 v2] ← 100% 流量（旧容器已移除）
```

### 关键配置

#### 1. docker-rollout 安装位置
```
/usr/local/lib/docker/cli-plugins/docker-rollout  # Docker 插件
/usr/local/bin/docker-rollout                      # 符号链接（可选）
```

#### 2. Healthcheck 配置示例

`docker-compose.yml`:
```yaml
services:
  hono-demo:
    image: your-image:latest
    healthcheck:
      test: ["CMD", "wget", "--quiet", "--tries=1", "--spider", "http://localhost:3000/"]
      interval: 10s      # 每 10 秒检查一次
      timeout: 5s        # 单次检查超时时间
      retries: 3         # 失败 3 次才标记为 unhealthy
      start_period: 20s  # 容器启动后等待 20 秒再开始检查
    networks:
      - shared
    restart: unless-stopped
```

**重要限制**（docker-rollout 要求）：
- ❌ 不能使用 `container_name`
- ❌ 不能使用 `ports` 映射（必须通过反向代理访问）
- ✅ 必须使用 Docker 网络 + 反向代理（如 Caddy）

#### 3. Caddy 反向代理配置

Caddy 自动发现同名服务的多个实例，并进行负载均衡：

```caddy
hono-demo.example.com {
    reverse_proxy hono-demo:3000
}
```

当有多个 `hono-demo` 容器时（如 `hono-demo-1`、`hono-demo-2`），Caddy 自动将流量分发到所有健康的容器。

## 如何测试零停机部署

### 方法 1: 使用自动化测试脚本（推荐）

1. **启动测试脚本**（持续发送请求）:
   ```bash
   ./test-zero-downtime.sh https://hono-demo.yourdomain.com
   ```

2. **在另一个终端运行部署**:
   ```bash
   mr deploy-hono-demo
   ```

3. **观察输出**:
   - ✅ 所有请求都应该成功（HTTP 200）
   - ❌ 不应该有失败或超时
   - 📊 成功率应该是 100%

**期望结果**：
```
[2024-11-24 01:52:30] ✅ 成功 - HTTP 200 - 响应时间: 0.123s
[2024-11-24 01:52:31] ✅ 成功 - HTTP 200 - 响应时间: 0.115s
[2024-11-24 01:52:31] ✅ 成功 - HTTP 200 - 响应时间: 0.128s
[2024-11-24 01:52:32] ✅ 成功 - HTTP 200 - 响应时间: 0.121s  ← 部署开始
[2024-11-24 01:52:32] ✅ 成功 - HTTP 200 - 响应时间: 0.119s
[2024-11-24 01:52:33] ✅ 成功 - HTTP 200 - 响应时间: 0.134s  ← 两个容器同时运行
[2024-11-24 01:52:33] ✅ 成功 - HTTP 200 - 响应时间: 0.127s
[2024-11-24 01:52:34] ✅ 成功 - HTTP 200 - 响应时间: 0.122s  ← 旧容器移除
[2024-11-24 01:52:34] ✅ 成功 - HTTP 200 - 响应时间: 0.118s

📊 统计 (运行时间: 60s)
  成功: 120 | 失败: 0 | 超时: 0 | 总计: 120
  成功率: 100.00%
```

### 方法 2: 手动测试（简单验证）

```bash
# 持续发送请求
while true; do
  curl -s -o /dev/null -w "%{http_code} - %{time_total}s\n" https://hono-demo.yourdomain.com
  sleep 0.5
done
```

在部署期间观察是否有非 200 的响应码。

### 方法 3: 监控容器生命周期

在服务器上实时监控容器：

```bash
# 终端 1：监控容器状态
ssh deploy@your-server 'watch -n 1 "docker ps | grep hono-demo"'

# 终端 2：运行部署
mr deploy-hono-demo
```

**你应该看到**：
```
时间 0s:  1 个容器 (hono-demo-1)
时间 10s: 2 个容器 (hono-demo-1, hono-demo-2) ← 关键时刻！
时间 40s: 1 个容器 (hono-demo-2)            ← 旧容器已移除
```

### 方法 4: Apache Bench 压力测试

```bash
# 部署前启动
ab -n 10000 -c 10 https://hono-demo.yourdomain.com/

# 检查结果
# Failed requests: 0          ← 应该是 0
# Connection errors: 0        ← 应该是 0
```

## 部署命令

```bash
# 部署单个服务（已配置零停机）
mr deploy-hono-demo
mr deploy-storefront
mr deploy-blog

# 或使用 mise 命令
mise run deploy-hono-demo
```

## 故障排查

### 问题 1: 部署失败，提示 "unknown flag: --timeout"

**原因**: `docker-rollout` 未正确安装为 Docker 插件

**解决**:
```bash
ssh your-server 'sudo mkdir -p /usr/local/lib/docker/cli-plugins && \
  sudo cp /usr/local/bin/docker-rollout /usr/local/lib/docker/cli-plugins/docker-rollout && \
  sudo chmod +x /usr/local/lib/docker/cli-plugins/docker-rollout'

# 验证
ssh your-server 'docker rollout --help'
```

### 问题 2: 容器创建失败

**原因**: 可能有端口冲突或使用了 `container_name`

**解决**: 检查 `docker-compose.yml`：
```yaml
# ❌ 错误
services:
  app:
    container_name: my-app  # 移除这行
    ports:
      - "3000:3000"         # 移除这行

# ✅ 正确
services:
  app:
    networks:
      - shared
```

### 问题 3: Healthcheck 超时

**原因**: 容器启动慢，90 秒内未就绪

**解决**: 调整超时时间（`ansible/playbooks/deploy-app.yml:79`）：
```yaml
docker rollout {{ service_name }} -t 180  # 增加到 180 秒
```

或优化 healthcheck 配置：
```yaml
healthcheck:
  start_period: 30s  # 增加启动宽限期
  interval: 5s       # 减少检查间隔
```

### 问题 4: 测试脚本显示失败

**检查**:
1. 服务是否真的在运行：`ssh your-server 'docker ps | grep hono-demo'`
2. Caddy 是否正常工作：`ssh your-server 'docker logs caddy-caddy-1 --tail 50'`
3. 防火墙/安全组是否开放了端口

## 文件修改记录

本零停机部署功能涉及以下文件修改：

1. **ansible/playbooks/deploy-app.yml**:
   - 将 `docker compose up` 替换为 `docker rollout`
   - 添加了部署输出和验证步骤

2. **ansible/tasks/install-docker-rollout.yml**:
   - 安装 docker-rollout 到 Docker CLI 插件目录
   - 创建符号链接方便直接调用

3. **test-zero-downtime.sh** (新文件):
   - 自动化测试脚本

## 参考资源

- [docker-rollout GitHub](https://github.com/Wowu/docker-rollout)
- [Docker Healthcheck 文档](https://docs.docker.com/engine/reference/builder/#healthcheck)
- [Caddy Reverse Proxy 文档](https://caddyserver.com/docs/caddyfile/directives/reverse_proxy)
