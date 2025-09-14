# 多阶段构建 Bun 生产 Dockerfile - 简化架构修复版本
# ===============================
# 基础阶段 - 共享的基础配置
# ===============================
FROM oven/bun:1-alpine AS base
WORKDIR /app
# 安装系统依赖
RUN apk add --no-cache \
   curl \
   dumb-init \
   ca-certificates
# 创建非 root 用户
RUN addgroup -g 1001 -S appuser && \
   adduser -S appuser -u 1001 -G appuser

# ===============================
# 依赖安装阶段 - 安装所有依赖
# ===============================
FROM base AS deps
WORKDIR /app
ARG APP=bun-hello
# 🔧 关键修复：设置环境变量避免架构冲突
ENV BUN_INSTALL_GLOBAL_DIR=/usr/local/bun
ENV BUN_RUNTIME_TRANSPILER_CACHE_PATH=/tmp/bun-cache
# 复制包管理文件
COPY package.json bun.lock* ./
# 创建目录结构并复制所有源码
COPY js-apps/${APP} ./js-apps/${APP}/
COPY js-packages/ ./js-packages/
# 🔧 关键修复：使用更兼容的安装方式
RUN bun install

# ===============================
# 构建阶段 - 构建指定应用
# ===============================
FROM base AS builder
WORKDIR /app
ARG APP=bun-hello
# 复制源码
COPY . .
# 复制依赖
COPY --from=deps /app/node_modules ./node_modules
COPY --from=deps /app/bun.lock* ./
# 构建指定应用
RUN bun run --filter ${APP} build
# 打印当前目录
RUN ls -a ./js-apps/${APP}

# ===============================
# 生产依赖阶段 - 只安装生产依赖
# ===============================
FROM base AS prod-deps
WORKDIR /app
ARG APP=bun-hello

# 设置生产环境
ENV NODE_ENV=production

# 复制根级别的包管理文件
COPY package.json ./
COPY --from=deps /app/bun.lock* ./


# 🔧 先复制整个目录，然后只保留 package.json
COPY js-apps/${APP}/package.json ./js-apps/${APP}/package.json
# COPY js-apps/ ./js-apps/
# RUN find ./js-apps -type f ! -name "package.json" -delete && \
#     find ./js-apps -type d -empty -delete 2>/dev/null || true


COPY js-packages/ ./js-packages/


# 复制构建产物
COPY --from=builder --chown=appuser:appuser /app/js-apps/${APP}/dist ./js-apps/${APP}/dist

# 🔧 关键修复：现在可以安全使用 frozen-lockfile，因为目录结构一致
RUN bun install --production --frozen-lockfile

# ===============================
# 通用应用阶段 - 适用于所有应用
# ===============================
FROM base AS app
WORKDIR /app
ARG APP=bun-hello
ENV NODE_ENV=production
ENV PORT=3000

# 复制生产依赖
COPY --from=prod-deps --chown=appuser:appuser /app/node_modules ./node_modules

# 复制构建产物（包括服务器文件）
COPY --from=builder --chown=appuser:appuser /app/js-apps/${APP}/dist ./dist

# 复制共享包
COPY --from=prod-deps --chown=appuser:appuser /app/js-packages ./js-packages

# 复制运行时必需的文件
COPY --from=builder --chown=appuser:appuser /app/js-apps/${APP}/package.json ./package.json

USER appuser
EXPOSE 3000

HEALTHCHECK --interval=30s --timeout=10s --start-period=30s --retries=3 \
   CMD curl -f http://localhost:${PORT:-3000}/health 2>/dev/null || exit 1

ENTRYPOINT ["dumb-init", "--"]
CMD ["bun", "./dist/index.js"]


# ===============================
# 使用示例
# ===============================
# 🚀 推荐构建命令（指定架构）:
# docker build --platform linux/amd64 --target app --build-arg APP=bun-hello -t studio-app .
# 🧪 测试构建（仅依赖阶段）:
# docker build --platform linux/amd64 --target deps --build-arg APP=bun-hello -t test-deps .
# 🔍 调试构建（查看详细信息）:
# docker build --platform linux/amd64 --target deps --build-arg APP=bun-hello -t debug-deps . --progress=plain
