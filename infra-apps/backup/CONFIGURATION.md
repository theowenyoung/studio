# 配置说明

## 配置文件结构

```
backup/
├── .env                      # 敏感信息（不提交到 Git）
├── .env.example             # 敏感信息模板
├── docker-compose.yml       # 开发环境配置 + 非敏感设置
└── docker-compose.prod.yml  # 生产环境配置 + 非敏感设置
```

## 配置原理

### 1. 敏感信息（.env）

仅包含密码、密钥等敏感信息，通过 `env_file` 自动加载：

```bash
# .env
# PostgreSQL: 不需要指定数据库名，pg_dumpall 会备份所有数据库
POSTGRES_ADMIN_URL=postgresql://user:password@host:5432

REDIS_DOCKER_URL=redis://:password@host:6379
AWS_ACCESS_KEY_ID=xxx
AWS_SECRET_ACCESS_KEY=xxx
S3_BUCKET=my-bucket
S3_ENDPOINT=https://s3.example.com
```

### 2. 非敏感配置（docker-compose.yml）

直接在 `environment` 块中定义，无需放在 .env：

```yaml
services:
  backup:
    env_file:
      - .env  # 自动加载敏感信息
    environment:
      # 这里只定义非敏感配置
      S3_REGION: us-east-1
      BACKUP_RETENTION_LOCAL: 3
      BACKUP_RETENTION_S3: 30
      POSTGRES_SCHEDULE: "0 2 * * *"
      REDIS_SCHEDULE: "0 3 * * *"
      TZ: UTC
```

### 3. 为什么不重复声明？

❌ **错误做法**（冗余）：
```yaml
services:
  backup:
    env_file:
      - .env
    environment:
      POSTGRES_ADMIN_URL: ${POSTGRES_ADMIN_URL}  # ❌ 多余！.env 已经定义了
      REDIS_DOCKER_URL: ${REDIS_DOCKER_URL}        # ❌ 多余！
      S3_REGION: us-east-1           # ✅ 这个可以
```

✅ **正确做法**（简洁）：
```yaml
services:
  backup:
    env_file:
      - .env  # POSTGRES_ADMIN_URL, REDIS_DOCKER_URL 等会自动加载
    environment:
      # 只定义 .env 中没有的非敏感配置
      S3_REGION: us-east-1
      BACKUP_RETENTION_LOCAL: 3
```

## 配置清单

| 变量名 | 类型 | 位置 | 说明 |
|--------|------|------|------|
| `POSTGRES_ADMIN_URL` | 敏感 | .env | 数据库连接 URL |
| `REDIS_DOCKER_URL` | 敏感 | .env | Redis 连接 URL |
| `AWS_ACCESS_KEY_ID` | 敏感 | .env | S3 访问密钥 |
| `AWS_SECRET_ACCESS_KEY` | 敏感 | .env | S3 密钥 |
| `S3_BUCKET` | 敏感 | .env | S3 桶名称 |
| `S3_ENDPOINT` | 半敏感 | .env | S3 端点（可选）|
| `S3_REGION` | 非敏感 | compose | S3 区域 |
| `BACKUP_RETENTION_LOCAL` | 非敏感 | compose | 本地保留天数 |
| `BACKUP_RETENTION_S3` | 非敏感 | compose | S3 保留天数 |
| `POSTGRES_SCHEDULE` | 非敏感 | compose | Cron 调度 |
| `REDIS_SCHEDULE` | 非敏感 | compose | Cron 调度 |
| `CLEANUP_SCHEDULE` | 非敏感 | compose | Cron 调度 |
| `FULL_BACKUP_SCHEDULE` | 非敏感 | compose | Cron 调度 |
| `TZ` | 非敏感 | compose | 时区 |

## 修改配置的方法

### 修改敏感信息（数据库密码、S3 密钥）

```bash
# 编辑 .env 文件
vim .env

# 重启服务使配置生效
docker compose restart backup
```

### 修改非敏感配置（备份策略、调度时间）

```bash
# 直接编辑 docker-compose.yml
vim docker-compose.yml

# 重新创建服务（up -d 会重新读取配置）
docker compose up -d
```

## 环境差异

### 开发环境 (docker-compose.yml)

```yaml
environment:
  BACKUP_RETENTION_LOCAL: 3   # 保留3天
  BACKUP_RETENTION_S3: 30     # 保留30天
volumes:
  - ./.local/backups:/backups  # 本地目录
```

### 生产环境 (docker-compose.prod.yml)

```yaml
environment:
  BACKUP_RETENTION_LOCAL: 7   # 保留7天
  BACKUP_RETENTION_S3: 90     # 保留90天
volumes:
  - /data/backups:/backups    # 服务器目录
```

## 最佳实践

1. ✅ **敏感信息永远不提交到 Git**
   ```bash
   echo ".env" >> .gitignore
   ```

2. ✅ **提供 .env.example 作为模板**
   ```bash
   cp .env.example .env
   # 然后编辑 .env 填入真实值
   ```

3. ✅ **非敏感配置直接写在 compose 文件中**
   - 便于版本控制
   - 团队成员可以看到默认配置
   - 减少配置文件数量

4. ✅ **不同环境使用不同的 compose 文件**
   ```bash
   # 开发
   docker compose up -d
   
   # 生产
   docker compose -f docker-compose.prod.yml up -d
   ```
