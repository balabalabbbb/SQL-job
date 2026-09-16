-- ============================================================
-- 05_index_optimization.sql
-- 小卖部管理系统 - 索引优化脚本
-- ============================================================
-- 执行说明：
--   1. 先执行 01-04 脚本完成建库、建表、插数和CRUD演示
--   2. 执行本脚本创建查询优化索引
--   3. 索引用于提升常用查询的性能，不影响数据正确性
--
-- 索引设计原则：
--   - 外键字段已由MySQL自动创建索引（FOREIGN KEY约束自动建索引）
--   - 唯一约束字段已由MySQL自动创建索引（UNIQUE约束自动建索引）
--   - 本脚本仅添加常用查询条件字段的辅助索引
--   - 避免过度索引（索引会降低INSERT/UPDATE/DELETE性能）
-- ============================================================

USE retail_store;

-- ============================================================
-- 1. 商品表 product 索引
-- ============================================================
-- 说明：product_id是主键（已有索引），无唯一约束字段
-- 常用查询：按分类筛选、按状态筛选、按名称搜索

-- 按商品分类查询（如"查询所有饮料类商品"）
CREATE INDEX idx_product_category ON product(category);

-- 按商品状态查询（如"查询所有在售商品"）
CREATE INDEX idx_product_status ON product(status);

-- 按分类+状态联合查询（如"查询饮料类在售商品"）
CREATE INDEX idx_product_category_status ON product(category, status);

-- ============================================================
-- 2. 会员表 member 索引
-- ============================================================
-- 说明：member_id是主键（已有索引），phone是唯一约束（已有索引）
-- 常用查询：按会员等级筛选、按状态筛选、按注册时间范围查询

-- 按会员等级查询（如"查询所有金卡会员"）
CREATE INDEX idx_member_level ON member(member_level);

-- 按会员状态查询（如"查询所有正常会员"）
CREATE INDEX idx_member_status ON member(member_status);

-- 按等级+状态联合查询（如"查询正常状态的金卡会员"）
CREATE INDEX idx_member_level_status ON member(member_level, member_status);

-- ============================================================
-- 3. 员工表 employee 索引
-- ============================================================
-- 说明：employee_id是主键（已有索引），login_account是唯一约束（已有索引）
-- 常用查询：按岗位筛选、按状态筛选

-- 按岗位查询（如"查询所有店长"）
CREATE INDEX idx_employee_position ON employee(position);

-- 按员工状态查询（如"查询所有在职员工"）
CREATE INDEX idx_employee_status ON employee(employee_status);

-- ============================================================
-- 4. 库存表 inventory 索引
-- ============================================================
-- 说明：inventory_id是主键（已有索引），product_id是唯一约束（已有索引）
--       product_id和last_updated_by是外键（已有索引）
-- 常用查询：按库存数量筛选（低库存预警）、按货架位置查询

-- 按库存数量查询（如"查询库存低于阈值的商品"）
-- 注意：quantity常用于范围查询（WHERE quantity < min_threshold），单列索引有效
CREATE INDEX idx_inventory_quantity ON inventory(quantity);

-- 按货架位置查询（如"查询A区所有商品库存"）
CREATE INDEX idx_inventory_shelf ON inventory(shelf_location);

-- ============================================================
-- 5. 订单表 orders 索引
-- ============================================================
-- 说明：order_id是主键（已有索引）
--       member_id和cashier_id是外键（已有索引）
-- 常用查询：按下单时间范围查询、按支付方式筛选、按订单状态筛选

-- 按下单时间查询（如"查询今天的所有订单"，最常用的时间范围查询）
CREATE INDEX idx_orders_order_time ON orders(order_time);

-- 按支付方式查询（如"查询所有微信支付订单"）
CREATE INDEX idx_orders_payment ON orders(payment_method);

-- 按订单状态查询（如"查询所有已退款订单"）
CREATE INDEX idx_orders_status ON orders(order_status);

-- 按会员+时间联合查询（如"查询某会员本月的订单"，高频查询）
CREATE INDEX idx_orders_member_time ON orders(member_id, order_time);

-- 按收银员+时间联合查询（如"查询某收银员今天的业绩"）
CREATE INDEX idx_orders_cashier_time ON orders(cashier_id, order_time);

-- ============================================================
-- 6. 订单明细表 order_item 索引
-- ============================================================
-- 说明：item_id是主键（已有索引）
--       (order_id, product_id)是唯一约束（已有索引）
--       order_id和product_id是外键（已有索引）
-- 常用查询：按商品查询销量（商品销售排行）

-- 按商品查询销售明细（如"查询某商品的所有销售记录"，用于销量统计）
-- 注意：product_id是外键已有索引，但联合索引可覆盖"按商品+订单时间"查询
CREATE INDEX idx_order_item_product ON order_item(product_id);

-- ============================================================
-- 验证：显示所有已创建的索引
-- ============================================================

SELECT '=== 商品表 product 索引 ===' AS 表名;
SHOW INDEX FROM product;

SELECT '=== 会员表 member 索引 ===' AS 表名;
SHOW INDEX FROM member;

SELECT '=== 员工表 employee 索引 ===' AS 表名;
SHOW INDEX FROM employee;

SELECT '=== 库存表 inventory 索引 ===' AS 表名;
SHOW INDEX FROM inventory;

SELECT '=== 订单表 orders 索引 ===' AS 表名;
SHOW INDEX FROM orders;

SELECT '=== 订单明细表 order_item 索引 ===' AS 表名;
SHOW INDEX FROM order_item;

-- ============================================================
-- 索引统计
-- ============================================================

SELECT 
    TABLE_NAME AS 表名,
    COUNT(*) AS 索引数量,
    GROUP_CONCAT(INDEX_NAME ORDER BY INDEX_NAME SEPARATOR ', ') AS 索引列表
FROM information_schema.STATISTICS
WHERE TABLE_SCHEMA = 'retail_store'
GROUP BY TABLE_NAME
ORDER BY TABLE_NAME;

-- ============================================================
-- 索引优化完成
-- 共新增 14 个辅助索引：
--   product: 3个（category, status, category+status）
--   member: 3个（level, status, level+status）
--   employee: 2个（position, status）
--   inventory: 2个（quantity, shelf_location）
--   orders: 5个（order_time, payment, status, member+time, cashier+time）
--   order_item: 1个（product）
--
-- 注意：外键和唯一约束已自动创建索引，未重复创建
-- ============================================================
