-- PostgreSQL 基础扩展和系统配置
-- 只包含系统级配置，应用数据库结构由应用的迁移脚本管理

-- 创建常用扩展
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";
CREATE EXTENSION IF NOT EXISTS "pg_stat_statements";

-- 创建监控用户
DO $$
BEGIN
    IF NOT EXISTS (SELECT FROM pg_user WHERE usename = 'monitor') THEN
        CREATE USER monitor WITH PASSWORD 'monitor_{{ ansible_date_time.epoch }}';
        GRANT pg_monitor TO monitor;
        GRANT CONNECT ON DATABASE postgres TO monitor;
    END IF;
END
$$;

