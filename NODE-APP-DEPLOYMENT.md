# Node.js 应用部署指南

## 🚀 **新增 Ansible Playbooks**

我已经为你创建了通用的 Node.js 应用部署 playbooks，仿照现有的基础设施部署模式。

### 📁 **创建的文件**

```
ansible/playbooks/
├── deploy-node-app.yml              # 🆕 通用 Node.js 应用部署
├── deploy-app-standalone.yml        # 🆕 快速单应用部署
└── templates/
    └── docker-rollout-node.sh.j2    # 🆕 零停机部署模板
```

## 🎯 **部署方式选择**

### **1. 完整部署** (`deploy-node-app.yml`)

**功能全面的部署方式：**
- ✅ 环境验证和检查
- ✅ 网络创建和管理
- ✅ 镜像构建控制
- ✅ 优雅停止现有容器
- ✅ 健康检查验证
- ✅ 部署状态报告
- ✅ 失败时日志诊断

**使用方式：**
```bash
# 使用 MISE 任务
mise run deploy-node-app app_name=node-demo env=aws build=true

# 直接使用 Ansible
ansible-playbook ansible/playbooks/deploy-node-app.yml \
  --extra-vars "app=node-demo env=production build=true"
```

### **2. 快速部署** (`deploy-app-standalone.yml`)

**简化的快速部署：**
- ✅ 直接调用应用的 deploy.sh 脚本
- ✅ 最小化配置和检查
- ✅ 适合开发和测试环境

**使用方式：**
```bash
# 使用 MISE 任务
mise run deploy-node-standalone app_name=node-demo env=aws

# 直接使用 Ansible
ansible-playbook ansible/playbooks/deploy-app-standalone.yml \
  --extra-vars "app=node-demo env=production"
```

## ⚙️ **配置参数**

### **完整部署参数**
| 参数 | 默认值 | 说明 |
|------|--------|------|
| `app` | node-demo | 应用名称 |
| `env` | production | 部署环境 (local/aws/production) |
| `build` | true | 是否构建镜像 |
| `node_env` | production | Node.js 环境变量 |
| `deploy_user` | deploy | 部署用户 |
| `aws_region` | us-west-2 | AWS 区域 |

### **快速部署参数**
| 参数 | 默认值 | 说明 |
|------|--------|------|
| `app` | node-demo | 应用名称 |
| `env` | aws | 部署环境 |

## 🛠️ **部署流程详解**

### **完整部署流程**
```
1. 参数验证
   ├── 检查应用名称
   ├── 验证部署脚本存在
   └── 确认应用配置存在

2. 环境准备
   ├── 检查共享网络
   ├── 创建网络（如需要）
   └── 显示部署计划

3. 应用部署
   ├── 停止现有容器
   ├── 构建新镜像（可选）
   ├── 启动新容器
   └── 等待服务启动

4. 验证和报告
   ├── 健康检查验证
   ├── 显示部署结果
   └── 失败时诊断日志
```

## 📋 **MISE 任务集成**

### **新增任务**
```toml
[tasks.deploy-node-app]
description = "部署 Node.js 应用"
# 完整功能部署

[tasks.deploy-node-standalone]  
description = "快速部署单个 Node.js 应用"
# 快速部署
```

### **使用示例**
```bash
# 完整部署 node-demo 到生产环境
mise run deploy-node-app app_name=node-demo env=aws build=true

# 快速部署到本地环境
mise run deploy-node-standalone app_name=node-demo env=local

# 部署但不重新构建镜像
mise run deploy-node-app app_name=node-demo env=aws build=false
```

## 🎨 **模板功能**

### **零停机部署模板** (`docker-rollout-node.sh.j2`)

支持使用 `docker-rollout` 工具进行零停机部署：

**特性：**
- ✅ 滚动更新
- ✅ 健康检查驱动
- ✅ 自动回滚
- ✅ 环境变量模板化
- ✅ 卷挂载支持

**使用方式：**
```bash
# 生成零停机部署脚本
ansible-playbook ansible/playbooks/deploy-node-app.yml \
  --extra-vars "app=node-demo" \
  --tags template
```

## 🔄 **与现有架构的集成**

### **依赖关系**
```
deploy-node-app.yml
├── 依赖: js-apps/{app_name}/deploy.sh
├── 依赖: js-apps/{app_name}/package.json
├── 依赖: shared_network (自动创建)
└── 使用: docker build 和 docker compose
```

### **环境变量继承**
```bash
# 从现有的 .mise.toml 继承
ENV_MODE=aws|local|production
AWS_REGION=us-west-2
DEPLOY_USER=deploy
NODE_ENV=production
```

## 🎯 **最佳实践**

### **生产部署建议**
1. **先部署基础设施**：
   ```bash
   ansible-playbook ansible/playbooks/deploy-standalone-services.yml
   ```

2. **再部署应用**：
   ```bash
   mise run deploy-node-app app_name=node-demo env=aws build=true
   ```

3. **验证部署**：
   ```bash
   curl http://your-server:3000/health
   ```

### **开发测试建议**
```bash
# 本地快速测试
mise run deploy-node-standalone app_name=node-demo env=local

# 不重新构建的更新
mise run deploy-node-app app_name=node-demo env=local build=false
```

## 📊 **对比现有方式**

| 方式 | 优势 | 适用场景 |
|------|------|----------|
| **deploy.sh** | 简单直接，本地友好 | 开发测试 |
| **Ansible Playbook** | 统一管理，生产级别 | 生产部署 |
| **Docker Compose** | 容器编排，依赖管理 | 完整环境 |
| **MISE 任务** | 命令统一，易于记忆 | 日常操作 |

## 🚀 **现在你可以**

1. **使用统一的 Ansible 方式部署 Node.js 应用**
2. **集成到现有的基础设施部署流程**
3. **享受完整的健康检查和错误诊断**
4. **通过 MISE 任务简化常用操作**

试试看：
```bash
mise run deploy-node-app app_name=node-demo
```

🎉 **Node.js 应用部署现在与基础设施部署保持一致的体验！**
