-- ============================================================
-- 06_queries.sql
-- 小卖部管理系统 - 多表连接查询与统计分析脚本 (SQL Server 版本)
-- ============================================================
-- 执行说明：
--   1. 先执行 01-03 脚本完成建库、建表、插数
--   2. 执行本脚本进行各类查询演示
--   3. 覆盖：内连接、外连接、聚合、分组、子查询、排序、TOP等
-- ============================================================

USE retail_store;

-- ============================================================
-- 查询1：订单详情查询（多表内连接）
-- 说明：连接订单主表、订单明细、商品、会员、员工五张表
-- 用途：查看任意订单的完整信息，包括买了什么、谁买的、谁收的钱
-- ============================================================

SELECT '=== 查询1：订单详情（五表连接）===' AS 查询;

SELECT
    o.order_id          AS 订单号,
    o.order_time        AS 下单时间,
    m.member_name       AS 会员姓名,
    e.employee_name     AS 收银员,
    p.product_name      AS 商品名称,
    p.category          AS 商品分类,
    oi.quantity         AS 数量,
    oi.unit_price       AS 成交单价,
    oi.subtotal         AS 小计,
    o.total_amount      AS 订单总金额,
    o.payment_method    AS 支付方式,
    o.order_status      AS 订单状态
FROM orders o
INNER JOIN order_item oi ON o.order_id = oi.order_id
INNER JOIN product p ON oi.product_id = p.product_id
LEFT JOIN member m ON o.member_id = m.member_id
INNER JOIN employee e ON o.cashier_id = e.employee_id
ORDER BY o.order_time DESC, oi.item_id;


-- ============================================================
-- 查询2：按商品分类统计销售情况（聚合+分组+连接）
-- 说明：统计每个分类的销售数量、销售金额、商品种类数
-- 用途：品类分析，了解哪些品类卖得好
-- ============================================================

SELECT '=== 查询2：按商品分类统计销售 ===' AS 查询;

SELECT
    p.category                      AS 商品分类,
    COUNT(DISTINCT p.product_id)    AS 商品种类数,
    COUNT(DISTINCT o.order_id)      AS 订单数,
    SUM(oi.quantity)                AS 销售总数量,
    SUM(oi.subtotal)                AS 销售总金额,
    ROUND(AVG(oi.unit_price), 2)    AS 平均成交单价
FROM product p
LEFT JOIN order_item oi ON p.product_id = oi.product_id
LEFT JOIN orders o ON oi.order_id = o.order_id AND o.order_status = '已支付'
GROUP BY p.category
ORDER BY 销售总金额 DESC;


-- ============================================================
-- 查询3：会员消费排行（子查询+聚合）
-- 说明：统计每个会员的消费次数、消费总额、平均消费
-- 用途：会员价值分析，识别高价值客户
-- 注意：使用LEFT JOIN包含未消费的会员，COALESCE将NULL转为0
-- ============================================================

SELECT '=== 查询3：会员消费排行 ===' AS 查询;

SELECT
    m.member_id                             AS 会员ID,
    m.member_name                           AS 会员姓名,
    m.member_level                          AS 会员等级,
    COUNT(o.order_id)                       AS 订单数,
    COALESCE(SUM(o.total_amount), 0)        AS 消费总额,
    COALESCE(ROUND(AVG(o.total_amount), 2), 0) AS 平均消费,
    MAX(o.order_time)                       AS 最近消费时间
FROM member m
LEFT JOIN orders o ON m.member_id = o.member_id AND o.order_status = '已支付'
GROUP BY m.member_id, m.member_name, m.member_level
ORDER BY 消费总额 DESC;


-- ============================================================
-- 查询4：库存预警查询（连接+条件+计算列）
-- 说明：查询库存数量低于最低阈值的商品，计算缺口数量
-- 用途：补货提醒，防止缺货
-- ============================================================

SELECT '=== 查询4：库存预警商品 ===' AS 查询;

SELECT
    p.product_name              AS 商品名称,
    p.category                  AS 分类,
    i.quantity                  AS 当前库存,
    i.min_threshold             AS 最低阈值,
    (i.min_threshold - i.quantity) AS 缺口数量,
    i.shelf_location            AS 货架位置,
    CASE
        WHEN i.quantity = 0 THEN '严重缺货'
        WHEN i.quantity < i.min_threshold THEN '需要补货'
        ELSE '库存正常'
    END                         AS 库存状态
FROM inventory i
JOIN product p ON i.product_id = p.product_id
WHERE i.quantity < i.min_threshold
ORDER BY 缺口数量 DESC;


-- ============================================================
-- 查询5：员工销售业绩排行（连接+聚合+排序）
-- 说明：统计每个员工处理的订单数、销售额、平均客单价
-- 用途：员工业绩考核
-- ============================================================

SELECT '=== 查询5：员工销售业绩排行 ===' AS 查询;

SELECT
    e.employee_id                       AS 员工ID,
    e.employee_name                     AS 员工姓名,
    e.position                          AS 岗位,
    COUNT(o.order_id)                   AS 处理订单数,
    COALESCE(SUM(o.total_amount), 0)    AS 销售总额,
    COALESCE(ROUND(AVG(o.total_amount), 2), 0) AS 平均客单价,
    COUNT(DISTINCT o.member_id)         AS 服务会员数
FROM employee e
LEFT JOIN orders o ON e.employee_id = o.cashier_id AND o.order_status = '已支付'
GROUP BY e.employee_id, e.employee_name, e.position
ORDER BY 销售总额 DESC;


-- ============================================================
-- 查询6：每日销售趋势（日期函数+聚合）
-- 说明：按日期统计订单数、销售额、客单价
-- 用途：销售趋势分析，了解每日经营情况
-- ============================================================

SELECT '=== 查询6：每日销售趋势 ===' AS 查询;

SELECT
    CAST(o.order_time AS DATE)      AS 销售日期,
    COUNT(*)                        AS 订单数,
    SUM(o.total_amount)             AS 销售总额,
    ROUND(AVG(o.total_amount), 2)   AS 平均客单价,
    COUNT(DISTINCT o.member_id)     AS 会员订单数,
    SUM(CASE WHEN o.member_id IS NULL THEN 1 ELSE 0 END) AS 散客订单数
FROM orders o
WHERE o.order_status = '已支付'
GROUP BY CAST(o.order_time AS DATE)
ORDER BY 销售日期;


-- ============================================================
-- 查询7：商品销量排行 TOP 5（TOP+聚合+连接）
-- 说明：统计销量最高的前5个商品
-- 用途：畅销商品分析，优化进货策略
-- ============================================================

SELECT '=== 查询7：商品销量排行 TOP 5 ===' AS 查询;

SELECT TOP 5
    p.product_id        AS 商品ID,
    p.product_name      AS 商品名称,
    p.category          AS 分类,
    SUM(oi.quantity)    AS 销售总数量,
    SUM(oi.subtotal)    AS 销售总金额,
    COUNT(DISTINCT oi.order_id) AS 出现订单数
FROM product p
JOIN order_item oi ON p.product_id = oi.product_id
JOIN orders o ON oi.order_id = o.order_id
WHERE o.order_status = '已支付'
GROUP BY p.product_id, p.product_name, p.category
ORDER BY 销售总数量 DESC;


-- ============================================================
-- 查询8：会员注册时长与消费关联分析（日期函数+子查询）
-- 说明：计算每个会员的注册天数，并分析注册时长与消费的关系
-- 用途：了解新老会员的消费差异
-- ============================================================

SELECT '=== 查询8：会员注册时长与消费分析 ===' AS 查询;

SELECT
    m.member_name                                       AS 会员姓名,
    m.member_level                                      AS 等级,
    DATEDIFF(day, m.register_time, GETDATE())           AS 注册天数,
    COALESCE(SUM(o.total_amount), 0)                    AS 累计消费,
    CASE
        WHEN DATEDIFF(day, m.register_time, GETDATE()) < 90 THEN '新会员(3个月内)'
        WHEN DATEDIFF(day, m.register_time, GETDATE()) < 180 THEN '中期会员(3-6个月)'
        ELSE '老会员(6个月以上)'
    END                                                 AS 会员阶段
FROM member m
LEFT JOIN orders o ON m.member_id = o.member_id AND o.order_status = '已支付'
GROUP BY m.member_name, m.member_level, m.register_time
ORDER BY 注册天数 DESC;


-- ============================================================
-- 查询9：每个订单包含的商品列表（字符串聚合）
-- 说明：将每个订单的商品名称合并为一个字符串
-- 用途：快速查看订单内容，SQL Server用STRING_AGG
-- ============================================================

SELECT '=== 查询9：每个订单的商品列表 ===' AS 查询;

SELECT
    o.order_id                  AS 订单号,
    o.order_time                AS 下单时间,
    o.total_amount              AS 总金额,
    STRING_AGG(p.product_name, '、') AS 商品列表
FROM orders o
JOIN order_item oi ON o.order_id = oi.order_id
JOIN product p ON oi.product_id = p.product_id
GROUP BY o.order_id, o.order_time, o.total_amount
ORDER BY o.order_time DESC;


-- ============================================================
-- 查询10：从未被购买过的商品（左外连接+NULL判断）
-- 说明：查询在order_item中没有出现过的商品
-- 用途：滞销商品分析，考虑促销或下架
-- ============================================================

SELECT '=== 查询10：从未被购买的商品 ===' AS 查询;

SELECT
    p.product_id        AS 商品ID,
    p.product_name      AS 商品名称,
    p.category          AS 分类,
    p.sale_price        AS 售价,
    p.status            AS 状态,
    i.quantity          AS 库存数量
FROM product p
LEFT JOIN order_item oi ON p.product_id = oi.product_id
LEFT JOIN inventory i ON p.product_id = i.product_id
WHERE oi.product_id IS NULL
ORDER BY p.product_id;


-- ============================================================
-- 查询11：高价值会员的详细消费记录（子查询作为过滤条件）
-- 说明：先找出消费总额超过100元的会员，再查询他们的订单明细
-- 用途：精准营销，针对高价值客户
-- ============================================================

SELECT '=== 查询11：高价值会员（消费>100元）的消费明细 ===' AS 查询;

SELECT
    m.member_name       AS 会员姓名,
    m.member_level      AS 等级,
    o.order_id          AS 订单号,
    o.order_time        AS 下单时间,
    p.product_name      AS 商品名称,
    oi.quantity         AS 数量,
    oi.subtotal         AS 小计
FROM member m
JOIN orders o ON m.member_id = o.member_id
JOIN order_item oi ON o.order_id = oi.order_id
JOIN product p ON oi.product_id = p.product_id
WHERE m.member_id IN (
    SELECT member_id
    FROM orders
    WHERE order_status = '已支付'
    GROUP BY member_id
    HAVING SUM(total_amount) > 100
)
AND o.order_status = '已支付'
ORDER BY m.member_name, o.order_time;


-- ============================================================
-- 查询12：商品毛利分析（计算列+连接）
-- 说明：计算每个商品的毛利和毛利率，按毛利排序
-- 用途：利润分析，优化商品结构
-- ============================================================

SELECT '=== 查询12：商品毛利分析 ===' AS 查询;

SELECT
    p.product_id                            AS 商品ID,
    p.product_name                          AS 商品名称,
    p.category                              AS 分类,
    p.purchase_price                        AS 进价,
    p.sale_price                            AS 售价,
    (p.sale_price - p.purchase_price)       AS 单件毛利,
    ROUND((p.sale_price - p.purchase_price) / p.sale_price * 100, 2) AS 毛利率百分比,
    COALESCE(SUM(oi.quantity), 0)           AS 累计销量,
    COALESCE(SUM(oi.quantity) * (p.sale_price - p.purchase_price), 0) AS 累计毛利
FROM product p
LEFT JOIN order_item oi ON p.product_id = oi.product_id
LEFT JOIN orders o ON oi.order_id = o.order_id AND o.order_status = '已支付'
GROUP BY p.product_id, p.product_name, p.category, p.purchase_price, p.sale_price
ORDER BY 累计毛利 DESC;


-- ============================================================
-- 查询13：收银员的工作效率分析（多维度聚合）
-- 说明：统计每个收银员的订单处理量、服务会员数、不同支付方式占比
-- 用途：员工排班和绩效考核参考
-- ============================================================

SELECT '=== 查询13：收银员工作效率分析 ===' AS 查询;

SELECT
    e.employee_name                                 AS 收银员,
    COUNT(o.order_id)                               AS 总订单数,
    COUNT(DISTINCT o.member_id)                     AS 服务会员数,
    SUM(CASE WHEN o.payment_method = '微信' THEN 1 ELSE 0 END)   AS 微信支付数,
    SUM(CASE WHEN o.payment_method = '支付宝' THEN 1 ELSE 0 END) AS 支付宝数,
    SUM(CASE WHEN o.payment_method = '现金' THEN 1 ELSE 0 END)   AS 现金支付数,
    SUM(CASE WHEN o.order_status = '已退款' THEN 1 ELSE 0 END)   AS 退款订单数
FROM employee e
LEFT JOIN orders o ON e.employee_id = o.cashier_id
WHERE e.position = '店员'
GROUP BY e.employee_name
ORDER BY 总订单数 DESC;


-- ============================================================
-- 查询14：库存周转率分析（连接+子查询+计算）
-- 说明：计算每个商品的销售数量与当前库存的比率
-- 用途：库存周转分析，识别积压和畅销商品
-- ============================================================

SELECT '=== 查询14：库存周转率分析 ===' AS 查询;

SELECT
    p.product_name                          AS 商品名称,
    i.quantity                              AS 当前库存,
    COALESCE(sales.total_qty, 0)            AS 累计销量,
    CASE
        WHEN i.quantity > 0 THEN ROUND(CAST(COALESCE(sales.total_qty, 0) AS DECIMAL(10,2)) / i.quantity, 2)
        ELSE NULL
    END                                     AS 库存周转率,
    CASE
        WHEN i.quantity = 0 THEN '缺货'
        WHEN COALESCE(sales.total_qty, 0) = 0 THEN '滞销(零销量)'
        WHEN i.quantity > COALESCE(sales.total_qty, 0) * 2 THEN '库存积压'
        ELSE '周转正常'
    END                                     AS 周转状态
FROM product p
JOIN inventory i ON p.product_id = i.product_id
LEFT JOIN (
    SELECT product_id, SUM(quantity) AS total_qty
    FROM order_item oi
    JOIN orders o ON oi.order_id = o.order_id
    WHERE o.order_status = '已支付'
    GROUP BY product_id
) sales ON p.product_id = sales.product_id
ORDER BY 库存周转率 DESC;


-- ============================================================
-- 查询15：会员等级分布与消费贡献（分组+占比计算）
-- 说明：统计各等级会员的人数、消费总额、消费占比
-- 用途：会员体系效果评估
-- ============================================================

SELECT '=== 查询15：会员等级分布与消费贡献 ===' AS 查询;

SELECT
    m.member_level                                  AS 会员等级,
    COUNT(*)                                        AS 会员人数,
    COALESCE(SUM(o.total_amount), 0)                AS 消费总额,
    ROUND(
        CAST(COUNT(*) AS DECIMAL(10,2)) /
        (SELECT COUNT(*) FROM member) * 100,
        2
    )                                               AS 人数占比百分比,
    ROUND(
        COALESCE(SUM(o.total_amount), 0) /
        NULLIF((SELECT SUM(total_amount) FROM orders WHERE order_status = '已支付' AND member_id IS NOT NULL), 0) * 100,
        2
    )                                               AS 消费占比百分比
FROM member m
LEFT JOIN orders o ON m.member_id = o.member_id AND o.order_status = '已支付'
GROUP BY m.member_level
ORDER BY 消费总额 DESC;


-- ============================================================
-- 查询16：当日销售实时统计（模拟）
-- 说明：统计今天的订单数、销售额、热销商品
-- 用途：店长日常经营监控
-- ============================================================

SELECT '=== 查询16：当日销售统计（模拟，样例数据中为9月15日）===' AS 查询;

-- 当日订单概览
SELECT
    COUNT(*)                        AS 当日订单数,
    SUM(total_amount)               AS 当日销售额,
    ROUND(AVG(total_amount), 2)     AS 当日客单价,
    COUNT(DISTINCT member_id)       AS 当日会员数
FROM orders
WHERE CAST(order_time AS DATE) = '2026-09-15'
  AND order_status = '已支付';

-- 当日热销商品 TOP 3
SELECT '=== 当日热销商品 TOP 3 ===' AS 子查询;

SELECT TOP 3
    p.product_name      AS 商品名称,
    SUM(oi.quantity)    AS 销售数量,
    SUM(oi.subtotal)    AS 销售金额
FROM orders o
JOIN order_item oi ON o.order_id = oi.order_id
JOIN product p ON oi.product_id = p.product_id
WHERE CAST(o.order_time AS DATE) = '2026-09-15'
  AND o.order_status = '已支付'
GROUP BY p.product_name
ORDER BY 销售数量 DESC;

-- ============================================================
-- 所有查询执行完成
-- 共16个查询，覆盖：
--   - 多表连接（内连接、左外连接）
--   - 聚合统计（SUM、COUNT、AVG、MAX、MIN）
--   - 分组（GROUP BY）
--   - 子查询（IN、作为派生表）
--   - 排序（ORDER BY）
--   - TOP 限制
--   - 日期函数（CAST AS DATE、DATEDIFF、GETDATE）
--   - 字符串聚合（STRING_AGG）
--   - 条件表达式（CASE WHEN）
--   - 计算列（毛利、周转率、占比）
-- ============================================================
