-- ============================================================
-- 01_create_database.sql
-- 小卖部管理系统 - 数据库创建脚本
-- ============================================================
-- 执行说明：
--   1. 以root或具有CREATE DATABASE权限的用户登录MySQL
--   2. 执行本脚本创建数据库
--   3. 然后执行 02_create_tables.sql 创建表结构
-- ============================================================

-- 如果数据库已存在则先删除（谨慎使用，会删除所有数据）
-- DROP DATABASE IF EXISTS retail_store;

-- 创建数据库
CREATE DATABASE IF NOT EXISTS retail_store
    DEFAULT CHARACTER SET utf8mb4
    DEFAULT COLLATE utf8mb4_unicode_ci;

-- 选择使用该数据库
USE retail_store;

-- 显示数据库创建信息
SHOW CREATE DATABASE retail_store;

-- ============================================================
-- 数据库创建完成
-- 下一步：执行 02_create_tables.sql 创建数据表
-- ============================================================
