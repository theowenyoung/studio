#!/usr/bin/env bash
set -euo pipefail

export ECR_REGISTRY="912951144733.dkr.ecr.us-west-2.amazonaws.com"
export ECR_REGION="us-west-2"
export DEPLOY_DIST="deploy-dist"

# ===== 生成统一版本号（YYYYMMDDHHmmss）=====
# 使用 UTC 时区避免不同机器时区差异
get_version() {
  date -u +%Y%m%d%H%M%S
}

# ===== ECR 登录 =====
ecr_login() {
  echo "🔐 Logging into ECR..."
  aws ecr get-login-password --region "$ECR_REGION" | \
    docker login --username AWS --password-stdin "$ECR_REGISTRY"
}

# ===== 确保 ECR 仓库存在 =====
ensure_ecr_repo() {
  local repo_name="$1"

  echo "🔍 Checking if ECR repository exists: $repo_name"

  if aws ecr describe-repositories --repository-names "$repo_name" --region "$ECR_REGION" >/dev/null 2>&1; then
    echo "✅ Repository already exists: $repo_name"
  else
    echo "📦 Creating ECR repository: $repo_name"
    aws ecr create-repository \
      --repository-name "$repo_name" \
      --region "$ECR_REGION" \
      --image-scanning-configuration scanOnPush=true \
      --encryption-configuration encryptionType=AES256
    echo "✅ Repository created: $repo_name"
  fi
}

# ===== 构建并推送 Docker 镜像 =====
build_and_push_image() {
  local image_name="$1"
  local version="$2"
  local dockerfile="$3"
  shift 3
  # 剩余参数 "$@" 是 build args

  local repo_root
  repo_root="$(git rev-parse --show-toplevel)"

  cd "$repo_root"

  echo "📦 Building: $image_name:$version"
  docker build \
    --platform linux/amd64 \
    -f "$dockerfile" \
    "$@" \
    -t "$image_name:latest" \
    -t "$image_name:$version" \
    .

  echo "📤 Pushing to ECR..."
  ecr_login

  # 从镜像名称中提取仓库名（去掉 registry 前缀）
  # 例如：912951144733.dkr.ecr.us-west-2.amazonaws.com/studio/hono-demo -> studio/hono-demo
  local repo_name="${image_name#$ECR_REGISTRY/}"
  ensure_ecr_repo "$repo_name"

  docker push "$image_name:latest"
  docker push "$image_name:$version"
}
