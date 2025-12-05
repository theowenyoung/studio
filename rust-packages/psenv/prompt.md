# psenv - AWS Parameter Store to .env Tool (Rust)

## 功能

从 AWS Parameter Store 拉取密钥，生成 `.env` 文件。

## 命令示例
```bash
psenv --template .env.example --prefix "/studio-dev/" --output .env
```

## 核心参数

### 必需参数
- `--template` / `-t`: 模板文件路径（如 `.env.example`）
- `--prefix` / `-p`: Parameter Store 前缀（如 `/studio-dev/`，必须以 `/` 开头）

### 可选参数
- `--output` / `-o`: 输出文件（默认 `.env`）
- `--strategy` / `-s`: 处理策略（默认 `merge`）
  - `merge`: 保留已有值，只添加新的
  - `overwrite`: 覆盖已有值
  - `replace`: 完全重新生成
  - `error`: 文件存在则报错
- `--ignore-keys` / `-i`: 跳过的 key（逗号分隔，如 `DB_HOST,DEBUG`）
- `--require-all`: 所有 key 必须存在，否则报错（默认 false）
- `--region` / `-r`: AWS region
- `--profile`: AWS profile
- `--dry-run`: 预览模式
- `--quiet` / `-q`: 安静模式
- `--verbose` / `-v`: 详细日志

## 工作流程
1. 读取模板文件的所有 key
2. 过滤掉 `--ignore-keys` 中的 key
3. 从 AWS Parameter Store 获取 `prefix + key` 的值
4. 根据 strategy 合并/覆盖到输出文件

## Exit Codes
- 0: 成功
- 1: 参数错误
- 2: AWS 认证错误
- 3: 缺少必需参数（--require-all）
- 4: 文件已存在（--strategy=error）

## 特殊行为
- Parameter Store 路径: `prefix + key` (自动去掉前缀写入 .env)
- 例: `/studio-dev/DB_HOST` → `.env` 中写 `DB_HOST=value`
- `--ignore-keys` 的 key 不会被获取
- `--require-all` 时，被 ignore 的 key 不检查

