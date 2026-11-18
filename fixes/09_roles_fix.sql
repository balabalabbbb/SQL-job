-- ============================================================
-- 09_roles_fix.sql
-- 角色权限补全（幂等，可重复执行）
处理两个问题：
--   1. 初次执行时视图尚未创建，对视图的 GRANT 失败 -> 现在视图已存在，补授权
--   2. guest 是 SQL Server 内置数据库用户名，无法 CREATE ROLE guest
--      -> 非会员只读语义改由内置 guest 用户 + 测试用户 guest_test 直接授权实现
-- 以 sysadmin 执行。
-- ============================================================

USE retail_store;
GO

-- ---------- store_manager：业务表全部读写 ----------
GRANT SELECT, INSERT, UPDATE, DELETE ON product    TO store_manager;
GRANT SELECT, INSERT, UPDATE, DELETE ON inventory  TO store_manager;
GRANT SELECT, INSERT, UPDATE, DELETE ON orders     TO store_manager;
GRANT SELECT, INSERT, UPDATE, DELETE ON order_item TO store_manager;
GRANT SELECT, INSERT, UPDATE, DELETE ON member     TO store_manager;
GRANT SELECT, INSERT, UPDATE, DELETE ON employee   TO store_manager;
-- store_manager：全部 7 个视图
GRANT SELECT ON v_order_detail         TO store_manager;
GRANT SELECT ON v_product_sales        TO store_manager;
GRANT SELECT ON v_inventory_status     TO store_manager;
GRANT SELECT ON v_member_sales         TO store_manager;
GRANT SELECT ON v_employee_performance TO store_manager;
GRANT SELECT ON v_daily_sales          TO store_manager;
GRANT SELECT ON v_category_sales       TO store_manager;
GO

-- ---------- cashier：日常操作 ----------
GRANT SELECT          ON product    TO cashier;
GRANT SELECT, UPDATE  ON inventory  TO cashier;
GRANT SELECT, INSERT  ON orders     TO cashier;
GRANT SELECT, INSERT  ON order_item TO cashier;
GRANT SELECT          ON member     TO cashier;
GRANT SELECT ON v_order_detail      TO cashier;
GRANT SELECT ON v_product_sales     TO cashier;
GRANT SELECT ON v_inventory_status     TO cashier;
GO

-- ---------- member：自助只读 ----------
GRANT SELECT ON product       TO member;
GRANT SELECT ON orders        TO member;
GRANT SELECT ON order_item    TO member;
GRANT SELECT ON v_product_sales TO member;
GO

-- ---------- guest 语义：非会员仅可浏览商品 ----------
-- 内置 guest 用户（控制未映射登录的访问）
GRANT SELECT ON product TO guest;
-- 测试用户 guest_test：直接授予 product 只读，替代原“guest 角色”
GRANT SELECT ON product TO guest_test;
GO

PRINT '09_roles_fix 执行完成：三个自定义角色权限完整，guest 只读语义已落地';
GO
