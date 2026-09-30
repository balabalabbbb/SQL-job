-- ============================================================
-- view.sql
-- 小卖部管理系统 - 统计视图创建与验证脚本
-- ============================================================
-- 执行说明：
--   1. 先执行 week3 的 01-03 脚本完成建库、建表、插数
--   2. 执行本脚本创建统计视图并验证
--   3. 视图封装了常用的复杂查询，便于重复使用
-- ============================================================

USE retail_store;

-- ============================================================
-- 视图1：订单详情视图 v_order_detail
-- 说明：整合订单主表、订单明细、商品、会员、收银员信息
-- 用途：查询任意订单的完整详情，无需每次写多表JOIN
-- ============================================================

DROP VIEW IF EXISTS v_order_detail;

CREATE VIEW v_order_detail AS
SELECT
    o.order_id          AS order_id,
    o.order_time        AS order_time,
    o.total_amount      AS order_total,
    o.payment_method    AS payment_method,
    o.order_status      AS order_status,
    o.remark            AS order_remark,
    m.member_id         AS member_id,
    m.member_name       AS member_name,
    m.member_level      AS member_level,
    e.employee_id       AS cashier_id,
    e.employee_name     AS cashier_name,
    oi.item_id          AS item_id,
    p.product_id        AS product_id,
    p.product_name      AS product_name,
    p.category          AS product_category,
    oi.quantity         AS quantity,
    oi.unit_price       AS unit_price,
    oi.subtotal         AS subtotal
FROM orders o
INNER JOIN order_item oi ON o.order_id = oi.order_id
INNER JOIN product p ON oi.product_id = p.product_id
LEFT JOIN member m ON o.member_id = m.member_id
INNER JOIN employee e ON o.cashier_id = e.employee_id;

-- 验证视图1：查询某订单详情
SELECT '=== 视图1验证：ORD202609150001订单详情 ===' AS 验证;
SELECT order_id, order_time, member_name, cashier_name, product_name, quantity, unit_price, subtotal
FROM v_order_detail
WHERE order_id = 'ORD202609150001'
ORDER BY item_id;


-- ============================================================
-- 视图2：商品销售统计视图 v_product_sales
-- 说明：统计每个商品的销售数量、销售金额、订单数
-- 用途：商品销量排行、销售分析，包含未销售商品（LEFT JOIN）
-- ============================================================

DROP VIEW IF EXISTS v_product_sales;

CREATE VIEW v_product_sales AS
SELECT
    p.product_id        AS product_id,
    p.product_name      AS product_name,
    p.category          AS category,
    p.sale_price        AS sale_price,
    p.purchase_price    AS purchase_price,
    p.status            AS product_status,
    COALESCE(sales.order_count, 0)   AS order_count,
    COALESCE(sales.total_quantity, 0) AS total_quantity,
    COALESCE(sales.total_amount, 0)   AS total_amount,
    COALESCE(sales.total_quantity, 0) * (p.sale_price - p.purchase_price) AS gross_profit
FROM product p
LEFT JOIN (
    SELECT
        product_id,
        COUNT(DISTINCT order_id) AS order_count,
        SUM(quantity) AS total_quantity,
        SUM(subtotal) AS total_amount
    FROM order_item
    GROUP BY product_id
) sales ON p.product_id = sales.product_id;

-- 验证视图2：商品销量排行TOP 5
SELECT '=== 视图2验证：商品销量排行TOP 5 ===' AS 验证;
SELECT product_name, category, total_quantity, total_amount, gross_profit
FROM v_product_sales
ORDER BY total_quantity DESC
LIMIT 5;

-- 验证视图2：未销售商品
SELECT '=== 视图2验证：从未销售的商品 ===' AS 验证;
SELECT product_name, category, sale_price, product_status
FROM v_product_sales
WHERE total_quantity = 0
ORDER BY product_id;


-- ============================================================
-- 视图3：库存状态视图 v_inventory_status
-- 说明：整合商品信息和库存信息，标注库存状态（正常/需补货/缺货）
-- 用途：库存预警、补货决策
-- ============================================================

DROP VIEW IF EXISTS v_inventory_status;

CREATE VIEW v_inventory_status AS
SELECT
    p.product_id            AS product_id,
    p.product_name          AS product_name,
    p.category              AS category,
    p.sale_price            AS sale_price,
    i.inventory_id          AS inventory_id,
    i.quantity              AS quantity,
    i.min_threshold         AS min_threshold,
    i.shelf_location        AS shelf_location,
    i.last_updated          AS last_updated,
    e.employee_name         AS last_updated_by,
    CASE
        WHEN i.quantity = 0 THEN '缺货'
        WHEN i.quantity < i.min_threshold THEN '需补货'
        ELSE '正常'
    END                     AS inventory_status,
    CASE
        WHEN i.quantity < i.min_threshold THEN i.min_threshold - i.quantity
        ELSE 0
    END                     AS shortage_qty,
    i.quantity * p.purchase_price AS inventory_cost_value,
    i.quantity * p.sale_price     AS inventory_retail_value
FROM product p
INNER JOIN inventory i ON p.product_id = i.product_id
LEFT JOIN employee e ON i.last_updated_by = e.employee_id;

-- 验证视图3：库存预警商品
SELECT '=== 视图3验证：库存预警商品（缺货/需补货）===' AS 验证;
SELECT product_name, category, quantity, min_threshold, inventory_status, shortage_qty, shelf_location
FROM v_inventory_status
WHERE inventory_status IN ('缺货', '需补货')
ORDER BY
    CASE inventory_status
        WHEN '缺货' THEN 1
        WHEN '需补货' THEN 2
        ELSE 3
    END,
    product_id;

-- 验证视图3：库存总价值
SELECT '=== 视图3验证：库存总价值统计 ===' AS 验证;
SELECT
    COUNT(*) AS 商品种类数,
    SUM(quantity) AS 库存总数量,
    ROUND(SUM(inventory_cost_value), 2) AS 库存进价总额,
    ROUND(SUM(inventory_retail_value), 2) AS 库存售价总额,
    ROUND(SUM(inventory_retail_value) - SUM(inventory_cost_value), 2) AS 库存毛利总额
FROM v_inventory_status;


-- ============================================================
-- 视图4：会员消费统计视图 v_member_sales
-- 说明：统计每个会员的消费次数、消费总额、平均消费
-- 用途：会员价值分析、会员等级评估
-- ============================================================

DROP VIEW IF EXISTS v_member_sales;

CREATE VIEW v_member_sales AS
SELECT
    m.member_id             AS member_id,
    m.member_name           AS member_name,
    m.phone                 AS phone,
    m.member_level          AS member_level,
    m.points_balance        AS points_balance,
    m.total_spent           AS total_spent_recorded,
    m.member_status         AS member_status,
    m.register_time         AS register_time,
    COUNT(o.order_id)       AS order_count,
    COALESCE(SUM(o.total_amount), 0) AS total_spent_calculated,
    COALESCE(AVG(o.total_amount), 0) AS avg_order_amount,
    MAX(o.order_time)       AS last_purchase_time,
    DATEDIFF(CURDATE(), MAX(o.order_time)) AS days_since_last_purchase
FROM member m
LEFT JOIN orders o ON m.member_id = o.member_id
GROUP BY m.member_id, m.member_name, m.phone, m.member_level,
         m.points_balance, m.total_spent, m.member_status, m.register_time;

-- 验证视图4：会员消费排行
SELECT '=== 视图4验证：会员消费排行 ===' AS 验证;
SELECT member_name, member_level, order_count, total_spent_calculated, avg_order_amount, last_purchase_time
FROM v_member_sales
ORDER BY total_spent_calculated DESC;

-- 验证视图4：高价值会员（消费>100）
SELECT '=== 视图4验证：高价值会员（消费>100元）===' AS 验证;
SELECT member_name, member_level, order_count, total_spent_calculated
FROM v_member_sales
WHERE total_spent_calculated > 100
ORDER BY total_spent_calculated DESC;


-- ============================================================
-- 视图5：员工销售业绩视图 v_employee_performance
-- 说明：统计每个员工的处理订单数、销售额、平均客单价
-- 用途：员工业绩考核、销售排行
-- ============================================================

DROP VIEW IF EXISTS v_employee_performance;

CREATE VIEW v_employee_performance AS
SELECT
    e.employee_id           AS employee_id,
    e.employee_name         AS employee_name,
    e.position              AS position,
    e.employee_status       AS employee_status,
    e.hire_date             AS hire_date,
    COUNT(o.order_id)       AS order_count,
    COALESCE(SUM(o.total_amount), 0) AS total_sales,
    COALESCE(AVG(o.total_amount), 0) AS avg_order_value,
    COALESCE(COUNT(DISTINCT o.member_id), 0) AS served_members,
    MIN(o.order_time)       AS first_order_time,
    MAX(o.order_time)       AS last_order_time
FROM employee e
LEFT JOIN orders o ON e.employee_id = o.cashier_id
GROUP BY e.employee_id, e.employee_name, e.position,
         e.employee_status, e.hire_date;

-- 验证视图5：员工销售业绩排行
SELECT '=== 视图5验证：员工销售业绩排行 ===' AS 验证;
SELECT employee_name, position, order_count, total_sales, avg_order_value
FROM v_employee_performance
ORDER BY total_sales DESC;


-- ============================================================
-- 视图6：每日销售汇总视图 v_daily_sales
-- 说明：按日期统计订单数、销售额、客单价
-- 用途：日报、销售趋势分析
-- ============================================================

DROP VIEW IF EXISTS v_daily_sales;

CREATE VIEW v_daily_sales AS
SELECT
    DATE(order_time)        AS sale_date,
    COUNT(*)                AS order_count,
    SUM(total_amount)       AS total_sales,
    AVG(total_amount)       AS avg_order_value,
    MIN(total_amount)       AS min_order_value,
    MAX(total_amount)       AS max_order_value,
    COUNT(DISTINCT member_id) AS member_order_count,
    SUM(CASE WHEN member_id IS NULL THEN 1 ELSE 0 END) AS guest_order_count
FROM orders
GROUP BY DATE(order_time);

-- 验证视图6：每日销售汇总
SELECT '=== 视图6验证：每日销售汇总 ===' AS 验证;
SELECT sale_date, order_count, total_sales, avg_order_value, member_order_count, guest_order_count
FROM v_daily_sales
ORDER BY sale_date;


-- ============================================================
-- 视图7：分类销售统计视图 v_category_sales
-- 说明：按商品分类统计销量、销售额、占比
-- 用途：品类分析、采购决策
-- ============================================================

DROP VIEW IF EXISTS v_category_sales;

CREATE VIEW v_category_sales AS
SELECT
    p.category              AS category,
    COUNT(DISTINCT p.product_id) AS product_count,
    COUNT(DISTINCT oi.order_id) AS order_count,
    COALESCE(SUM(oi.quantity), 0) AS total_quantity,
    COALESCE(SUM(oi.subtotal), 0) AS total_sales,
    COALESCE(AVG(oi.unit_price), 0) AS avg_unit_price,
    ROUND(
        COALESCE(SUM(oi.subtotal), 0) /
        NULLIF((SELECT SUM(subtotal) FROM order_item), 0) * 100,
        2
    )                       AS sales_percentage
FROM product p
LEFT JOIN order_item oi ON p.product_id = oi.product_id
GROUP BY p.category;

-- 验证视图7：分类销售统计
SELECT '=== 视图7验证：分类销售统计及占比 ===' AS 验证;
SELECT category, product_count, total_quantity, total_sales, sales_percentage
FROM v_category_sales
ORDER BY total_sales DESC;


-- ============================================================
-- 视图清单验证
-- ============================================================

SELECT '=== 已创建的视图清单 ===' AS 视图管理;
SELECT
    TABLE_NAME AS 视图名称,
    IS_UPDATABLE AS 是否可更新,
    DEFINER AS 定义者
FROM information_schema.VIEWS
WHERE TABLE_SCHEMA = 'retail_store'
ORDER BY TABLE_NAME;

-- ============================================================
-- 视图脚本执行完成
-- 共创建7个统计视图：
--   1. v_order_detail        - 订单详情视图
--   2. v_product_sales       - 商品销售统计视图
--   3. v_inventory_status    - 库存状态视图
--   4. v_member_sales        - 会员消费统计视图
--   5. v_employee_performance - 员工销售业绩视图
--   6. v_daily_sales         - 每日销售汇总视图
--   7. v_category_sales      - 分类销售统计视图
-- ============================================================
