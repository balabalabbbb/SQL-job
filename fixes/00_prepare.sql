-- ============================================================
-- 00_prepare.sql
-- 复现前置补丁：处理仓库脚本两个已知坑（不改原始仓库文件）
--   1. 仓库无 CREATE LOGIN retail_app，只有对它的 GRANT -> 这里补建登录与用户
--   2. week6/migration.sql 有 GRANT ... TO customer，但实际角色是 guest
--      -> 这里创建兼容角色 customer，保证原脚本可直接执行
-- 以 sysadmin（当前 Windows 用户 HUAWEI）执行；可重复执行。
-- ============================================================

USE master;
GO

-- 1. 服务器登录名 retail_app（CHECK_POLICY=OFF 以兼容其密码策略）
IF NOT EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'retail_app' AND type = 'S')
BEGIN
    CREATE LOGIN retail_app WITH PASSWORD = 'retail123456', CHECK_POLICY = OFF;
    PRINT '已创建登录名 retail_app';
END
GO

USE retail_store;
GO

-- 2. 数据库用户 retail_app，映射到同名登录
IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name = 'retail_app' AND type = 'S')
BEGIN
    CREATE USER retail_app FOR LOGIN retail_app;
    PRINT '已创建数据库用户 retail_app';
END
GO

-- 3. 兼容角色 customer（migration.sql 第407行 GRANT 引用）
IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name = 'customer' AND type = 'R')
BEGIN
    CREATE ROLE customer;
    PRINT '已创建兼容角色 customer';
END
GO
