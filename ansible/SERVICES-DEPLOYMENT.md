# 独立服务部署指南

现在你可以独立部署数据库、Redis和Caddy服务了！每个服务都有自己的playbook，可以单独运行。

## 📋 可用的独立部署Playbooks

### 1. 数据库部署 (PostgreSQL)
```bash
ansible-playbook -i inventory/production playbooks/deploy-database.yml
```

### 2. Redis缓存部署
```bash
ansible-playbook -i inventory/production playbooks/deploy-redis.yml
```

### 3. Caddy反向代理部署
```bash
ansible-playbook -i inventory/production playbooks/deploy-caddy.yml
```

### 4. 所有服务部署（可选择性）
```bash
ansible-playbook -i inventory/production playbooks/deploy-services.yml
```

## 🎛️ 选择性部署控制

你可以通过变量来控制要部署哪些服务：

### 方法1：使用命令行参数
```bash
# 只部署数据库和Redis，跳过Caddy
ansible-playbook -i inventory/production playbooks/deploy-services.yml \
  --extra-vars "deploy_database=true deploy_redis=true deploy_caddy=false"

# 只部署Caddy
ansible-playbook -i inventory/production playbooks/deploy-services.yml \
  --extra-vars "deploy_database=false deploy_redis=false deploy_caddy=true"
```

### 方法2：在配置文件中设置
在 `inventory/production/group_vars/all.yml` 中添加：
```yaml
# 控制服务部署
deploy_database: true   # 部署PostgreSQL
deploy_redis: true      # 部署Redis  
deploy_caddy: true      # 部署Caddy
```

## 🏷️ 使用Tags进行精确控制

你也可以使用tags来控制部署的具体部分：

### 数据库相关tags
```bash
# 只安装PostgreSQL，不做配置
ansible-playbook -i inventory/production playbooks/deploy-database.yml --tags "postgresql"

# 只进行健康检查
ansible-playbook -i inventory/production playbooks/deploy-database.yml --tags "health-check"

# 只创建备份脚本
ansible-playbook -i inventory/production playbooks/deploy-database.yml --tags "backup"
```

### Redis相关tags
```bash
# 只安装Redis
ansible-playbook -i inventory/production playbooks/deploy-redis.yml --tags "redis"

# 进行连接测试
ansible-playbook -i inventory/production playbooks/deploy-redis.yml --tags "test"
```

### Caddy相关tags
```bash
# 只安装Caddy
ansible-playbook -i inventory/production playbooks/deploy-caddy.yml --tags "caddy"

# 只更新配置
ansible-playbook -i inventory/production playbooks/deploy-caddy.yml --tags "config"
```

## 🔄 更新的主部署流程

原有的 `deploy-app.yml` 现在会调用独立的服务部署：

```bash
# 完整应用部署（包含所有服务）
ansible-playbook -i inventory/production playbooks/deploy-app.yml

# 跳过某些服务的应用部署
ansible-playbook -i inventory/production playbooks/deploy-app.yml \
  --extra-vars "deploy_database=false"
```

## 📊 部署验证

每个服务部署完成后都会显示相应的连接信息和状态：

- **PostgreSQL**: 显示数据库连接信息和备份脚本位置
- **Redis**: 显示缓存连接信息和配置详情  
- **Caddy**: 显示代理配置和管理API地址

## 🚀 使用场景示例

### 场景1：新环境初始化
```bash
# 先部署基础服务
ansible-playbook -i inventory/production playbooks/deploy-services.yml

# 再部署应用（跳过服务安装）
ansible-playbook -i inventory/production playbooks/deploy-app.yml \
  --extra-vars "deploy_database=false deploy_redis=false deploy_caddy=false"
```

### 场景2：只更新某个服务
```bash
# 只更新Redis配置
ansible-playbook -i inventory/production playbooks/deploy-redis.yml --tags "config"

# 只更新Caddy配置
ansible-playbook -i inventory/production playbooks/deploy-caddy.yml --tags "config"
```

### 场景3：维护模式
```bash
# 只部署应用代码，不碰基础服务
ansible-playbook -i inventory/production playbooks/deploy-app.yml \
  --skip-tags "services"
```

这样的拆分让你可以更灵活地管理不同服务的部署和维护！

## ⚠️ 重要修复

### 多数据库支持
独立的数据库部署playbook已经修复，现在能正确处理多个应用的数据库配置：

- ✅ **支持多数据库验证**: 会测试每个应用的数据库连接
- ✅ **支持多应用备份**: 为每个使用PostgreSQL的应用创建独立的备份脚本
- ✅ **正确的连接信息显示**: 显示所有应用的数据库连接详情

### 数据库配置说明
系统会根据`applications`数组中每个应用的配置动态创建：
- 数据库名: `app.services.postgresql.database`
- 数据库用户: `app.services.postgresql.user` 
- 数据库密码: `app.services.postgresql.password`

备份脚本位置: `/opt/{应用名}/backups/pg_backup.sh`
