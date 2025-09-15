# Node.js + Fastify + React Demo

一个现代化的全栈 Node.js 应用，使用 Fastify、React、TypeScript 和 PostgreSQL。

## 🚀 技术栈

### 后端
- **Fastify** - 高性能 Web 框架
- **TypeScript** - 类型安全
- **Prisma** - 现代数据库 ORM
- **PostgreSQL** - 数据库

### 前端  
- **React 19** - UI 框架
- **Vite** - 快速构建工具
- **TypeScript** - 类型安全

## 📦 安装依赖

```bash
npm install
```

## 🛠️ 开发

### 本地开发（需要数据库）

1. 确保 PostgreSQL 数据库运行：
```bash
# 在项目根目录启动基础设施
mise service
```

2. 配置环境变量：
```bash
cp .env.example .env
# 编辑 .env 配置数据库连接
```

3. 生成 Prisma 客户端并推送数据库结构：
```bash
npm run db:generate
npm run db:push
```

4. 启动开发服务器：
```bash
npm run dev
```

这将启动：
- 后端服务器：http://localhost:3000
- 前端开发服务器：http://localhost:5173

### Docker 开发

```bash
# 构建镜像
mise run builddocker app_name=node-demo

# 启动服务
./deploy.sh up

# 查看日志
./deploy.sh logs

# 停止服务
./deploy.sh down
```

## 🌐 API 端点

- `GET /health` - 健康检查
- `GET /api/records` - 获取所有记录
- `POST /api/records` - 创建新记录

## 📝 数据库操作

```bash
# 生成 Prisma 客户端
npm run db:generate

# 推送数据库结构变更
npm run db:push

# 创建迁移文件
npm run db:migrate

# 打开数据库管理界面
npm run db:studio
```

## 🚢 部署

### 本地部署
```bash
ENV_MODE=local ./deploy.sh up
```

### 生产部署
```bash
ENV_MODE=prod ./deploy.sh up
```

## 🔧 开发工具

```bash
# 类型检查
npm run typecheck

# 构建
npm run build

# 启动生产服务器
npm start
```

## 🎯 与 Bun 版本的对比

| 特性 | Bun 版本 | Node.js 版本 |
|------|----------|--------------|
| 启动速度 | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐ |
| 生态系统 | ⭐⭐⭐ | ⭐⭐⭐⭐⭐ |
| 类型安全 | ⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ |
| 开发体验 | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐ |
| 生产稳定 | ⭐⭐⭐ | ⭐⭐⭐⭐⭐ |
| 性能 | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐ |
| 调试工具 | ⭐⭐⭐ | ⭐⭐⭐⭐⭐ |

## 🎨 特性

- ✅ 热重载开发
- ✅ TypeScript 全栈类型安全
- ✅ 自动 API 验证和序列化
- ✅ 数据库类型安全 ORM
- ✅ Docker 容器化
- ✅ 健康检查
- ✅ 结构化日志
- ✅ 优雅关闭
- ✅ 零停机部署支持
