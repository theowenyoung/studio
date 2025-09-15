-- 创建测试数据库和用户
-- 注意: 如果数据库或用户已存在，会显示错误但不会中断执行

-- 创建用户（如果不存在）
DO $$
BEGIN
    IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'test_demo_user') THEN
        CREATE USER test_demo_user WITH PASSWORD '$TEST_DEMO_POSTGRES_PASSWORD';
    END IF;
END $$;

-- 创建数据库（可能已存在）
SELECT 'CREATE DATABASE test_demo_production'
WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'test_demo_production')\gexec

-- 授予权限
GRANT ALL PRIVILEGES ON DATABASE test_demo_production TO test_demo_user;

