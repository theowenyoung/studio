# 环境变量配置重构 CHANGELOG

## v0.3.0 (2025-12-02)

### 🎯 目标

重构环境变量配置管理流程，解决多环境（Dev/Preview/Prod）下复杂变量生成的痛点。

### ✨ 核心变更

#### 1. 工具层：`psenv` 升级为模板渲染引擎

**新增功能：**
- ✅ 支持 Bash 风格变量替换语法
  - `${VAR}` - 严格模式，变量必须存在
  - `${VAR:-default}` - 默认值模式
  - `${VAR:-}` - 允许为空
- ✅ 两阶段处理架构
  - Phase 1: 解析源变量（从环境/AWS/文件获取）
  - Phase 2: 渲染计算变量（模板替换）
- ✅ 多轮迭代渲染，自动处理变量依赖关系
- ✅ 自动包含 `CTX_*` 上下文变量

**修改文件：**
- `rust-packages/psenv/src/main.rs` - 实现两阶段处理逻辑
- `rust-packages/psenv/src/template_parser.rs` - 保留键值对信息
- `rust-packages/psenv/src/template_renderer.rs` - 新增模板渲染引擎
- `rust-packages/psenv/src/lib.rs` - 导出新模块

#### 2. 脚本层：`build-lib.sh` 注入标准上下文

**变更内容：**
- ✅ `detect_environment()` 函数增强
  - 导出 `CTX_DB_SUFFIX` - 数据库名后缀（下划线风格）
  - 导出 `CTX_DNS_SUFFIX` - 域名后缀（中划线风格）
  - 导出 `CTX_PG_HOST` / `CTX_REDIS_HOST` - 基础设施主机
  - 导出 `CTX_ROOT_DOMAIN` - 根域名
- ✅ 保留原有辅助函数（向后兼容）
  - `get_service_name()`
  - `get_database_name()`
  - `get_domain()`

**修改文件：**
- `scripts/build-lib.sh` - 增强环境检测函数

#### 3. 配置层：标准化 `.env.example`

**新规范：**
- ✅ 明确区分源变量和计算变量
- ✅ 源变量：留空或提供默认值
- ✅ 计算变量：使用 `${VAR:-default}` 语法
- ✅ 添加详细注释说明用途

**修改文件：**
- `js-apps/hono-demo/.env.example` - 完全重构
- `js-apps/api/.env.example` - 完全重构

### 📊 测试结果

#### Preview 环境测试
```bash
export CTX_PG_HOST="postgres"
export CTX_DB_SUFFIX="_feat_test"
export CTX_DNS_SUFFIX="-feat-test"
export CTX_ROOT_DOMAIN="preview.owenyoung.com"

# 结果
DATABASE_URL=postgresql://app_user:***@postgres:5432/hono_demo_feat_test
APP_URL=https://hono-demo-feat-test.preview.owenyoung.com
```

#### Local 环境测试
```bash
# 不设置任何 CTX_* 变量

# 结果
DATABASE_URL=postgresql://app_user:dev@localhost:5432/hono_demo
APP_URL=https://hono-demo.localhost
```

✅ 两个环境测试均通过，变量正确渲染。

### 📚 文档更新

**新增文档：**
- `docs/ENV_TEMPLATE_GUIDE.md` - 完整的使用指南
- `docs/CHANGELOG_ENV_REFACTOR.md` - 本变更日志

**更新文档：**
- `CLAUDE.md` - 更新环境变量章节，引用详细指南

### 🔄 迁移指南

#### 对于现有应用

1. **更新 `.env.example`：**
   ```bash
   # 旧格式（硬编码）
   DATABASE_URL=postgresql://app_user:dev@localhost:5432/hono_demo

   # 新格式（模板化）
   POSTGRES_USER=
   POSTGRES_PASSWORD=
   POSTGRES_DB_NAME=
   DB_HOST=${CTX_PG_HOST:-localhost}
   POSTGRES_DB=${POSTGRES_DB_NAME}${CTX_DB_SUFFIX:-}
   DATABASE_URL=postgresql://${POSTGRES_USER}:${POSTGRES_PASSWORD}@${DB_HOST}:5432/${POSTGRES_DB}
   ```

2. **在 AWS Parameter Store 中配置源变量：**
   ```bash
   /studio-dev/POSTGRES_USER=app_user
   /studio-dev/POSTGRES_PASSWORD=<secret>
   /studio-dev/POSTGRES_DB_NAME=hono_demo
   ```

3. **重新编译 psenv（如果使用旧版本）：**
   ```bash
   cd rust-packages/psenv
   cargo build --release
   ```

4. **测试配置：**
   ```bash
   # Dry-run 模式查看结果
   psenv -t .env.example -p /studio-dev/ --dry-run --show-secrets
   ```

#### 对于新应用

直接参考 `js-apps/hono-demo/.env.example` 的结构。

### 🚀 性能优化

- ✅ 多轮渲染限制为 10 次迭代，避免无限循环
- ✅ 使用 Rust 实现，性能优于 Shell 脚本
- ✅ AWS API 调用仅针对源变量，计算变量不产生额外请求

### 🔒 安全改进

- ✅ 敏感信息（密码、密钥）必须留空，强制从 AWS 获取
- ✅ 计算变量不会被推送到 AWS，避免信息泄露
- ✅ Dry-run 模式默认隐藏敏感信息（需 `--show-secrets` 显示）

### ⚠️ Breaking Changes

**无破坏性变更**

本次重构保持向后兼容：
- ✅ 旧的 .env.example 仍然可以工作（作为纯源变量处理）
- ✅ 原有脚本函数保留
- ✅ psenv CLI 参数保持不变

### 📋 文档更新 (2025-12-02)

**澄清设计细节：**
- ✅ 明确说明**顺序无关性**：变量定义顺序不影响渲染结果
- ✅ 明确说明**支持嵌套**：计算变量可以引用其他计算变量
- ✅ 补充**多轮迭代细节**：最多 10 轮，实际通常 2-3 轮
- ✅ 添加**最佳实践**：建议依赖层级不超过 2-3 层
- ✅ 新增 FAQ：关于顺序、嵌套、依赖层级的常见问题

**更新文件：**
- `docs/ENV_TEMPLATE_GUIDE.md` - 完善 Phase 2 说明，添加示例和 FAQ
- `js-apps/hono-demo/.env.example` - 修正默认域名为 `studio.localhost`
- `js-apps/api/.env.example` - 修正默认域名为 `studio.localhost`

### 📝 TODO

后续可以考虑的改进：

- [ ] 为其他 js-apps（proxy, blog, storefront）迁移 .env.example
- [ ] 为 infra-apps 添加模板化配置支持
- [ ] 添加 psenv 配置文件（.psenvrc）支持
- [ ] 实现变量依赖关系可视化工具
- [ ] 支持环境变量加密存储到本地文件

### 👥 贡献者

- Claude Code - 完整实现和文档

### 🔗 相关链接

- [ENV_TEMPLATE_GUIDE.md](ENV_TEMPLATE_GUIDE.md) - 详细使用指南
- [CLAUDE.md](../CLAUDE.md) - 项目主文档
- [psenv GitHub](https://github.com/yourusername/psenv) - 工具仓库（如果独立）
