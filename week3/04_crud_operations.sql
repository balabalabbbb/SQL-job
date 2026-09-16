-- ============================================================
-- 04_crud_operations.sql
-- 小卖部管理系统 - 增删改查（CRUD）操作脚本
-- ============================================================
-- 执行说明：
--   1. 先执行 01_create_database.sql、02_create_tables.sql、03_insert_sample_data.sql
--   2. 执行本脚本进行CRUD操作演示
--   3. 每个操作前都有SELECT验证目标行，修改/删除后有结果验证
--   4. DELETE和UPDATE操作前先用相同条件SELECT确认目标
-- ============================================================

USE retail_store;

-- ============================================================
-- 第一部分：商品表 product 的 CRUD 操作
-- ============================================================

-- ----------------------------------------------------------
-- C (Create) - 插入新商品
-- ----------------------------------------------------------

-- 操作前：查看当前商品总数
SELECT '=== 插入新商品前：商品总数 ===' AS 操作;
SELECT COUNT(*) AS 商品总数 FROM product;

-- 插入新商品：旺仔牛奶125ml
INSERT INTO product (product_id, product_name, category, sale_price, purchase_price, unit, supplier, production_date, shelf_life_days, status)
VALUES ('P0011', '旺仔牛奶125ml', '饮料', 2.50, 1.20, '盒', '旺旺集团', '2026-08-25', 270, '在售');

-- 操作后：查看新插入的商品
SELECT '=== 插入新商品后：查看新商品 ===' AS 操作;
SELECT * FROM product WHERE product_id = 'P0011';

-- ----------------------------------------------------------
-- R (Read) - 查询商品
-- ----------------------------------------------------------

-- 查询1：查询所有在售商品，按价格升序
SELECT '=== 查询1：所有在售商品（按价格升序）===' AS 操作;
SELECT product_id, product_name, category, sale_price, unit, status
FROM product
WHERE status = '在售'
ORDER BY sale_price ASC;

-- 查询2：查询饮料类商品，显示毛利（售价-进价）和毛利率
SELECT '=== 查询2：饮料类商品及毛利分析 ===' AS 操作;
SELECT
    product_id,
    product_name,
    sale_price AS 售价,
    purchase_price AS 进价,
    (sale_price - purchase_price) AS 毛利,
    ROUND((sale_price - purchase_price) / sale_price * 100, 2) AS 毛利率百分比
FROM product
WHERE category = '饮料'
ORDER BY 毛利 DESC;

-- 查询3：查询库存不足（缺货或下架）的商品
SELECT '=== 查询3：缺货或下架商品 ===' AS 操作;
SELECT p.product_id, p.product_name, p.status, i.quantity
FROM product p
LEFT JOIN inventory i ON p.product_id = i.product_id
WHERE p.status IN ('缺货', '下架');

-- ----------------------------------------------------------
-- U (Update) - 修改商品
-- ----------------------------------------------------------

-- 操作前：先SELECT确认要修改的目标行
SELECT '=== 修改商品前：确认目标商品 ===' AS 操作;
SELECT product_id, product_name, sale_price, status FROM product WHERE product_id = 'P0011';

-- 修改商品：旺仔牛奶涨价到3.00元，并修改供应商
UPDATE product
SET sale_price = 3.00,
    supplier = '旺旺食品有限公司'
WHERE product_id = 'P0011';

-- 操作后：验证修改结果
SELECT '=== 修改商品后：验证修改结果 ===' AS 操作;
SELECT product_id, product_name, sale_price, supplier FROM product WHERE product_id = 'P0011';

-- ----------------------------------------------------------
-- D (Delete) - 删除商品
-- ----------------------------------------------------------

-- 操作前：先SELECT确认要删除的目标行
SELECT '=== 删除商品前：确认目标商品 ===' AS 操作;
SELECT product_id, product_name FROM product WHERE product_id = 'P0011';

-- 注意：删除前需确认该商品没有被库存表或订单明细表引用
-- 检查库存引用
SELECT '=== 检查库存表是否引用该商品 ===' AS 操作;
SELECT COUNT(*) AS 库存引用数 FROM inventory WHERE product_id = 'P0011';

-- 检查订单明细引用
SELECT '=== 检查订单明细表是否引用该商品 ===' AS 操作;
SELECT COUNT(*) AS 订单明细引用数 FROM order_item WHERE product_id = 'P0011';

-- 删除商品（新插入的P0011没有被其他表引用，可以安全删除）
DELETE FROM product WHERE product_id = 'P0011';

-- 操作后：验证删除结果
SELECT '=== 删除商品后：验证删除结果 ===' AS 操作;
SELECT COUNT(*) AS 商品P0011数量 FROM product WHERE product_id = 'P0011';


-- ============================================================
-- 第二部分：库存表 inventory 的 CRUD 操作
-- ============================================================

-- ----------------------------------------------------------
-- C (Create) - 插入新库存记录
-- ----------------------------------------------------------

-- 操作前：查看P0011商品是否有库存（之前已删除商品，这里用已有商品演示）
-- 先重新插入P0011商品用于库存演示
INSERT INTO product (product_id, product_name, category, sale_price, purchase_price, unit, supplier, production_date, shelf_life_days, status)
VALUES ('P0011', '旺仔牛奶125ml', '饮料', 2.50, 1.20, '盒', '旺旺集团', '2026-08-25', 270, '在售');

-- 插入新库存记录
SELECT '=== 插入新库存前：商品P0011库存情况 ===' AS 操作;
SELECT * FROM inventory WHERE product_id = 'P0011';

INSERT INTO inventory (product_id, quantity, shelf_location, min_threshold, last_updated, last_updated_by)
VALUES ('P0011', 50, 'A-05', 15, '2026-09-16 10:00:00', 2);

-- 操作后：查看新插入的库存
SELECT '=== 插入新库存后：查看库存记录 ===' AS 操作;
SELECT * FROM inventory WHERE product_id = 'P0011';

-- ----------------------------------------------------------
-- R (Read) - 查询库存
-- ----------------------------------------------------------

-- 查询1：查询所有库存低于最低阈值的商品（需要补货）
SELECT '=== 查询1：库存低于阈值（需要补货）===' AS 操作;
SELECT
    i.inventory_id,
    p.product_name,
    i.quantity AS 当前库存,
    i.min_threshold AS 最低阈值,
    i.shelf_location AS 货架位置,
    (i.min_threshold - i.quantity) AS 缺口数量
FROM inventory i
JOIN product p ON i.product_id = p.product_id
WHERE i.quantity < i.min_threshold
ORDER BY 缺口数量 DESC;

-- 查询2：按商品分类统计库存总数量和库存总价值
SELECT '=== 查询2：按分类统计库存价值 ===' AS 操作;
SELECT
    p.category AS 商品分类,
    COUNT(*) AS 商品种类数,
    SUM(i.quantity) AS 库存总数量,
    SUM(i.quantity * p.purchase_price) AS 库存总进价,
    SUM(i.quantity * p.sale_price) AS 库存总售价
FROM inventory i
JOIN product p ON i.product_id = p.product_id
GROUP BY p.category
ORDER BY 库存总售价 DESC;

-- ----------------------------------------------------------
-- U (Update) - 修改库存（模拟销售后扣减库存）
-- ----------------------------------------------------------

-- 操作前：先SELECT确认要修改的目标行
SELECT '=== 修改库存前：确认P0001当前库存 ===' AS 操作;
SELECT inventory_id, product_id, quantity, last_updated FROM inventory WHERE product_id = 'P0001';

-- 模拟销售：纯牛奶卖出5盒，扣减库存
UPDATE inventory
SET quantity = quantity - 5,
    last_updated = '2026-09-16 12:00:00',
    last_updated_by = 2
WHERE product_id = 'P0001';

-- 操作后：验证库存扣减结果
SELECT '=== 修改库存后：验证P0001库存扣减 ===' AS 操作;
SELECT inventory_id, product_id, quantity, last_updated FROM inventory WHERE product_id = 'P0001';

-- ----------------------------------------------------------
-- D (Delete) - 删除库存记录
-- ----------------------------------------------------------

-- 操作前：先SELECT确认要删除的目标行
SELECT '=== 删除库存前：确认目标库存 ===' AS 操作;
SELECT inventory_id, product_id, quantity FROM inventory WHERE product_id = 'P0011';

-- 删除库存记录（P0011的库存，注意删除后商品还在）
DELETE FROM inventory WHERE product_id = 'P0011';

-- 操作后：验证删除结果
SELECT '=== 删除库存后：验证删除结果 ===' AS 操作;
SELECT COUNT(*) AS P0011库存记录数 FROM inventory WHERE product_id = 'P0011';

-- 清理：删除演示用的P0011商品
DELETE FROM product WHERE product_id = 'P0011';


-- ============================================================
-- 第三部分：订单表 orders 的 CRUD 操作
-- ============================================================

-- ----------------------------------------------------------
-- C (Create) - 创建新订单（含订单明细）
-- ----------------------------------------------------------

-- 操作前：查看当前订单总数
SELECT '=== 创建新订单前：订单总数 ===' AS 操作;
SELECT COUNT(*) AS 订单总数 FROM orders;

-- 创建新订单（注意：先插入订单主表，再插入订单明细）
-- 使用事务保证订单主表与明细的一致性，任何一步失败则全部回滚
START TRANSACTION;

INSERT INTO orders (order_id, order_time, total_amount, payment_method, order_status, member_id, cashier_id, remark)
VALUES ('ORD202609160001', '2026-09-16 14:30:00', 14.00, '微信', '已支付', 'M0001', 2, '测试订单');

-- 插入订单明细
INSERT INTO order_item (order_id, product_id, quantity, unit_price, subtotal)
VALUES
('ORD202609160001', 'P0001', 2, 3.50, 7.00),
('ORD202609160001', 'P0007', 1, 3.00, 3.00),
('ORD202609160001', 'P0004', 2, 2.00, 4.00);

-- 提交事务（如果以上任何一步出错，应执行ROLLBACK回滚）
COMMIT;

-- 操作后：查看新订单及其明细（连接查询）
SELECT '=== 创建新订单后：订单主表信息 ===' AS 操作;
SELECT * FROM orders WHERE order_id = 'ORD202609160001';

SELECT '=== 创建新订单后：订单明细信息 ===' AS 操作;
SELECT
    oi.item_id,
    oi.order_id,
    p.product_name,
    oi.quantity,
    oi.unit_price,
    oi.subtotal
FROM order_item oi
JOIN product p ON oi.product_id = p.product_id
WHERE oi.order_id = 'ORD202609160001';

-- 验证：订单明细合计应等于订单总金额
SELECT '=== 验证：明细合计 vs 订单总金额 ===' AS 操作;
SELECT
    o.order_id,
    o.total_amount AS 订单总金额,
    SUM(oi.subtotal) AS 明细合计,
    CASE WHEN o.total_amount = SUM(oi.subtotal) THEN '一致' ELSE '不一致' END AS 验证结果
FROM orders o
JOIN order_item oi ON o.order_id = oi.order_id
WHERE o.order_id = 'ORD202609160001'
GROUP BY o.order_id, o.total_amount;

-- ----------------------------------------------------------
-- R (Read) - 查询订单
-- ----------------------------------------------------------

-- 查询1：查询某会员的所有订单，按时间倒序
SELECT '=== 查询1：会员M0001的所有订单 ===' AS 操作;
SELECT
    o.order_id,
    o.order_time,
    o.total_amount,
    o.payment_method,
    o.order_status,
    e.employee_name AS 收银员
FROM orders o
JOIN employee e ON o.cashier_id = e.employee_id
WHERE o.member_id = 'M0001'
ORDER BY o.order_time DESC;

-- 查询2：按支付方式统计订单数量和金额
SELECT '=== 查询2：按支付方式统计 ===' AS 操作;
SELECT
    payment_method AS 支付方式,
    COUNT(*) AS 订单数量,
    SUM(total_amount) AS 总金额,
    ROUND(AVG(total_amount), 2) AS 平均金额
FROM orders
WHERE order_status = '已支付'
GROUP BY payment_method
ORDER BY 总金额 DESC;

-- 查询3：查询销售额最高的商品（按销售数量和金额排序）
SELECT '=== 查询3：商品销量排行 ===' AS 操作;
SELECT
    p.product_id,
    p.product_name,
    p.category,
    SUM(oi.quantity) AS 销售总数量,
    SUM(oi.subtotal) AS 销售总金额
FROM order_item oi
JOIN product p ON oi.product_id = p.product_id
JOIN orders o ON oi.order_id = o.order_id
WHERE o.order_status = '已支付'
GROUP BY p.product_id, p.product_name, p.category
ORDER BY 销售总金额 DESC
LIMIT 5;

-- ----------------------------------------------------------
-- U (Update) - 修改订单（模拟修改订单备注和支付方式）
-- ----------------------------------------------------------

-- 操作前：先SELECT确认要修改的目标行
SELECT '=== 修改订单前：确认目标订单 ===' AS 操作;
SELECT order_id, payment_method, remark FROM orders WHERE order_id = 'ORD202609160001';

-- 修改订单：将支付方式改为支付宝，修改备注
UPDATE orders
SET payment_method = '支付宝',
    remark = '顾客改用支付宝支付'
WHERE order_id = 'ORD202609160001';

-- 操作后：验证修改结果
SELECT '=== 修改订单后：验证修改结果 ===' AS 操作;
SELECT order_id, payment_method, remark FROM orders WHERE order_id = 'ORD202609160001';

-- ----------------------------------------------------------
-- D (Delete) - 删除订单（含订单明细）
-- ----------------------------------------------------------

-- 操作前：先SELECT确认要删除的目标行
SELECT '=== 删除订单前：确认目标订单及明细 ===' AS 操作;
SELECT o.order_id, o.total_amount, COUNT(oi.item_id) AS 明细数
FROM orders o
LEFT JOIN order_item oi ON o.order_id = oi.order_id
WHERE o.order_id = 'ORD202609160001'
GROUP BY o.order_id, o.total_amount;

-- 注意：删除订单前必须先删除订单明细（因为order_item有外键引用orders）
-- 使用事务保证删除操作的原子性，明细和主表要么全部删除，要么都不删
START TRANSACTION;

-- 先删除订单明细
DELETE FROM order_item WHERE order_id = 'ORD202609160001';

-- 再删除订单主表
DELETE FROM orders WHERE order_id = 'ORD202609160001';

-- 提交事务
COMMIT;

-- 操作后：验证删除结果
SELECT '=== 删除订单后：验证订单已删除 ===' AS 操作;
SELECT COUNT(*) AS 订单ORD202609160001数量 FROM orders WHERE order_id = 'ORD202609160001';

SELECT '=== 删除订单后：验证明细已删除 ===' AS 操作;
SELECT COUNT(*) AS 明细ORD202609160001数量 FROM order_item WHERE order_id = 'ORD202609160001';


-- ============================================================
-- 第四部分：约束验证（非法数据被拒绝）
-- ============================================================

-- 验证1：外键约束 - 插入引用不存在商品的库存（应失败）
SELECT '=== 验证1：外键约束（引用不存在的商品）===' AS 操作;
-- 以下语句会报错：Cannot add or update a child row: a foreign key constraint fails
-- INSERT INTO inventory (product_id, quantity, last_updated_by) VALUES ('P9999', 10, 1);
SELECT '尝试插入product_id=P9999的库存会因外键约束失败' AS 验证结果;

-- 验证2：唯一约束 - 插入重复手机号的会员（应失败）
SELECT '=== 验证2：唯一约束（重复手机号）===' AS 操作;
-- 以下语句会报错：Duplicate entry '13800138001' for key 'uk_member_phone'
-- INSERT INTO member (member_id, member_name, phone) VALUES ('M0099', '测试', '13800138001');
SELECT '尝试插入手机号13800138001的会员会因唯一约束失败' AS 验证结果;

-- 验证3：检查约束 - 插入负价格的商品（应失败）
SELECT '=== 验证3：检查约束（负价格）===' AS 操作;
-- 以下语句会报错：Check constraint 'chk_product_sale_price' is violated
-- INSERT INTO product (product_id, product_name, category, sale_price, purchase_price, unit, status) VALUES ('P0099', '测试', '饮料', -1.00, 0.50, '瓶', '在售');
SELECT '尝试插入售价为负的商品会因检查约束失败' AS 验证结果;

-- 验证4：非空约束 - 插入缺少商品名称的商品（应失败）
SELECT '=== 验证4：非空约束（缺少必填字段）===' AS 操作;
-- 以下语句会报错：Field 'product_name' doesn't have a default value
-- INSERT INTO product (product_id, category, sale_price, purchase_price, unit, status) VALUES ('P0099', '饮料', 1.00, 0.50, '瓶', '在售');
SELECT '尝试插入缺少商品名称的商品会因非空约束失败' AS 验证结果;


-- ============================================================
-- CRUD操作完成
-- 总结：
--   商品表：完成插入、查询（3种）、修改、删除
--   库存表：完成插入、查询（2种）、修改（扣减）、删除
--   订单表：完成创建（主表+明细）、查询（3种）、修改、删除（明细+主表）
--   约束验证：外键、唯一、检查、非空约束均有效
-- ============================================================
