# 多阶段构建 Node.js 生产 Dockerfile
# ===============================
# 基础阶段 - 共享的基础配置
# ===============================
FROM node:22-alpine AS base
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
ARG APP=node-demo

# 复制 package 管理文件
COPY package.json package-lock.json* ./
COPY js-apps/${APP}/package.json ./js-apps/${APP}/package.json

# 安装依赖
RUN npm ci --only=production && npm cache clean --force
RUN npm ci && npm cache clean --force

# ===============================
# 构建阶段 - 构建应用
# ===============================
FROM base AS builder
WORKDIR /app
ARG APP=node-demo

# 复制源码和依赖
COPY . .
COPY --from=deps /app/node_modules ./node_modules
COPY --from=deps /app/package-lock.json ./

# 进入应用目录并构建
WORKDIR /app/js-apps/${APP}
COPY --from=deps /app/js-apps/${APP}/node_modules ./node_modules

# 生成 Prisma 客户端并构建
RUN npm run db:generate
RUN npm run build

# ===============================
# 生产依赖阶段
# ===============================
FROM base AS prod-deps
WORKDIR /app
ARG APP=node-demo

ENV NODE_ENV=production

# 复制 package 文件
COPY js-apps/${APP}/package.json ./package.json
COPY js-apps/${APP}/package-lock.json* ./

# 安装生产依赖
RUN npm ci --only=production && npm cache clean --force

# ===============================
# 生产阶段
# ===============================
FROM base AS app
WORKDIR /app
ARG APP=node-demo

ENV NODE_ENV=production
ENV PORT=3000

# 复制生产依赖
COPY --from=prod-deps --chown=appuser:appuser /app/node_modules ./node_modules

# 复制构建产物
COPY --from=builder --chown=appuser:appuser /app/js-apps/${APP}/dist ./dist
COPY --from=builder --chown=appuser:appuser /app/js-apps/${APP}/package.json ./package.json

# 复制 Prisma schema（运行时需要）
COPY --from=builder --chown=appuser:appuser /app/js-apps/${APP}/prisma ./prisma

USER appuser
EXPOSE 3000

HEALTHCHECK --interval=30s --timeout=10s --start-period=30s --retries=3 \
    CMD curl -f http://localhost:${PORT:-3000}/health 2>/dev/null || exit 1

ENTRYPOINT ["dumb-init", "--"]
CMD ["node", "./dist/server.js"]
