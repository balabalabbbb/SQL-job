-- ============================================================
-- query.sql
-- 小卖部管理系统 - 多表查询与统计查询脚本
-- ============================================================
-- 执行说明：
--   1. 先执行 week3 的 01-03 脚本完成建库、建表、插数
--   2. 执行本脚本进行多表查询和统计查询
--   3. 每个查询都有明确的业务问题说明
-- ============================================================

USE retail_store;

-- ============================================================
-- 第一部分：多表连接查询（INNER JOIN / LEFT JOIN）
-- ============================================================

-- ----------------------------------------------------------
-- 查询1：订单完整详情（订单主表 + 订单明细 + 商品 + 会员 + 收银员）
-- 业务问题：某一笔订单的完整信息是什么？买了什么商品？谁买的？谁收的款？
-- 连接方式：orders INNER JOIN order_item INNER JOIN product
--           LEFT JOIN member（非会员订单member_id为NULL）
--           INNER JOIN employee（收银员）
-- ----------------------------------------------------------
SELECT '=== 查询1：订单完整详情（ORD202609150001）===' AS 业务查询;

SELECT
    o.order_id          AS 订单编号,
    o.order_time        AS 下单时间,
    o.total_amount      AS 订单总金额,
    o.payment_method    AS 支付方式,
    o.order_status      AS 订单状态,
    m.member_name       AS 会员姓名,
    m.member_level      AS 会员等级,
    e.employee_name     AS 收银员,
    p.product_name      AS 商品名称,
    p.category          AS 商品分类,
    oi.quantity         AS 购买数量,
    oi.unit_price       AS 成交单价,
    oi.subtotal         AS 小计金额
FROM orders o
INNER JOIN order_item oi ON o.order_id = oi.order_id
INNER JOIN product p ON oi.product_id = p.product_id
LEFT JOIN member m ON o.member_id = m.member_id
INNER JOIN employee e ON o.cashier_id = e.employee_id
WHERE o.order_id = 'ORD202609150001'
ORDER BY oi.item_id;


-- ----------------------------------------------------------
-- 查询2：所有订单及其会员信息（含非会员订单）
-- 业务问题：所有订单分别是哪些顾客下的？会员和非会员各占多少？
-- 连接方式：orders LEFT JOIN member
-- 说明：使用LEFT JOIN因为非会员订单的member_id为NULL
-- ----------------------------------------------------------
SELECT '=== 查询2：所有订单及会员信息（含非会员）===' AS 业务查询;

SELECT
    o.order_id          AS 订单编号,
    o.order_time        AS 下单时间,
    o.total_amount      AS 订单金额,
    o.payment_method    AS 支付方式,
    CASE
        WHEN m.member_id IS NULL THEN '非会员顾客'
        ELSE CONCAT(m.member_name, '(', m.member_level, ')')
    END                 AS 顾客信息
FROM orders o
LEFT JOIN member m ON o.member_id = m.member_id
ORDER BY o.order_time;


-- ----------------------------------------------------------
-- 查询3：商品库存状态（商品 + 库存）
-- 业务问题：每个商品的当前库存是多少？是否低于预警阈值？
-- 连接方式：product INNER JOIN inventory
-- ----------------------------------------------------------
SELECT '=== 查询3：商品库存状态及预警 ===' AS 业务查询;

SELECT
    p.product_id        AS 商品编号,
    p.product_name      AS 商品名称,
    p.category          AS 分类,
    p.sale_price        AS 售价,
    i.quantity          AS 当前库存,
    i.min_threshold     AS 预警阈值,
    i.shelf_location    AS 货架位置,
    CASE
        WHEN i.quantity = 0 THEN '缺货'
        WHEN i.quantity < i.min_threshold THEN '需补货'
        ELSE '正常'
    END                 AS 库存状态,
    CASE
        WHEN i.quantity < i.min_threshold THEN i.min_threshold - i.quantity
        ELSE 0
    END                 AS 缺口数量
FROM product p
INNER JOIN inventory i ON p.product_id = i.product_id
ORDER BY
    CASE
        WHEN i.quantity = 0 THEN 1
        WHEN i.quantity < i.min_threshold THEN 2
        ELSE 3
    END,
    p.product_id;


-- ----------------------------------------------------------
-- 查询4：员工销售业绩（员工 + 订单）
-- 业务问题：每个收银员的销售业绩如何？处理了多少订单？总销售额多少？
-- 连接方式：employee LEFT JOIN orders
-- 说明：使用LEFT JOIN因为可能有员工没有处理订单
-- ----------------------------------------------------------
SELECT '=== 查询4：员工销售业绩 ===' AS 业务查询;

SELECT
    e.employee_id       AS 员工编号,
    e.employee_name     AS 员工姓名,
    e.position          AS 岗位,
    e.employee_status   AS 状态,
    COUNT(o.order_id)   AS 处理订单数,
    COALESCE(SUM(o.total_amount), 0) AS 销售总额,
    COALESCE(AVG(o.total_amount), 0) AS 平均客单价
FROM employee e
LEFT JOIN orders o ON e.employee_id = o.cashier_id
GROUP BY e.employee_id, e.employee_name, e.position, e.employee_status
ORDER BY 销售总额 DESC;


-- ============================================================
-- 第二部分：聚合统计查询（GROUP BY / HAVING / 聚合函数）
-- ============================================================

-- ----------------------------------------------------------
-- 查询5：按商品分类统计销售情况
-- 业务问题：哪个分类卖得最好？销量和销售额各是多少？
-- 聚合：SUM, COUNT, GROUP BY, ORDER BY
-- ----------------------------------------------------------
SELECT '=== 查询5：按商品分类统计销售情况 ===' AS 业务查询;

SELECT
    p.category          AS 商品分类,
    COUNT(DISTINCT oi.order_id) AS 订单笔数,
    SUM(oi.quantity)    AS 销售总数量,
    SUM(oi.subtotal)    AS 销售总金额,
    AVG(oi.unit_price)  AS 平均成交单价,
    ROUND(SUM(oi.subtotal) / SUM(oi.quantity), 2) AS 件均价
FROM order_item oi
INNER JOIN product p ON oi.product_id = p.product_id
GROUP BY p.category
ORDER BY 销售总金额 DESC;


-- ----------------------------------------------------------
-- 查询6：商品销量排行榜（TOP 5）
-- 业务问题：销量最高的前5个商品是什么？
-- 聚合：SUM, GROUP BY, ORDER BY DESC, LIMIT
-- ----------------------------------------------------------
SELECT '=== 查询6：商品销量排行榜 TOP 5 ===' AS 业务查询;

SELECT
    p.product_id        AS 商品编号,
    p.product_name      AS 商品名称,
    p.category          AS 分类,
    SUM(oi.quantity)    AS 销售总数量,
    SUM(oi.subtotal)    AS 销售总金额
FROM order_item oi
INNER JOIN product p ON oi.product_id = p.product_id
GROUP BY p.product_id, p.product_name, p.category
ORDER BY 销售总数量 DESC
LIMIT 5;


-- ----------------------------------------------------------
-- 查询7：会员消费统计（HAVING筛选）
-- 业务问题：消费总额超过100元的会员有哪些？
-- 聚合：SUM, GROUP BY, HAVING
-- ----------------------------------------------------------
SELECT '=== 查询7：消费总额超过100元的会员 ===' AS 业务查询;

SELECT
    m.member_id         AS 会员编号,
    m.member_name       AS 会员姓名,
    m.member_level      AS 会员等级,
    m.points_balance    AS 当前积分,
    COUNT(o.order_id)   AS 消费次数,
    SUM(o.total_amount) AS 消费总额,
    AVG(o.total_amount) AS 平均消费
FROM member m
INNER JOIN orders o ON m.member_id = o.member_id
GROUP BY m.member_id, m.member_name, m.member_level, m.points_balance
HAVING SUM(o.total_amount) > 100
ORDER BY 消费总额 DESC;


-- ----------------------------------------------------------
-- 查询8：按支付方式统计订单
-- 业务问题：各种支付方式的使用情况如何？
-- 聚合：COUNT, SUM, AVG, GROUP BY
-- ----------------------------------------------------------
SELECT '=== 查询8：按支付方式统计订单 ===' AS 业务查询;

SELECT
    payment_method      AS 支付方式,
    COUNT(*)            AS 订单数量,
    SUM(total_amount)   AS 总金额,
    AVG(total_amount)   AS 平均金额,
    MIN(total_amount)   AS 最小金额,
    MAX(total_amount)   AS 最大金额
FROM orders
GROUP BY payment_method
ORDER BY 订单数量 DESC;


-- ----------------------------------------------------------
-- 查询9：按日期统计每日销售
-- 业务问题：每天的销售额是多少？哪天最高？
-- 聚合：DATE(), SUM, COUNT, GROUP BY
-- ----------------------------------------------------------
SELECT '=== 查询9：按日期统计每日销售 ===' AS 业务查询;

SELECT
    DATE(order_time)    AS 销售日期,
    COUNT(*)            AS 订单数量,
    SUM(total_amount)   AS 销售总额,
    AVG(total_amount)   AS 平均客单价
FROM orders
GROUP BY DATE(order_time)
ORDER BY 销售日期;


-- ============================================================
-- 第三部分：子查询
-- ============================================================

-- ----------------------------------------------------------
-- 查询10：销量高于平均水平的商品
-- 业务问题：哪些商品的销量高于所有商品的平均销量？
-- 子查询：FROM子句中的聚合子查询
-- ----------------------------------------------------------
SELECT '=== 查询10：销量高于平均水平的商品 ===' AS 业务查询;

SELECT
    p.product_name      AS 商品名称,
    p.category          AS 分类,
    sales.total_qty     AS 销售数量,
    avg_sales.avg_qty   AS 平均销量
FROM (
    SELECT product_id, SUM(quantity) AS total_qty
    FROM order_item
    GROUP BY product_id
) sales
INNER JOIN product p ON sales.product_id = p.product_id
CROSS JOIN (
    SELECT AVG(total_qty) AS avg_qty
    FROM (
        SELECT SUM(quantity) AS total_qty
        FROM order_item
        GROUP BY product_id
    ) t
) avg_sales
WHERE sales.total_qty > avg_sales.avg_qty
ORDER BY sales.total_qty DESC;


-- ----------------------------------------------------------
-- 查询11：从未被购买过的商品
-- 业务问题：哪些商品从来没有被卖出过？
-- 子查询：NOT IN 子查询
-- ----------------------------------------------------------
SELECT '=== 查询11：从未被购买过的商品 ===' AS 业务查询;

SELECT
    product_id          AS 商品编号,
    product_name        AS 商品名称,
    category            AS 分类,
    sale_price          AS 售价,
    status              AS 状态
FROM product
WHERE product_id NOT IN (
    SELECT DISTINCT product_id
    FROM order_item
)
ORDER BY product_id;


-- ----------------------------------------------------------
-- 查询12：每个分类中售价最高的商品
-- 业务问题：每个分类中最贵的商品是什么？
-- 子查询：关联子查询（ correlated subquery ）
-- ----------------------------------------------------------
SELECT '=== 查询12：每个分类中售价最高的商品 ===' AS 业务查询;

SELECT
    p1.category         AS 分类,
    p1.product_name     AS 商品名称,
    p1.sale_price       AS 最高售价
FROM product p1
WHERE p1.sale_price = (
    SELECT MAX(p2.sale_price)
    FROM product p2
    WHERE p2.category = p1.category
)
ORDER BY p1.category;


-- ----------------------------------------------------------
-- 查询13：会员最近一次消费信息
-- 业务问题：每个会员最近一次消费是什么时候？花了多少钱？
-- 子查询：IN + 最大时间子查询
-- ----------------------------------------------------------
SELECT '=== 查询13：会员最近一次消费信息 ===' AS 业务查询;

SELECT
    m.member_name       AS 会员姓名,
    m.member_level      AS 等级,
    o.order_id          AS 最近订单号,
    o.order_time        AS 最近消费时间,
    o.total_amount      AS 消费金额
FROM member m
INNER JOIN orders o ON m.member_id = o.member_id
WHERE (o.member_id, o.order_time) IN (
    SELECT member_id, MAX(order_time)
    FROM orders
    WHERE member_id IS NOT NULL
    GROUP BY member_id
)
ORDER BY o.order_time DESC;


-- ----------------------------------------------------------
-- 查询14：库存价值分析（子查询计算总价值）
-- 业务问题：库存总价值是多少？各分类占比如何？
-- 子查询：计算总值作为分母
-- ----------------------------------------------------------
SELECT '=== 查询14：库存价值分类占比 ===' AS 业务查询;

SELECT
    p.category          AS 分类,
    COUNT(*)            AS 商品种类数,
    SUM(i.quantity)     AS 库存总数量,
    SUM(i.quantity * p.purchase_price) AS 库存进价总额,
    SUM(i.quantity * p.sale_price)     AS 库存售价总额,
    ROUND(
        SUM(i.quantity * p.sale_price) /
        (SELECT SUM(i2.quantity * p2.sale_price)
         FROM inventory i2
         INNER JOIN product p2 ON i2.product_id = p2.product_id) * 100,
        2
    )                   AS 售价占比百分比
FROM inventory i
INNER JOIN product p ON i.product_id = p.product_id
GROUP BY p.category
ORDER BY 库存售价总额 DESC;


-- ============================================================
-- 第四部分：综合业务查询
-- ============================================================

-- ----------------------------------------------------------
-- 查询15：商品毛利分析
-- 业务问题：每个商品的毛利率是多少？总毛利是多少？
-- 计算：毛利 = 售价 - 进价，毛利率 = 毛利 / 售价 * 100%
-- ----------------------------------------------------------
SELECT '=== 查询15：商品毛利分析 ===' AS 业务查询;

SELECT
    p.product_id        AS 商品编号,
    p.product_name      AS 商品名称,
    p.category          AS 分类,
    p.purchase_price    AS 进价,
    p.sale_price        AS 售价,
    (p.sale_price - p.purchase_price) AS 单位毛利,
    ROUND((p.sale_price - p.purchase_price) / p.sale_price * 100, 2) AS 毛利率百分比,
    COALESCE(sales.total_qty, 0) AS 已售数量,
    COALESCE(sales.total_qty, 0) * (p.sale_price - p.purchase_price) AS 已实现毛利
FROM product p
LEFT JOIN (
    SELECT product_id, SUM(quantity) AS total_qty
    FROM order_item
    GROUP BY product_id
) sales ON p.product_id = sales.product_id
ORDER BY 毛利率百分比 DESC;


-- ----------------------------------------------------------
-- 查询16：会员等级价值分析
-- 业务问题：不同等级会员的人均消费是多少？哪个等级价值最高？
-- 多表连接 + 聚合 + 计算
-- ----------------------------------------------------------
SELECT '=== 查询16：会员等级价值分析 ===' AS 业务查询;

SELECT
    m.member_level      AS 会员等级,
    COUNT(*)            AS 会员人数,
    COUNT(o.order_id)   AS 总订单数,
    COALESCE(SUM(o.total_amount), 0) AS 总消费额,
    COALESCE(AVG(o.total_amount), 0) AS 平均客单价,
    COALESCE(SUM(o.total_amount) / COUNT(DISTINCT m.member_id), 0) AS 人均消费
FROM member m
LEFT JOIN orders o ON m.member_id = o.member_id
GROUP BY m.member_level
ORDER BY 人均消费 DESC;


-- ============================================================
-- 查询脚本执行完成
-- 共16个查询，覆盖：
--   - 多表连接（INNER JOIN, LEFT JOIN, CROSS JOIN）
--   - 聚合统计（GROUP BY, HAVING, 聚合函数）
--   - 子查询（NOT IN, 关联子查询, FROM子查询）
--   - 综合业务分析（毛利, 会员价值, 库存占比）
-- ============================================================
