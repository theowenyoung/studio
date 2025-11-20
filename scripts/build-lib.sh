#!/usr/bin/env bash
set -euo pipefail

export ECR_REGISTRY="912951144733.dkr.ecr.us-west-2.amazonaws.com"
export ECR_REGION="us-west-2"
export DEPLOY_DIST="deploy-dist"

# ===== 生成统一版本号（YYYYMMDDHHmmss）=====
get_version() {
  date +%Y%m%d%H%M%S
}

# ===== ECR 登录 =====
ecr_login() {
  echo "🔐 Logging into ECR..."
  aws ecr get-login-password --region "$ECR_REGION" | \
    docker login --username AWS --password-stdin "$ECR_REGISTRY"
}

# ===== 构建并推送 Docker 镜像 =====
build_and_push_image() {
  local image_name="$1"
  local version="$2"
  local dockerfile="$3"
  shift 3
  local build_args="$@"

  local repo_root
  repo_root="$(git rev-parse --show-toplevel)"

  cd "$repo_root"

  echo "📦 Building: $image_name:$version"
  docker build \
    -f "$dockerfile" \
    $build_args \
    -t "$image_name:latest" \
    -t "$image_name:$version" \
    .

  echo "📤 Pushing to ECR..."
  ecr_login
  docker push "$image_name:latest"
  docker push "$image_name:$version"
}

# ===== 从 AWS Parameter Store 获取环境变量 =====
fetch_env() {
  local template="$1"
  local param_path="$2"
  local output="$3"

  if command -v psenv &> /dev/null; then
    psenv -t "$template" -p "$param_path" -o "$output"
  else
    echo "⚠️  psenv not found, copying template"
    cp "$template" "$output"
  fi
}
