-- 创建测试数据库和用户
CREATE DATABASE test_demo_production;
CREATE USER test_demo_user WITH PASSWORD '$TEST_DEMO_PASSWORD';
GRANT ALL PRIVILEGES ON DATABASE test_demo_production TO test_demo_user;

