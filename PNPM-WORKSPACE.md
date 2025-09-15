# PNPM Workspace 配置指南

## 🚀 项目已配置为 PNPM Monorepo

### 📁 配置文件

#### `pnpm-workspace.yaml`
```yaml
packages:
  # JavaScript applications
  - 'js-apps/*'
  # JavaScript packages/libraries  
  - 'js-packages/*'
```

#### 根目录 `package.json`
```json
{
  "name": "studio",
  "private": true,
  "packageManager": "pnpm@9.0.0",
  "scripts": {
    "dev": "pnpm --filter",
    "build": "pnpm --recursive build",
    "install:all": "pnpm install"
  }
}
```

## 🎯 MISE 命令

### 开发命令
```bash
# 使用 PNPM Workspace 启动应用
mise run pnpmdev app_name=node-demo
mise run pnpmdev app_name=bun-demo

# 传统方式（兼容）
mise run nodedev app_name=node-demo  # 也使用 pnpm
mise run dev app_name=bun-demo       # 使用 bun
```

### 构建命令
```bash
# PNPM Workspace 构建
mise run pnpmbuild app_name=node-demo

# 传统方式
mise run build app_name=bun-demo
```

### Docker 构建
```bash
# Node.js + PNPM Docker 构建
mise run builddocker app_name=node-demo

# Bun Docker 构建  
mise run builddocker app_name=bun-demo
```

### 依赖管理
```bash
# 安装所有 workspace 依赖
mise run pnpminstall

# 或直接使用 pnpm
pnpm install
```

## 📦 PNPM Workspace 命令

### 基础命令
```bash
# 安装所有依赖
pnpm install

# 安装特定 workspace 的依赖
pnpm --filter node-demo install
pnpm --filter bun-demo install

# 运行特定 workspace 的脚本
pnpm --filter node-demo dev
pnpm --filter node-demo build

# 在所有 workspace 中运行脚本
pnpm --recursive dev
pnpm --recursive build
```

### 添加依赖
```bash
# 给根目录添加依赖
pnpm add -w typescript

# 给特定 workspace 添加依赖
pnpm --filter node-demo add fastify
pnpm --filter node-demo add -D @types/node

# 添加 workspace 内部依赖
pnpm --filter node-demo add js-packages/shared
```

## 🔄 迁移优势

### 与 npm workspaces 相比
- ✅ **更快的安装速度** - 更高效的依赖解析
- ✅ **更好的磁盘利用** - 全局依赖共享
- ✅ **严格模式** - 防止幽灵依赖
- ✅ **更好的 monorepo 支持** - 专为 monorepo 设计

### 项目结构
```
studio/
├── pnpm-workspace.yaml     # Workspace 配置
├── package.json             # 根项目配置
├── pnpm-lock.yaml          # 锁文件（自动生成）
├── js-apps/
│   ├── node-demo/          # Node.js 应用
│   └── bun-demo/           # Bun 应用
└── js-packages/            # 共享包
```

## 🐳 Docker 支持

### Node.js + PNPM Dockerfile
- 新增：`js-apps/node-demo/Dockerfile.pnpm`
- 使用 PNPM 进行多阶段构建
- 支持 workspace 依赖管理

## 🎨 使用建议

### 开发工作流
1. **启动基础设施**：`mise service`
2. **安装依赖**：`pnpm install`
3. **启动应用**：`mise run pnpmdev app_name=node-demo`

### 新增应用
1. 在 `js-apps/` 下创建新目录
2. 添加 `package.json`
3. PNPM 会自动识别为 workspace 项目

### 共享代码
1. 在 `js-packages/` 创建共享包
2. 使用 `pnpm --filter <app> add js-packages/<package>` 添加依赖
3. 支持热重载和类型检查

## ⚡ 性能优势

- **安装速度**：比 npm 快 2-3 倍
- **磁盘空间**：节省 30-50% 磁盘空间
- **网络请求**：减少重复下载
- **构建速度**：更好的缓存机制
