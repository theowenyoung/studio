# 多阶段构建 Node.js 生产 Dockerfile - PNPM 版本
# ===============================
# 基础阶段 - 共享的基础配置
# ===============================
FROM node:22-alpine AS base
WORKDIR /app

# 安装系统依赖和 pnpm
RUN apk add --no-cache \
    curl \
    dumb-init \
    ca-certificates \
    openssl \
    openssl-dev && \
    npm install -g pnpm@9.0.0

# 创建非 root 用户
RUN addgroup -g 1001 -S appuser && \
    adduser -S appuser -u 1001 -G appuser

# ===============================
# 依赖安装阶段 - 安装所有依赖
# ===============================
FROM base AS deps
WORKDIR /app

# 复制包管理文件
COPY package.json pnpm-lock.yaml* ./
COPY prisma ./prisma/

# 安装依赖 (重试机制)
RUN for i in 1 2 3; do pnpm install && break || sleep 10; done

# ===============================
# 构建阶段 - 构建应用
# ===============================
FROM base AS builder
WORKDIR /app

# 复制源码和依赖
COPY . .
COPY --from=deps /app/node_modules ./node_modules

# 构建应用
RUN pnpm run build

# ===============================
# 生产依赖阶段
# ===============================
FROM base AS prod-deps
WORKDIR /app

ENV NODE_ENV=production

# 复制包管理文件
COPY package.json pnpm-lock.yaml* ./
COPY prisma ./prisma/

# 安装生产依赖
RUN pnpm install --prod

# ===============================
# 生产阶段
# ===============================
FROM base AS app
WORKDIR /app

ENV NODE_ENV=production
ENV PORT=3000

# 复制生产依赖（包含 Prisma 生成的客户端）
COPY --from=builder --chown=appuser:appuser /app/node_modules ./node_modules

# 复制构建产物
COPY --from=builder --chown=appuser:appuser /app/dist ./dist
COPY --from=builder --chown=appuser:appuser /app/package.json ./package.json

# 复制 Prisma schema（运行时需要）
COPY --from=builder --chown=appuser:appuser /app/prisma ./prisma

USER appuser
EXPOSE 3000

HEALTHCHECK --interval=30s --timeout=10s --start-period=30s --retries=3 \
    CMD curl -f http://localhost:${PORT:-3000}/health 2>/dev/null || exit 1

ENTRYPOINT ["dumb-init", "--"]
CMD ["node", "./dist/server.js"]