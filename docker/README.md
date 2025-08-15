# Studio Docker 构建指南

本项目提供了灵活的 Docker 构建方案，支持单个应用构建和批量构建。

## 🚀 快速开始

### 构建单个应用

```bash
# 构建默认应用 (bun-hello)
./docker/build.sh

# 构建指定应用
./docker/build.sh bun-hello
./docker/build.sh bun-demo2

# 使用自定义标签前缀
./docker/build.sh bun-hello myapp
```

### 批量构建所有应用

```bash
# 使用默认标签前缀 (studio)
./docker/build-all.sh

# 使用自定义标签前缀
./docker/build-all.sh myapp
```

### 直接使用 Docker 命令

```bash
# 构建单个应用
docker build --target app -t studio-app --build-arg APP=bun-hello -f docker/bun/Dockerfile .

# 构建所有应用
docker build --target all -t studio-all -f docker/bun/Dockerfile .
```

## 📦 运行应用

```bash
# 运行 bun-hello 应用
docker run -p 3000:3000 studio-bun-hello

# 运行 bun-demo2 应用
docker run -p 3001:3000 studio-bun-demo2

# 后台运行
docker run -d -p 3000:3000 --name studio-hello studio-bun-hello
```

## 🔧 构建配置

### 环境变量

- `NODE_ENV`: 生产环境 (production)
- `PORT`: 应用端口 (默认: 3000)

### 构建参数

- `APP`: 要构建的应用名称 (默认: bun-hello)

### 健康检查

应用包含健康检查功能，使用简单的curl命令：
```bash
curl -f http://localhost:${PORT:-3000}/health 2>/dev/null || exit 1
```

确保你的应用提供 `/health` 端点。

## 📁 项目结构

```
studio/
├── apps/
│   ├── bun-hello/     # React 应用
│   └── bun-demo2/     # 后端应用
├── js-packages/       # 共享包
├── docker/
│   ├── bun/
│   │   └── Dockerfile # 多阶段构建文件
│   ├── build.sh       # 单个应用构建脚本
│   ├── build-all.sh   # 批量构建脚本
│   └── README.md      # 本文档
└── package.json       # 工作区配置
```

## 🎯 构建阶段

1. **base**: 基础环境配置
2. **deps**: 安装所有依赖
3. **builder**: 构建指定应用
4. **prod-deps**: 安装生产依赖
5. **app**: 通用应用运行环境
6. **all**: 一键构建所有应用

## 🔍 故障排除

### 常见问题

1. **应用目录不存在**
   ```bash
   # 检查可用应用
   ls apps/
   ```

2. **构建失败**
   ```bash
   # 查看详细日志
   docker build --target app --build-arg APP=bun-hello -f docker/bun/Dockerfile . --progress=plain
   ```

3. **端口冲突**
   ```bash
   # 使用不同端口
   docker run -p 3001:3000 studio-bun-hello
   ```

### 调试模式

```bash
# 进入容器调试
docker run -it --rm studio-bun-hello /bin/sh
```

## 📝 注意事项

- 确保应用目录下有 `package.json` 文件
- 应用需要支持 `bun run build` 和 `bun run start` 命令
- 健康检查端点需要正确配置
- 建议在生产环境中使用 `--no-cache` 参数重新构建
