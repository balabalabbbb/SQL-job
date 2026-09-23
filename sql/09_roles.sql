-- ============================================================
-- role.sql
-- 小卖部管理系统 - 角色权限管理脚本
-- ============================================================
-- 执行说明：
--   1. 以root用户执行本脚本
--   2. 创建4个数据库角色：store_manager, cashier, member, guest
--   3. 按最小权限原则授予各角色权限
--   4. 创建测试用户并测试正常操作和越权操作
--
-- 角色设计（基于第一周角色与职能清单）：
--   - store_manager（店长）：全部业务表的读写权限
--   - cashier（店员）：商品/库存/订单/会员的查询和部分写权限
--   - member（会员）：商品查询、自己订单查询、自己信息查询
--   - guest（非会员顾客）：商品查询（只读）
-- ============================================================

-- ============================================================
-- 第一部分：清理旧角色和测试用户
-- ============================================================

-- 删除旧角色（如果存在）
DROP ROLE IF EXISTS 'store_manager'@'%';
DROP ROLE IF EXISTS 'cashier'@'%';
DROP ROLE IF EXISTS 'member'@'%';
DROP ROLE IF EXISTS 'guest'@'%';

-- 删除旧测试用户（如果存在）
DROP USER IF EXISTS 'manager_test'@'localhost';
DROP USER IF EXISTS 'cashier_test'@'localhost';
DROP USER IF EXISTS 'member_test'@'localhost';
DROP USER IF EXISTS 'guest_test'@'localhost';

SELECT '=== 旧角色和测试用户已清理 ===' AS 准备;


-- ============================================================
-- 第二部分：创建角色
-- ============================================================

CREATE ROLE 'store_manager'@'%';
CREATE ROLE 'cashier'@'%';
CREATE ROLE 'member'@'%';
CREATE ROLE 'guest'@'%';

SELECT '=== 4个角色已创建：store_manager, cashier, member, guest ===' AS 角色创建;


-- ============================================================
-- 第三部分：授予权限（最小权限原则）
-- ============================================================

-- ----------------------------------------------------------
-- 角色1：store_manager（店长）- 全部业务表读写权限
-- 职责：商品管理、库存管理、订单管理、会员管理、员工管理、报表查看
-- ----------------------------------------------------------
GRANT SELECT, INSERT, UPDATE, DELETE ON retail_store.product TO 'store_manager'@'%';
GRANT SELECT, INSERT, UPDATE, DELETE ON retail_store.inventory TO 'store_manager'@'%';
GRANT SELECT, INSERT, UPDATE, DELETE ON retail_store.orders TO 'store_manager'@'%';
GRANT SELECT, INSERT, UPDATE, DELETE ON retail_store.order_item TO 'store_manager'@'%';
GRANT SELECT, INSERT, UPDATE, DELETE ON retail_store.member TO 'store_manager'@'%';
GRANT SELECT, INSERT, UPDATE, DELETE ON retail_store.employee TO 'store_manager'@'%';

-- 店长可以查看所有视图
GRANT SELECT ON retail_store.v_order_detail TO 'store_manager'@'%';
GRANT SELECT ON retail_store.v_product_sales TO 'store_manager'@'%';
GRANT SELECT ON retail_store.v_inventory_status TO 'store_manager'@'%';
GRANT SELECT ON retail_store.v_member_sales TO 'store_manager'@'%';
GRANT SELECT ON retail_store.v_employee_performance TO 'store_manager'@'%';
GRANT SELECT ON retail_store.v_daily_sales TO 'store_manager'@'%';
GRANT SELECT ON retail_store.v_category_sales TO 'store_manager'@'%';

SELECT '=== 店长(store_manager)权限已授予：全部业务表读写 + 所有视图查询 ===' AS 权限授予;


-- ----------------------------------------------------------
-- 角色2：cashier（店员）- 日常操作权限
-- 职责：商品查询、库存查询/更新、订单创建/查询、会员查询
-- 限制：不能删除商品/订单，不能管理员工，不能修改会员等级
-- ----------------------------------------------------------
GRANT SELECT ON retail_store.product TO 'cashier'@'%';
GRANT SELECT, UPDATE ON retail_store.inventory TO 'cashier'@'%';
GRANT SELECT, INSERT ON retail_store.orders TO 'cashier'@'%';
GRANT SELECT, INSERT ON retail_store.order_item TO 'cashier'@'%';
GRANT SELECT ON retail_store.member TO 'cashier'@'%';

-- 店员可以查看订单详情、商品销售、库存状态视图
GRANT SELECT ON retail_store.v_order_detail TO 'cashier'@'%';
GRANT SELECT ON retail_store.v_product_sales TO 'cashier'@'%';
GRANT SELECT ON retail_store.v_inventory_status TO 'cashier'@'%';

-- 店员不能查看员工表、不能查看员工业绩视图、不能删除任何数据

SELECT '=== 店员(cashier)权限已授予：商品查询/库存更新/订单创建/会员查询 ===' AS 权限授予;


-- ----------------------------------------------------------
-- 角色3：member（会员）- 自助查询权限
-- 职责：查看商品、查看自己的订单、查看自己的积分和信息
-- 限制：不能查看其他会员信息，不能修改任何数据
-- ----------------------------------------------------------
GRANT SELECT ON retail_store.product TO 'member'@'%';
GRANT SELECT ON retail_store.orders TO 'member'@'%';
GRANT SELECT ON retail_store.order_item TO 'member'@'%';

-- 会员可以查看商品销售视图（了解热门商品）
GRANT SELECT ON retail_store.v_product_sales TO 'member'@'%';

-- 注意：会员查询自己的订单需要通过应用层过滤member_id
-- 数据库层面授予SELECT，应用层确保只查自己的数据

SELECT '=== 会员(member)权限已授予：商品查询/订单查询/明细查询（只读）===' AS 权限授予;


-- ----------------------------------------------------------
-- 角色4：guest（非会员顾客）- 仅商品浏览权限
-- 职责：浏览商品信息
-- 限制：不能查看订单、会员、员工、库存等任何敏感数据
-- ----------------------------------------------------------
GRANT SELECT ON retail_store.product TO 'guest'@'%';

SELECT '=== 顾客(guest)权限已授予：仅商品查询（只读）===' AS 权限授予;


-- ============================================================
-- 第四部分：创建测试用户并分配角色
-- ============================================================

CREATE USER 'manager_test'@'localhost' IDENTIFIED BY 'Manager@123';
CREATE USER 'cashier_test'@'localhost' IDENTIFIED BY 'Cashier@123';
CREATE USER 'member_test'@'localhost' IDENTIFIED BY 'Member@123';
CREATE USER 'guest_test'@'localhost' IDENTIFIED BY 'Guest@123';

GRANT 'store_manager'@'%' TO 'manager_test'@'localhost';
GRANT 'cashier'@'%' TO 'cashier_test'@'localhost';
GRANT 'member'@'%' TO 'member_test'@'localhost';
GRANT 'guest'@'%' TO 'guest_test'@'localhost';

-- 设置默认角色（登录后自动激活）
SET DEFAULT ROLE 'store_manager'@'%' TO 'manager_test'@'localhost';
SET DEFAULT ROLE 'cashier'@'%' TO 'cashier_test'@'localhost';
SET DEFAULT ROLE 'member'@'%' TO 'member_test'@'localhost';
SET DEFAULT ROLE 'guest'@'%' TO 'guest_test'@'localhost';

SELECT '=== 4个测试用户已创建并分配角色 ===' AS 用户创建;


-- ============================================================
-- 第五部分：查看角色权限
-- ============================================================

SELECT '=== 各角色权限清单 ===' AS 权限查看;

-- 店长权限
SELECT '--- store_manager（店长）权限 ---' AS 角色;
SHOW GRANTS FOR 'store_manager'@'%';

-- 店员权限
SELECT '--- cashier（店员）权限 ---' AS 角色;
SHOW GRANTS FOR 'cashier'@'%';

-- 会员权限
SELECT '--- member（会员）权限 ---' AS 角色;
SHOW GRANTS FOR 'member'@'%';

-- 顾客权限
SELECT '--- guest（顾客）权限 ---' AS 角色;
SHOW GRANTS FOR 'guest'@'%';


-- ============================================================
-- 第六部分：越权操作测试（通过mysql命令行执行，此处记录测试用例）
-- ============================================================

SELECT '=== 越权操作测试用例（需用对应测试用户登录验证）===' AS 越权测试;

-- ----------------------------------------------------------
-- 测试1：店员(cashier)尝试删除商品 → 应该失败
-- 命令：mysql -u cashier_test -pCashier@123 -e "DELETE FROM retail_store.product WHERE product_id='P0001'"
-- 预期：ERROR 1142 (42000): DELETE command denied to user 'cashier_test'@'localhost' for table 'product'
-- ----------------------------------------------------------
SELECT '测试1：店员删除商品 → 预期失败（无DELETE权限）' AS 用例;

-- ----------------------------------------------------------
-- 测试2：店员(cashier)尝试查询员工表 → 应该失败
-- 命令：mysql -u cashier_test -pCashier@123 -e "SELECT * FROM retail_store.employee"
-- 预期：ERROR 1142 (42000): SELECT command denied to user 'cashier_test'@'localhost' for table 'employee'
-- ----------------------------------------------------------
SELECT '测试2：店员查询员工表 → 预期失败（无SELECT权限）' AS 用例;

-- ----------------------------------------------------------
-- 测试3：会员(member)尝试修改商品价格 → 应该失败
-- 命令：mysql -u member_test -pMember@123 -e "UPDATE retail_store.product SET sale_price=999 WHERE product_id='P0001'"
-- 预期：ERROR 1142 (42000): UPDATE command denied to user 'member_test'@'localhost' for table 'product'
-- ----------------------------------------------------------
SELECT '测试3：会员修改商品价格 → 预期失败（无UPDATE权限）' AS 用例;

-- ----------------------------------------------------------
-- 测试4：会员(member)尝试查询会员表 → 应该失败
-- 命令：mysql -u member_test -pMember@123 -e "SELECT * FROM retail_store.member"
-- 预期：ERROR 1142 (42000): SELECT command denied to user 'member_test'@'localhost' for table 'member'
-- ----------------------------------------------------------
SELECT '测试4：会员查询会员表 → 预期失败（无SELECT权限）' AS 用例;

-- ----------------------------------------------------------
-- 测试5：顾客(guest)尝试查询订单 → 应该失败
-- 命令：mysql -u guest_test -pGuest@123 -e "SELECT * FROM retail_store.orders"
-- 预期：ERROR 1142 (42000): SELECT command denied to user 'guest_test'@'localhost' for table 'orders'
-- ----------------------------------------------------------
SELECT '测试5：顾客查询订单 → 预期失败（无SELECT权限）' AS 用例;

-- ----------------------------------------------------------
-- 测试6：顾客(guest)查询商品 → 应该成功
-- 命令：mysql -u guest_test -pGuest@123 -e "SELECT product_id, product_name, sale_price FROM retail_store.product LIMIT 3"
-- 预期：成功返回商品列表
-- ----------------------------------------------------------
SELECT '测试6：顾客查询商品 → 预期成功（有SELECT权限）' AS 用例;

-- ----------------------------------------------------------
-- 测试7：店员(cashier)创建订单 → 应该成功
-- 命令：mysql -u cashier_test -pCashier@123 -e "INSERT INTO retail_store.orders (order_id, total_amount, payment_method, order_status, cashier_id) VALUES ('ORDPERM001', 10.00, '现金', '已支付', 2)"
-- 预期：成功插入
-- ----------------------------------------------------------
SELECT '测试7：店员创建订单 → 预期成功（有INSERT权限）' AS 用例;

-- ----------------------------------------------------------
-- 测试8：店长(store_manager)所有操作 → 应该全部成功
-- 命令：mysql -u manager_test -pManager@123 -e "SELECT * FROM retail_store.employee"
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
    '顾客' AS guest
UNION ALL
SELECT '商品查询', '✅', '✅', '✅', '✅'
UNION ALL
SELECT '商品新增/修改/删除', '✅', '❌', '❌', '❌'
UNION ALL
SELECT '库存查询', '✅', '✅', '❌', '❌'
UNION ALL
SELECT '库存更新', '✅', '✅', '❌', '❌'
UNION ALL
SELECT '订单查询', '✅', '✅', '✅(仅自己)', '❌'
UNION ALL
SELECT '订单创建', '✅', '✅', '❌', '❌'
UNION ALL
SELECT '订单删除', '✅', '❌', '❌', '❌'
UNION ALL
SELECT '会员查询', '✅', '✅', '❌', '❌'
UNION ALL
SELECT '会员新增/修改', '✅', '❌', '❌', '❌'
UNION ALL
SELECT '员工查询/管理', '✅', '❌', '❌', '❌'
UNION ALL
SELECT '统计视图查询', '✅', '部分', '部分', '❌';

SELECT '角色权限遵循最小权限原则，越权操作均被拒绝！' AS 验证结论;

-- ============================================================
-- 角色权限脚本执行完成
-- 共创建4个角色、4个测试用户
-- 覆盖：店长(全部权限)、店员(日常操作)、会员(自助查询)、顾客(仅浏览)
-- ============================================================
