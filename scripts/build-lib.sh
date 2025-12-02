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
  aws ecr get-login-password --region "$ECR_REGION" |
    docker login --username AWS --password-stdin "$ECR_REGISTRY"
}

# ===== 应用 ECR 生命周期规则 =====
apply_ecr_lifecycle_policy() {
  local repo_name="$1"

  local policy=$(
    cat <<'EOF'
{
  "rules": [
    {
      "rulePriority": 1,
      "description": "删除1天前的未标记镜像",
      "selection": {
        "tagStatus": "untagged",
        "countType": "sinceImagePushed",
        "countUnit": "days",
        "countNumber": 1
      },
      "action": {
        "type": "expire"
      }
    },
    {
      "rulePriority": 2,
      "description": "生产环境：保留最新5个 prod-* 镜像",
      "selection": {
        "tagStatus": "tagged",
        "tagPrefixList": ["prod-"],
        "countType": "imageCountMoreThan",
        "countNumber": 5
      },
      "action": {
        "type": "expire"
      }
    },
    {
      "rulePriority": 3,
      "description": "预览环境：删除3天前的 preview-* 镜像",
      "selection": {
        "tagStatus": "tagged",
        "tagPrefixList": ["preview-"],
        "countType": "sinceImagePushed",
        "countUnit": "days",
        "countNumber": 3
      },
      "action": {
        "type": "expire"
      }
    }
  ]
}
EOF
  )

  if aws ecr put-lifecycle-policy \
    --repository-name "$repo_name" \
    --region "$ECR_REGION" \
    --lifecycle-policy-text "$policy" >/dev/null 2>&1; then
    echo "✅ Lifecycle policy applied"
    return 0
  else
    echo "⚠️  Failed to apply lifecycle policy (non-critical)"
    return 1
  fi
}

# ===== 确保 ECR 仓库存在 =====
ensure_ecr_repo() {
  local repo_name="$1"

  echo "🔍 Checking if ECR repository exists: $repo_name"

  if aws ecr describe-repositories --repository-names "$repo_name" --region "$ECR_REGION" >/dev/null 2>&1; then
    echo "✅ Repository already exists: $repo_name"

    # 检查是否有生命周期规则
    if ! aws ecr get-lifecycle-policy --repository-name "$repo_name" --region "$ECR_REGION" >/dev/null 2>&1; then
      echo "⚙️  Setting up lifecycle policy..."
      apply_ecr_lifecycle_policy "$repo_name"
    fi
  else
    echo "📦 Creating ECR repository: $repo_name"
    aws ecr create-repository \
      --repository-name "$repo_name" \
      --region "$ECR_REGION" \
      --image-scanning-configuration scanOnPush=true \
      --encryption-configuration encryptionType=AES256
    echo "✅ Repository created: $repo_name"

    # 新仓库立即设置生命周期规则
    echo "⚙️  Setting up lifecycle policy..."
    apply_ecr_lifecycle_policy "$repo_name"
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

  # 检测环境（如果还没检测）
  if [ -z "${DEPLOY_ENV:-}" ]; then
    detect_environment
  fi

  # 生成标签
  local tag_latest=$(get_image_tag "latest")
  local tag_versioned=$(get_image_tag "versioned")

  echo "📦 Building: $image_name"
  echo "   Tags: $tag_latest, $tag_versioned"
  docker build \
    --platform linux/amd64 \
    -f "$dockerfile" \
    "$@" \
    -t "$image_name:$tag_latest" \
    -t "$image_name:$tag_versioned" \
    .

  echo "📤 Pushing to ECR..."
  ecr_login

  # 从镜像名称中提取仓库名（去掉 registry 前缀）
  # 例如：912951144733.dkr.ecr.us-west-2.amazonaws.com/studio/hono-demo -> studio/hono-demo
  local repo_name="${image_name#$ECR_REGISTRY/}"
  ensure_ecr_repo "$repo_name"

  docker push "$image_name:$tag_latest"
  docker push "$image_name:$tag_versioned"

  # 导出镜像标签供调用者使用
  export IMAGE_TAG_VERSIONED="$image_name:$tag_versioned"
  export IMAGE_TAG_LATEST="$image_name:$tag_latest"
}

# ===== 环境检测 =====
# 注入基础设施上下文变量 (CTX_*) 供 psenv 模板渲染使用
detect_environment() {
  local current_branch=$(git rev-parse --abbrev-ref HEAD)
  export CURRENT_BRANCH="$current_branch"

  # 清洗分支名，用于生成后缀
  export BRANCH_CLEAN=$(echo "$current_branch" | sed 's/[^a-zA-Z0-9-]/-/g' | tr '[:upper:]' '[:lower:]' | cut -c1-30)
  export DEPLOY_TIMESTAMP=$(date -u +%Y%m%d%H%M%S)

  # 服务名：从当前目录名推断（monorepo 约定）
  export CTX_SERVICE_NAME=$(basename "$PWD")

  if [ "$current_branch" = "main" ]; then
    # === Production Environment ===
    export DEPLOY_ENV="prod"
    export ANSIBLE_TARGET="prod"

    # 生产环境上下文
    # 注意：不需要后缀，域名等配置通常在 AWS Parameter Store 中
    export CTX_DB_SUFFIX=""
    export CTX_DNS_SUFFIX=""
    export CTX_ROOT_DOMAIN="owenyoung.com"

    export CTX_PG_HOST="postgres"
    export CTX_REDIS_HOST="redis"
  else
    # === Preview Environment ===
    export DEPLOY_ENV="preview"
    export ANSIBLE_TARGET="preview"

    # 预览环境上下文
    # 1. 数据库后缀 (下划线风格): _feat_auth
    export CTX_DB_SUFFIX="_${BRANCH_CLEAN//-/_}"

    # 2. 域名后缀 (中划线风格): -feat-auth
    export CTX_DNS_SUFFIX="-${BRANCH_CLEAN}"

    # 3. 基础设施 Host (Docker Service Name)
    export CTX_PG_HOST="postgres"
    export CTX_REDIS_HOST="redis"

    # 4. 根域名
    export CTX_ROOT_DOMAIN="preview.owenyoung.com"
  fi

  echo "🔧 Environment: $DEPLOY_ENV"
  echo "🌳 Branch: $current_branch (clean: $BRANCH_CLEAN)"
  echo "📦 Service: $CTX_SERVICE_NAME"
  if [ "$DEPLOY_ENV" = "preview" ]; then
    echo "📊 Context: DB_SUFFIX=$CTX_DB_SUFFIX, DNS_SUFFIX=$CTX_DNS_SUFFIX"
  fi
}

# ===== 生成镜像标签 =====
get_image_tag() {
  local tag_type=$1 # "latest" or "versioned"

  if [ "$DEPLOY_ENV" = "preview" ]; then
    if [ "$tag_type" = "latest" ]; then
      echo "preview-${BRANCH_CLEAN}"
    else
      echo "preview-${BRANCH_CLEAN}-${DEPLOY_TIMESTAMP}"
    fi
  else
    # 生产环境加 prod- 前缀
    if [ "$tag_type" = "latest" ]; then
      echo "prod-latest"
    else
      echo "prod-${DEPLOY_TIMESTAMP}"
    fi
  fi
}
