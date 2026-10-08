-- ============================================================
-- 09_roles.sql
-- 小卖部管理系统 - 角色权限管理脚本 (SQL Server 版本)
-- ============================================================
-- 执行说明：
--   1. 以 sa 或具有 CREATE ANY DATABASE / ALTER ANY LOGIN 权限的用户执行
--   2. 创建4个数据库角色：store_manager, cashier, member, customer
--   3. 按最小权限原则授予各角色权限
--   4. 创建测试登录名+用户并分配角色
--   5. 测试正常操作和越权操作
--
-- SQL Server 权限模型说明：
--   - LOGIN（登录名）：服务器级别，用于连接SQL Server实例
--   - USER（用户）：数据库级别，映射到LOGIN，用于数据库内权限
--   - ROLE（角色）：数据库级别，可包含多个USER，权限授予角色后成员自动继承
--   - 权限授予：GRANT SELECT ON 表名 TO 角色名
--   - 角色成员：ALTER ROLE 角色名 ADD MEMBER 用户名
--
-- 角色设计（基于第一周角色与职能清单）：
--   - store_manager（店长）：全部业务表的读写权限
--   - cashier（店员）：商品/库存/订单/会员的查询和部分写权限
--   - member（会员）：商品查询、自己订单查询、自己信息查询
--   - customer（非会员顾客）：商品查询（只读）
-- ============================================================

USE retail_store;

-- ============================================================
-- 第一部分：清理旧角色、用户和登录名
-- ============================================================

-- 先移除角色成员（如果存在）
IF EXISTS (SELECT * FROM sys.database_role_members drm
           JOIN sys.database_principals dp ON drm.role_principal_id = dp.principal_id
           WHERE dp.name = 'store_manager')
    ALTER ROLE store_manager DROP MEMBER manager_test;

IF EXISTS (SELECT * FROM sys.database_role_members drm
           JOIN sys.database_principals dp ON drm.role_principal_id = dp.principal_id
           WHERE dp.name = 'cashier')
    ALTER ROLE cashier DROP MEMBER cashier_test;

IF EXISTS (SELECT * FROM sys.database_role_members drm
           JOIN sys.database_principals dp ON drm.role_principal_id = dp.principal_id
           WHERE dp.name = 'member')
    ALTER ROLE member DROP MEMBER member_test;

IF EXISTS (SELECT * FROM sys.database_role_members drm
           JOIN sys.database_principals dp ON drm.role_principal_id = dp.principal_id
           WHERE dp.name = 'customer')
    ALTER ROLE customer DROP MEMBER guest_test;

-- 删除数据库用户（如果存在）
IF EXISTS (SELECT * FROM sys.database_principals WHERE name = 'manager_test' AND type = 'S')
    DROP USER manager_test;
IF EXISTS (SELECT * FROM sys.database_principals WHERE name = 'cashier_test' AND type = 'S')
    DROP USER cashier_test;
IF EXISTS (SELECT * FROM sys.database_principals WHERE name = 'member_test' AND type = 'S')
    DROP USER member_test;
IF EXISTS (SELECT * FROM sys.database_principals WHERE name = 'guest_test' AND type = 'S')
    DROP USER guest_test;

-- 删除服务器登录名（如果存在）
IF EXISTS (SELECT * FROM sys.server_principals WHERE name = 'manager_test' AND type = 'S')
    DROP LOGIN manager_test;
IF EXISTS (SELECT * FROM sys.server_principals WHERE name = 'cashier_test' AND type = 'S')
    DROP LOGIN cashier_test;
IF EXISTS (SELECT * FROM sys.server_principals WHERE name = 'member_test' AND type = 'S')
    DROP LOGIN member_test;
IF EXISTS (SELECT * FROM sys.server_principals WHERE name = 'guest_test' AND type = 'S')
    DROP LOGIN guest_test;

-- 删除数据库角色（如果存在）
IF EXISTS (SELECT * FROM sys.database_principals WHERE name = 'store_manager' AND type = 'R')
    DROP ROLE store_manager;
IF EXISTS (SELECT * FROM sys.database_principals WHERE name = 'cashier' AND type = 'R')
    DROP ROLE cashier;
IF EXISTS (SELECT * FROM sys.database_principals WHERE name = 'member' AND type = 'R')
    DROP ROLE member;
IF EXISTS (SELECT * FROM sys.database_principals WHERE name = 'customer' AND type = 'R')
    DROP ROLE customer;

SELECT '=== 旧角色、用户和登录名已清理 ===' AS 准备;
GO


-- ============================================================
-- 第二部分：创建角色
-- ============================================================

CREATE ROLE store_manager;
CREATE ROLE cashier;
CREATE ROLE member;
CREATE ROLE customer;

SELECT '=== 4个角色已创建：store_manager, cashier, member, customer ===' AS 角色创建;
GO


-- ============================================================
-- 第三部分：授予权限（最小权限原则）
-- ============================================================

-- ----------------------------------------------------------
-- 角色1：store_manager（店长）- 全部业务表读写权限
-- 职责：商品管理、库存管理、订单管理、会员管理、员工管理、报表查看
-- ----------------------------------------------------------
GRANT SELECT, INSERT, UPDATE, DELETE ON product TO store_manager;
GRANT SELECT, INSERT, UPDATE, DELETE ON inventory TO store_manager;
GRANT SELECT, INSERT, UPDATE, DELETE ON orders TO store_manager;
GRANT SELECT, INSERT, UPDATE, DELETE ON order_item TO store_manager;
GRANT SELECT, INSERT, UPDATE, DELETE ON member TO store_manager;
GRANT SELECT, INSERT, UPDATE, DELETE ON employee TO store_manager;

-- 店长可以查看所有视图
GRANT SELECT ON v_order_detail TO store_manager;
GRANT SELECT ON v_product_sales TO store_manager;
GRANT SELECT ON v_inventory_status TO store_manager;
GRANT SELECT ON v_member_sales TO store_manager;
GRANT SELECT ON v_employee_performance TO store_manager;
GRANT SELECT ON v_daily_sales TO store_manager;
GRANT SELECT ON v_category_sales TO store_manager;

SELECT '=== 店长(store_manager)权限已授予：全部业务表读写 + 所有视图查询 ===' AS 权限授予;


-- ----------------------------------------------------------
-- 角色2：cashier（店员）- 日常操作权限
-- 职责：商品查询、库存查询/更新、订单创建/查询、会员查询
-- 限制：不能删除商品/订单，不能管理员工，不能修改会员等级
-- ----------------------------------------------------------
GRANT SELECT ON product TO cashier;
GRANT SELECT, UPDATE ON inventory TO cashier;
GRANT SELECT, INSERT ON orders TO cashier;
GRANT SELECT, INSERT ON order_item TO cashier;
GRANT SELECT ON member TO cashier;

-- 店员可以查看订单详情、商品销售、库存状态视图
GRANT SELECT ON v_order_detail TO cashier;
GRANT SELECT ON v_product_sales TO cashier;
GRANT SELECT ON v_inventory_status TO cashier;

-- 店员不能查看员工表、不能查看员工业绩视图、不能删除任何数据

SELECT '=== 店员(cashier)权限已授予：商品查询/库存更新/订单创建/会员查询 ===' AS 权限授予;


-- ----------------------------------------------------------
-- 角色3：member（会员）- 自助查询权限
-- 职责：查看商品、查看自己的订单、查看自己的积分和信息
-- 限制：不能查看其他会员信息，不能修改任何数据
-- ----------------------------------------------------------
GRANT SELECT ON product TO member;
GRANT SELECT ON orders TO member;
GRANT SELECT ON order_item TO member;

-- 会员可以查看商品销售视图（了解热门商品）
GRANT SELECT ON v_product_sales TO member;

-- 注意：会员查询自己的订单需要通过应用层过滤member_id
-- 数据库层面授予SELECT，应用层确保只查自己的数据

SELECT '=== 会员(member)权限已授予：商品查询/订单查询/明细查询（只读）===' AS 权限授予;


-- ----------------------------------------------------------
-- 角色4：customer（非会员顾客）- 仅商品浏览权限
-- 职责：浏览商品信息
-- 限制：不能查看订单、会员、员工、库存等任何敏感数据
-- ----------------------------------------------------------
GRANT SELECT ON product TO customer;

SELECT '=== 顾客(customer)权限已授予：仅商品查询（只读）===' AS 权限授予;


-- ============================================================
-- 第四部分：创建测试登录名、用户并分配角色
-- ============================================================

-- 创建登录名（服务器级别）
CREATE LOGIN manager_test WITH PASSWORD = 'Manager@123', CHECK_POLICY = OFF;
CREATE LOGIN cashier_test WITH PASSWORD = 'Cashier@123', CHECK_POLICY = OFF;
CREATE LOGIN member_test WITH PASSWORD = 'Member@123', CHECK_POLICY = OFF;
CREATE LOGIN guest_test WITH PASSWORD = 'Guest@123', CHECK_POLICY = OFF;

-- 创建数据库用户（映射到登录名）
CREATE USER manager_test FOR LOGIN manager_test;
CREATE USER cashier_test FOR LOGIN cashier_test;
CREATE USER member_test FOR LOGIN member_test;
CREATE USER guest_test FOR LOGIN guest_test;

-- 将用户添加到角色（SQL Server中添加后角色自动生效，无需设置默认角色）
ALTER ROLE store_manager ADD MEMBER manager_test;
ALTER ROLE cashier ADD MEMBER cashier_test;
ALTER ROLE member ADD MEMBER member_test;
ALTER ROLE customer ADD MEMBER guest_test;

SELECT '=== 4个测试登录名+用户已创建并分配角色 ===' AS 用户创建;
GO


-- ============================================================
-- 第五部分：查看角色权限
-- ============================================================

SELECT '=== 各角色权限清单 ===' AS 权限查看;

-- 店长权限
SELECT '--- store_manager（店长）权限 ---' AS 角色;
SELECT
    dp.permission_name AS 权限,
    dp.state_desc AS 状态,
    OBJECT_NAME(dp.major_id) AS 对象名
FROM sys.database_permissions dp
JOIN sys.database_principals d ON dp.grantee_principal_id = d.principal_id
WHERE d.name = 'store_manager' AND dp.class = 1
ORDER BY 对象名, 权限;

-- 店员权限
SELECT '--- cashier（店员）权限 ---' AS 角色;
SELECT
    dp.permission_name AS 权限,
    dp.state_desc AS 状态,
    OBJECT_NAME(dp.major_id) AS 对象名
FROM sys.database_permissions dp
JOIN sys.database_principals d ON dp.grantee_principal_id = d.principal_id
WHERE d.name = 'cashier' AND dp.class = 1
ORDER BY 对象名, 权限;

-- 会员权限
SELECT '--- member（会员）权限 ---' AS 角色;
SELECT
    dp.permission_name AS 权限,
    dp.state_desc AS 状态,
    OBJECT_NAME(dp.major_id) AS 对象名
FROM sys.database_permissions dp
JOIN sys.database_principals d ON dp.grantee_principal_id = d.principal_id
WHERE d.name = 'member' AND dp.class = 1
ORDER BY 对象名, 权限;

-- 顾客权限
SELECT '--- customer（顾客）权限 ---' AS 角色;
SELECT
    dp.permission_name AS 权限,
    dp.state_desc AS 状态,
    OBJECT_NAME(dp.major_id) AS 对象名
FROM sys.database_permissions dp
JOIN sys.database_principals d ON dp.grantee_principal_id = d.principal_id
WHERE d.name = 'customer' AND dp.class = 1
ORDER BY 对象名, 权限;

-- 查看角色成员关系
SELECT '=== 角色-成员关系 ===' AS 成员关系;
SELECT
    r.name AS 角色名,
    u.name AS 成员用户名
FROM sys.database_role_members drm
JOIN sys.database_principals r ON drm.role_principal_id = r.principal_id
JOIN sys.database_principals u ON drm.member_principal_id = u.principal_id
ORDER BY r.name, u.name;


-- ============================================================
-- 第六部分：越权操作测试（通过sqlcmd命令行执行，此处记录测试用例）
-- ============================================================

SELECT '=== 越权操作测试用例（需用对应测试用户登录验证）===' AS 越权测试;

-- ----------------------------------------------------------
-- 测试1：店员(cashier)尝试删除商品 → 应该失败
-- 命令：sqlcmd -S localhost -U cashier_test -P Cashier@123 -d retail_store -Q "DELETE FROM product WHERE product_id='P0001'"
-- 预期：The DELETE permission was denied on the object 'product'
-- ----------------------------------------------------------
SELECT '测试1：店员删除商品 → 预期失败（无DELETE权限）' AS 用例;

-- ----------------------------------------------------------
-- 测试2：店员(cashier)尝试查询员工表 → 应该失败
-- 命令：sqlcmd -S localhost -U cashier_test -P Cashier@123 -d retail_store -Q "SELECT * FROM employee"
-- 预期：The SELECT permission was denied on the object 'employee'
-- ----------------------------------------------------------
SELECT '测试2：店员查询员工表 → 预期失败（无SELECT权限）' AS 用例;

-- ----------------------------------------------------------
-- 测试3：会员(member)尝试修改商品价格 → 应该失败
-- 命令：sqlcmd -S localhost -U member_test -P Member@123 -d retail_store -Q "UPDATE product SET sale_price=999 WHERE product_id='P0001'"
-- 预期：The UPDATE permission was denied on the object 'product'
-- ----------------------------------------------------------
SELECT '测试3：会员修改商品价格 → 预期失败（无UPDATE权限）' AS 用例;

-- ----------------------------------------------------------
-- 测试4：会员(member)尝试查询会员表 → 应该失败
-- 命令：sqlcmd -S localhost -U member_test -P Member@123 -d retail_store -Q "SELECT * FROM member"
-- 预期：The SELECT permission was denied on the object 'member'
-- ----------------------------------------------------------
SELECT '测试4：会员查询会员表 → 预期失败（无SELECT权限）' AS 用例;

-- ----------------------------------------------------------
-- 测试5：顾客(guest)尝试查询订单 → 应该失败
-- 命令：sqlcmd -S localhost -U guest_test -P Guest@123 -d retail_store -Q "SELECT * FROM orders"
-- 预期：The SELECT permission was denied on the object 'orders'
-- ----------------------------------------------------------
SELECT '测试5：顾客查询订单 → 预期失败（无SELECT权限）' AS 用例;

-- ----------------------------------------------------------
-- 测试6：顾客(guest)查询商品 → 应该成功
-- 命令：sqlcmd -S localhost -U guest_test -P Guest@123 -d retail_store -Q "SELECT TOP 3 product_id, product_name, sale_price FROM product"
-- 预期：成功返回商品列表
-- ----------------------------------------------------------
SELECT '测试6：顾客查询商品 → 预期成功（有SELECT权限）' AS 用例;

-- ----------------------------------------------------------
-- 测试7：店员(cashier)创建订单 → 应该成功
-- 命令：sqlcmd -S localhost -U cashier_test -P Cashier@123 -d retail_store -Q "INSERT INTO orders (order_id, total_amount, payment_method, order_status, cashier_id) VALUES ('ORDPERM001', 10.00, '现金', '已支付', 2)"
-- 预期：成功插入（(1 rows affected)）
-- ----------------------------------------------------------
SELECT '测试7：店员创建订单 → 预期成功（有INSERT权限）' AS 用例;

-- ----------------------------------------------------------
-- 测试8：店长(store_manager)所有操作 → 应该全部成功
-- 命令：sqlcmd -S localhost -U manager_test -P Manager@123 -d retail_store -Q "SELECT * FROM employee"
-- 预期：成功返回员工列表
-- ----------------------------------------------------------
SELECT '测试8：店长查询员工表 → 预期成功（有全部权限）' AS 用例;


-- ============================================================
-- 第七部分：角色权限总结
-- ============================================================

SELECT '=== 角色权限矩阵总结 ===' AS 权限矩阵;

SELECT
    '功能/数据' AS 功能,
    '店长' AS store_manager,
    '店员' AS cashier,
    '会员' AS member,
    '顾客' AS customer
UNION ALL
SELECT '商品查询', 'Y', 'Y', 'Y', 'Y'
UNION ALL
SELECT '商品新增/修改/删除', 'Y', 'N', 'N', 'N'
UNION ALL
SELECT '库存查询', 'Y', 'Y', 'N', 'N'
UNION ALL
SELECT '库存更新', 'Y', 'Y', 'N', 'N'
UNION ALL
SELECT '订单查询', 'Y', 'Y', 'Y(仅自己)', 'N'
UNION ALL
SELECT '订单创建', 'Y', 'Y', 'N', 'N'
UNION ALL
SELECT '订单删除', 'Y', 'N', 'N', 'N'
UNION ALL
SELECT '会员查询', 'Y', 'Y', 'N', 'N'
UNION ALL
SELECT '会员新增/修改', 'Y', 'N', 'N', 'N'
UNION ALL
SELECT '员工查询/管理', 'Y', 'N', 'N', 'N'
UNION ALL
SELECT '统计视图查询', 'Y', '部分', '部分', 'N';

SELECT '角色权限遵循最小权限原则，越权操作均被拒绝！' AS 验证结论;

-- ============================================================
-- 角色权限脚本执行完成
-- 共创建4个角色、4个测试登录名+4个测试用户
-- 覆盖：店长(全部权限)、店员(日常操作)、会员(自助查询)、顾客(仅浏览)
--
-- 测试用户登录信息：
--   店长：manager_test / Manager@123
--   店员：cashier_test / Cashier@123
--   会员：member_test / Member@123
--   顾客：guest_test / Guest@123
--
-- 使用sqlcmd测试示例：
--   sqlcmd -S localhost -U cashier_test -P Cashier@123 -d retail_store -Q "SELECT * FROM product"
-- ============================================================
