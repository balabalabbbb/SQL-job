-- ============================================================
-- 01_create_database.sql
-- 小卖部管理系统 - 数据库创建脚本 (SQL Server 版本)
-- ============================================================
-- 执行说明：
--   1. 以 sa 或具有 CREATE DATABASE 权限的用户登录 SQL Server
--   2. 执行本脚本创建数据库
--   3. 然后执行 02_create_tables.sql 创建表结构
-- ============================================================

-- 如果数据库已存在则先删除（谨慎使用，会删除所有数据）
-- DROP DATABASE IF EXISTS retail_store;

-- 创建数据库
IF NOT EXISTS (SELECT name FROM sys.databases WHERE name = 'retail_store')
BEGIN
    CREATE DATABASE retail_store;
END
GO

-- 选择使用该数据库
USE retail_store;
GO

-- 显示数据库创建信息
SELECT name AS 数据库名, collation_name AS 排序规则, state_desc AS 状态
FROM sys.databases
WHERE name = 'retail_store';

-- ============================================================
-- 数据库创建完成
-- 下一步：执行 02_create_tables.sql 创建数据表
-- ============================================================
