-- ============================================================
-- 01_create_database_fixed.sql
-- 建库脚本修正版：原始 01 脚本中 CREATE DATABASE 与 USE 处于同一批，
-- 全新环境下编译时数据库尚不存在，USE 报 Msg 911，导致整批不执行。
-- 本修正仅在 CREATE DATABASE 块后补 GO，语义不变；可重复执行。
-- ============================================================

IF NOT EXISTS (SELECT name FROM sys.databases WHERE name = 'retail_store')
BEGIN
    CREATE DATABASE retail_store;
END
GO

USE retail_store;
GO

SELECT name AS 数据库名, collation_name AS 排序规则, state_desc AS 状态
FROM sys.databases
WHERE name = 'retail_store';
GO
