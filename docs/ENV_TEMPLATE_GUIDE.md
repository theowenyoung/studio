# 环境变量模板渲染指南

## 概述

本项目采用 **两阶段配置管理** 来解决多环境（Dev/Preview/Prod）下复杂变量生成的问题。

**核心理念：**
- **工具层 (`psenv`)**: 从 AWS Fetcher 升级为 **模版渲染引擎**，支持 `${VAR:-default}` 语法
- **脚本层 (`build-lib.sh`)**: 注入标准的 **基础设施上下文 (CTX_* 变量)**，而非拼接业务字符串
- **配置层 (`.env.example`)**: 作为唯一的真理来源，区分 **源变量** 和 **计算变量**

## 工作原理

### Phase 1: 解析源变量 (Raw Variables)

源变量是不包含模板语法（`${}`）的变量。psenv 按以下优先级获取值：

```
1. Shell 环境变量
2. AWS Parameter Store
3. .env.example 中的字面默认值
```

**示例：**
```bash
# .env.example
POSTGRES_USER=           # 留空 = 必须从 AWS 获取
POSTGRES_PORT=5432       # 有默认值 = 可选（AWS 可覆盖）
```

### Phase 2: 渲染计算变量 (Computed Variables)

计算变量包含模板语法，通过引用源变量或其他计算变量来组合生成。

**支持的语法：**
- `${VAR}` - 严格模式，变量必须存在，否则报错
- `${VAR:-default}` - 默认值模式，变量不存在时使用默认值
- `${VAR:-}` - 允许为空，变量不存在时使用空字符串

**多轮迭代渲染：**

psenv 使用智能迭代算法处理变量依赖关系：

1. **顺序无关**：变量定义顺序不影响渲染结果
   ```bash
   # 这两种写法完全等价
   DATABASE_URL=postgresql://${DB_HOST}/${POSTGRES_DB}  # 前面引用后面
   DB_HOST=${CTX_PG_HOST:-localhost}                     # 被引用的在后面
   ```

2. **支持嵌套**：计算变量可以引用其他计算变量
   ```bash
   DB_HOST=${CTX_PG_HOST:-localhost}                     # 第 1 层
   POSTGRES_DB=${POSTGRES_DB_NAME}${CTX_DB_SUFFIX:-}   # 第 1 层
   DATABASE_URL=postgresql://${USER}@${DB_HOST}/${POSTGRES_DB}  # 第 2 层（引用第 1 层）
   ```

3. **自动依赖解析**：每轮尝试渲染所有未完成的变量，直到全部解析完成
   - 最多 10 轮迭代（支持最深 10 层依赖链）
   - 实际使用通常只需 2-3 轮
   - 检测循环依赖并报错

**示例：多轮渲染过程**
```bash
# 配置文件
POSTGRES_DB=${POSTGRES_DB_NAME}${CTX_DB_SUFFIX:-}         # 只依赖原始变量
DB_HOST=${CTX_PG_HOST:-localhost}                          # 只依赖上下文变量
DATABASE_URL=postgresql://${POSTGRES_USER}@${DB_HOST}/${POSTGRES_DB}  # 依赖上面两个

# 渲染过程
# Iteration 1: 渲染 POSTGRES_DB 和 DB_HOST（依赖已满足）
# Iteration 2: 渲染 DATABASE_URL（依赖在第 1 轮解析完成）
# 结果：2 轮完成所有渲染
```

## 基础设施上下文 (CTX_* 变量)

`build-lib.sh` 会根据当前分支和环境自动注入以下上下文变量：

### Preview 环境
```bash
CTX_DB_SUFFIX="_feat_test"           # 数据库名后缀（下划线风格）
CTX_DNS_SUFFIX="-feat-test"          # 域名后缀（中划线风格）
CTX_PG_HOST="postgres"               # PostgreSQL 主机（Docker service）
CTX_REDIS_HOST="redis"               # Redis 主机（Docker service）
CTX_ROOT_DOMAIN="preview.owenyoung.com"
```

### Production 环境
```bash
CTX_DB_SUFFIX=""                     # 无后缀
CTX_DNS_SUFFIX=""                    # 无后缀
CTX_ROOT_DOMAIN="owenyoung.com"
# CTX_PG_HOST 不设置，从 AWS 获取或使用模板默认值
```

### Local 开发环境
不设置任何 CTX_* 变量，所有计算变量使用默认值（通常是 localhost）。

## 配置文件编写规范

### 文件结构

```bash
# ==============================================
# 1. 源变量 (Raw Sources)
# 约定：留空 = 必须从 AWS Parameter Store 拉取
# ==============================================

# 数据库基础名称 (AWS 存: "hono_demo")
POSTGRES_DB_NAME=

# 数据库凭证 (AWS 存)
POSTGRES_USER=
POSTGRES_PASSWORD=

# 数据库端口 (固定默认值)
POSTGRES_PORT=5432

# ==============================================
# 2. 计算变量 (Computed Logic)
# 约定：使用 ${} 语法进行模板渲染
# ==============================================

# Host 配置
DB_HOST=${CTX_PG_HOST:-localhost}

# 数据库名（带分支后缀）
POSTGRES_DB=${POSTGRES_DB_NAME}${CTX_DB_SUFFIX:-}

# 连接字符串
DATABASE_URL=postgresql://${POSTGRES_USER}:${POSTGRES_PASSWORD}@${DB_HOST}:${POSTGRES_PORT}/${POSTGRES_DB}
```

### 最佳实践

1. **源变量在前，计算变量在后**
   - 便于理解哪些值来自外部，哪些是本地组合

2. **为可选源变量提供合理的默认值**
   - 例如 `POSTGRES_PORT=5432` - 大多数情况下不会改变
   - 例如 `APP_SUBDOMAIN=hono-demo` - 提供默认值，AWS 可选覆盖

3. **必需的源变量留空**
   - 例如 `POSTGRES_PASSWORD=` - 强制从 AWS 获取，避免硬编码敏感信息

4. **使用 `:-` 提供默认值**
   - `${CTX_PG_HOST:-localhost}` - 本地开发时自动使用 localhost
   - `${CTX_DB_SUFFIX:-}` - 允许为空，prod 环境无后缀

5. **合理控制依赖层级**
   - ✅ 支持计算变量引用其他计算变量（多轮渲染自动处理）
   - ✅ 定义顺序不影响结果，按逻辑分组即可
   - ⚠️ 建议不超过 2-3 层依赖，保持配置易于理解
   - 示例：
     ```bash
     # ✅ 推荐：清晰的依赖链
     DB_HOST=${CTX_PG_HOST:-localhost}           # 第 1 层
     POSTGRES_DB=${POSTGRES_DB_NAME}${CTX_DB_SUFFIX:-}  # 第 1 层
     DATABASE_URL=postgresql://${USER}@${DB_HOST}/${POSTGRES_DB}  # 第 2 层

     # ⚠️ 避免：过深的依赖链
     A=${B}  # 第 1 层
     B=${C}  # 第 2 层
     C=${D}  # 第 3 层
     D=${E}  # 第 4 层
     E=${F}  # 第 5 层 - 太深了！
     ```

## 使用示例

### 本地开发

```bash
# 设置必需的源变量
export POSTGRES_USER="app_user"
export POSTGRES_PASSWORD="dev"
export POSTGRES_DB_NAME="hono_demo"

# 运行 psenv（不设置 CTX_* 变量）
mise run dev-env-hono

# 生成的 .env
# DATABASE_URL=postgresql://app_user:dev@localhost:5432/hono_demo
# APP_URL=https://hono-demo.studio.localhost
```

### Preview 环境

```bash
# build-lib.sh 自动检测分支并注入 CTX_* 变量
cd js-apps/hono-demo
../../scripts/build-lib.sh detect_environment

# 运行 psenv（从 AWS 获取凭证）
psenv -t .env.example -p /studio-dev/ -o .env

# 生成的 .env
# DATABASE_URL=postgresql://app_user:aws_password@postgres:5432/hono_demo_feat_test
# APP_URL=https://hono-demo-feat-test.preview.owenyoung.com
```

### 生产环境

```bash
# build-lib.sh 检测 main 分支
export DEPLOY_ENV=prod

# 运行 psenv
psenv -t .env.example -p /studio-prod/ -o .env

# 生成的 .env
# DATABASE_URL=postgresql://prod_user:prod_password@prod-db.internal:5432/hono_demo
# APP_URL=https://hono-demo.owenyoung.com
```

## 调试技巧

### 1. Dry-run 模式

查看渲染结果而不写入文件：

```bash
psenv -t .env.example -p /studio-dev/ --dry-run --show-secrets
```

### 2. 详细日志

查看每个变量的解析过程：

```bash
psenv -t .env.example -p /studio-dev/ -o .env --verbose
```

输出示例：
```
[INFO] Phase 1: Resolving raw variables...
[DEBUG] Processing raw variable: POSTGRES_USER
[DEBUG]   ✓ Found in AWS Parameter Store
[INFO] Phase 1 complete: 7 raw variables resolved
[INFO] Phase 2: Rendering computed variables...
[DEBUG] Render iteration 1: 6 variables remaining
[DEBUG]   ✓ DB_HOST = postgres
[DEBUG]   ✓ POSTGRES_DB = hono_demo_feat_test
[DEBUG] Render iteration 2: 2 variables remaining
[DEBUG]   ✓ DATABASE_URL = postgresql://app_user:***@postgres:5432/hono_demo_feat_test
```

### 3. 检查 CTX_* 变量

在脚本中打印上下文：

```bash
source scripts/build-lib.sh
detect_environment
env | grep CTX_
```

## 常见问题

### Q: 为什么我的变量没有被渲染？

**A:** 检查几点：
1. 变量是否在 .env.example 中定义？
2. 引用的变量是否存在于上下文中？（使用 `--verbose` 查看）
3. 是否有循环依赖？（A 引用 B，B 引用 A）
4. 依赖链是否超过 10 层？

### Q: 变量定义的顺序重要吗？

**A:** **不重要**。psenv 使用多轮迭代算法，自动解析依赖关系。

示例：
```bash
# 这两种写法完全等价
# 方式 1: 按依赖顺序写
DB_HOST=${CTX_PG_HOST:-localhost}
DATABASE_URL=postgresql://${USER}@${DB_HOST}/mydb

# 方式 2: 反过来也可以
DATABASE_URL=postgresql://${USER}@${DB_HOST}/mydb
DB_HOST=${CTX_PG_HOST:-localhost}
```

建议按逻辑分组（源变量、计算变量）而不是按依赖顺序排列，更易于维护。

### Q: 计算变量可以引用其他计算变量吗？

**A:** **可以**。psenv 支持多层依赖（最多 10 层）。

示例：
```bash
# 第 1 层：基础计算
DB_HOST=${CTX_PG_HOST:-localhost}
POSTGRES_DB=${POSTGRES_DB_NAME}${CTX_DB_SUFFIX:-}

# 第 2 层：组合第 1 层的结果
DATABASE_URL=postgresql://${POSTGRES_USER}@${DB_HOST}/${POSTGRES_DB}
```

实际使用中通常只需 2-3 层。超过 10 层会报错（可能存在循环依赖）。

### Q: 如何在 AWS 中配置变量？

**A:** 使用 AWS Parameter Store，路径格式：
- 开发环境: `/studio-dev/{KEY_NAME}`
- 生产环境: `/studio-prod/{KEY_NAME}`

例如：
```bash
aws ssm put-parameter \
  --name /studio-dev/POSTGRES_PASSWORD \
  --value "my_secret" \
  --type SecureString
```

### Q: 计算变量会被推送到 AWS 吗？

**A:** **不会**。psenv 不会将计算变量（含 `${}` 的变量）推送到 AWS。只有源变量需要在 AWS 中配置。

### Q: 如何迁移旧的 .env.example？

**A:**
1. 识别哪些是源变量（用户凭证、API key 等）
2. 识别哪些是计算变量（拼接的 URL、动态生成的名称等）
3. 将计算逻辑从脚本移到 .env.example 中
4. 使用 `${CTX_*:-default}` 替代硬编码的环境判断

## 技术细节

### psenv 渲染引擎

- **语言**: Rust
- **依赖**: regex, aws-sdk-ssm, tokio
- **算法**: 迭代式依赖解析（拓扑排序的简化版本）
- **限制**: 最多 10 轮迭代，超过则报错

### 模板语法解析

使用正则表达式：`\$\{([a-zA-Z_][a-zA-Z0-9_]*)(:-([^}]*))?\}`

- 捕获组 1: 变量名
- 捕获组 2: 完整的默认值语法（包括 `:-`）
- 捕获组 3: 默认值内容

### 变量优先级总结

```
对于源变量:
  Shell Env > AWS Parameter Store > .env.example Literal

对于计算变量:
  仅从当前 context 中查找 > 使用模板中的默认值
```

## 相关文件

- `rust-packages/psenv/src/main.rs` - psenv 主逻辑
- `rust-packages/psenv/src/template_renderer.rs` - 模板渲染引擎
- `scripts/build-lib.sh` - 环境检测和 CTX_* 注入
- `js-apps/*/\.env.example` - 各应用的配置模板

## 版本历史

- **v0.3.0** (2025-12-02): 重构为两阶段渲染架构
- **v0.2.0**: 支持 AWS Parameter Store 集成
- **v0.1.0**: 初始版本，简单的 key-value 替换
