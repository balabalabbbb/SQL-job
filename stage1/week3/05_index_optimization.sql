-- ============================================================
-- 05_index_optimization.sql
-- 小卖部管理系统 - 索引优化脚本 (SQL Server 版本)
-- ============================================================
-- 执行说明：
--   1. 先执行 01-03 脚本完成建库、建表、插数
--   2. 执行本脚本创建索引并验证
--   3. 索引用于加速常用查询，提高数据库性能
-- ============================================================

USE retail_store;

-- ============================================================
-- 第一部分：创建索引
-- ============================================================

-- ----------------------------------------------------------
-- 1. 商品表索引
-- ----------------------------------------------------------

-- 索引1：商品分类索引（加速按分类查询商品）
-- 场景：SELECT * FROM product WHERE category = '饮料';
CREATE INDEX idx_product_category ON product(category);

-- 索引2：商品状态索引（加速按状态筛选在售/下架商品）
-- 场景：SELECT * FROM product WHERE status = '在售';
CREATE INDEX idx_product_status ON product(status);

-- 索引3：商品名称索引（加速按名称搜索商品）
-- 场景：SELECT * FROM product WHERE product_name LIKE '%牛奶%';
CREATE INDEX idx_product_name ON product(product_name);

-- ----------------------------------------------------------
-- 2. 会员表索引
-- ----------------------------------------------------------

-- 索引4：会员手机号索引（加速按手机号查找会员，手机号已有唯一约束但显式建索引更清晰）
-- 场景：SELECT * FROM member WHERE phone = '13800138001';
-- 注意：uk_member_phone 唯一约束已自动创建索引，此处不重复创建

-- 索引5：会员等级索引（加速按等级筛选会员）
-- 场景：SELECT * FROM member WHERE member_level = '金卡';
CREATE INDEX idx_member_level ON member(member_level);

-- 索引6：会员状态索引（加速按状态筛选正常/冻结会员）
CREATE INDEX idx_member_status ON member(member_status);

-- ----------------------------------------------------------
-- 3. 员工表索引
-- ----------------------------------------------------------

-- 索引7：员工岗位索引（加速按岗位查询）
CREATE INDEX idx_employee_position ON employee(position);

-- 索引8：员工状态索引（加速按状态筛选在职/离职员工）
CREATE INDEX idx_employee_status ON employee(employee_status);

-- ----------------------------------------------------------
-- 4. 库存表索引
-- ----------------------------------------------------------

-- 索引9：库存商品ID索引（加速按商品查库存，product_id已有唯一约束自动建索引）
-- 注意：uk_inventory_product 唯一约束已自动创建索引，此处不重复创建

-- 索引10：库存数量索引（加速查询低库存商品）
-- 场景：SELECT * FROM inventory WHERE quantity < min_threshold;
CREATE INDEX idx_inventory_quantity ON inventory(quantity);

-- ----------------------------------------------------------
-- 5. 订单表索引
-- ----------------------------------------------------------

-- 索引11：订单会员ID索引（加速按会员查订单）
-- 场景：SELECT * FROM orders WHERE member_id = 'M0001';
CREATE INDEX idx_orders_member_id ON orders(member_id);

-- 索引12：订单收银员ID索引（加速按收银员查订单）
-- 场景：SELECT * FROM orders WHERE cashier_id = 2;
CREATE INDEX idx_orders_cashier_id ON orders(cashier_id);

-- 索引13：订单时间索引（加速按时间范围查询订单）
-- 场景：SELECT * FROM orders WHERE order_time BETWEEN '2026-09-10' AND '2026-09-16';
CREATE INDEX idx_orders_order_time ON orders(order_time);

-- 索引14：订单状态索引（加速按状态筛选已支付/已退款订单）
CREATE INDEX idx_orders_status ON orders(order_status);

-- ----------------------------------------------------------
-- 6. 订单明细表索引
-- ----------------------------------------------------------

-- 索引15：订单明细-订单ID索引（加速按订单查明细，外键自动建索引）
-- 注意：外键 fk_order_item_orders 已自动创建索引，此处不重复创建

-- 索引16：订单明细-商品ID索引（加速按商品查销售记录，外键自动建索引）
-- 注意：外键 fk_order_item_product 已自动创建索引，此处不重复创建

-- ============================================================
-- 第二部分：验证索引
-- ============================================================

-- 查看所有索引（使用系统视图）
SELECT '=== 所有表的索引清单 ===' AS 索引管理;

SELECT
    t.name AS 表名,
    i.name AS 索引名,
    i.type_desc AS 索引类型,
    i.is_unique AS 是否唯一,
    i.is_primary_key AS 是否主键
FROM sys.indexes i
JOIN sys.tables t ON i.object_id = t.object_id
WHERE i.type > 0  -- 排除堆表(HEAP)
ORDER BY t.name, i.is_primary_key DESC, i.name;

-- 查看索引列详情
SELECT '=== 索引列详情 ===' AS 索引列;

SELECT
    t.name AS 表名,
    i.name AS 索引名,
    c.name AS 列名,
    ic.key_ordinal AS 列顺序
FROM sys.indexes i
JOIN sys.tables t ON i.object_id = t.object_id
JOIN sys.index_columns ic ON i.object_id = ic.object_id AND i.index_id = ic.index_id
JOIN sys.columns c ON ic.object_id = c.object_id AND ic.column_id = c.column_id
WHERE i.type > 0
ORDER BY t.name, i.name, ic.key_ordinal;

-- ============================================================
-- 第三部分：索引使用示例（EXPLAIN 等价物：查看执行计划）
-- ============================================================

-- SQL Server 中使用 SET SHOWPLAN_TEXT ON 或 SET STATISTICS IO ON 查看查询计划
-- 以下演示带索引的查询

-- 示例1：按分类查询商品（使用 idx_product_category）
SELECT '=== 示例1：按分类查询商品（使用分类索引）===' AS 查询示例;
SELECT product_id, product_name, sale_price
FROM product
WHERE category = '饮料';

-- 示例2：按会员查订单（使用 idx_orders_member_id）
SELECT '=== 示例2：按会员查订单（使用会员ID索引）===' AS 查询示例;
SELECT order_id, order_time, total_amount
FROM orders
WHERE member_id = 'M0001';

-- 示例3：按时间范围查订单（使用 idx_orders_order_time）
SELECT '=== 示例3：按时间范围查订单（使用时间索引）===' AS 查询示例;
SELECT order_id, order_time, total_amount
FROM orders
WHERE order_time >= '2026-09-15' AND order_time < '2026-09-16';

-- ============================================================
-- 索引优化脚本执行完成
-- 共创建14个非主键/非唯一约束索引：
--   商品表：3个（分类、状态、名称）
--   会员表：2个（等级、状态）
--   员工表：2个（岗位、状态）
--   库存表：1个（数量）
--   订单表：4个（会员ID、收银员ID、时间、状态）
--   订单明细表：0个（外键已自动建索引）
-- 另有：6个主键索引 + 4个唯一约束索引 = 10个自动创建索引
-- 总计：24个索引
-- ============================================================
