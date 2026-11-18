-- ============================================================
-- window_query.sql
-- 小卖部管理系统 v1.0 - 第11周 窗口函数查询
-- ============================================================
-- 交付三条查询：
--   1. 排名查询：RANK / DENSE_RANK / ROW_NUMBER
--   2. 累计值查询：按订单时间累计销售金额（明确排序字段）
--   3. 移动平均查询：最近 3 笔订单的平均金额（明确窗口范围）
--
-- 共性：窗口函数不减少原始行数，而是在每一行旁边增加统计结果。
-- 以 sa / db_owner 或有 SELECT 权限的账户执行；本文件为 UTF-8 with BOM。
-- ============================================================

USE retail_store;
GO

-- ============================================================
-- 查询 1：商品销售排名
-- 排名指标：销售数量 total_quantity、销售金额 total_amount、订单数量 order_count
-- 统计口径：仅计入“已支付 / 已完成”订单。
-- ============================================================
WITH product_sales AS (
    SELECT p.product_id,
           p.product_name,
           c.category_name,
           SUM(oi.quantity)               AS total_quantity,
           SUM(oi.subtotal)               AS total_amount,
           COUNT(DISTINCT oi.order_id)    AS order_count
    FROM dbo.product p
    LEFT JOIN dbo.category c ON c.category_id = p.category_id
    INNER JOIN dbo.order_item oi ON oi.product_id = p.product_id
    INNER JOIN dbo.orders o ON o.order_id = oi.order_id
    WHERE o.order_status IN ('已支付','已完成')
    GROUP BY p.product_id, p.product_name, c.category_name
)
SELECT product_id,
       product_name,
       category_name,
       total_quantity,
       total_amount,
       order_count,
       -- RANK：并列同名次，之后跳号（两个第 1，下一个为第 3）
       RANK()       OVER (ORDER BY total_quantity DESC)                       AS rank_by_qty,
       -- DENSE_RANK：并列不跳号（两个第 1，下一个仍为第 2）
       DENSE_RANK() OVER (ORDER BY total_amount DESC)                         AS dense_rank_by_amount,
       -- ROW_NUMBER：强制唯一序号，用 product_id 打破平局，保证结果确定
       ROW_NUMBER() OVER (ORDER BY order_count DESC, product_id ASC)           AS row_num_by_orders
FROM product_sales
ORDER BY rank_by_qty;
GO

-- 业务含义：
--   rank_by_qty 回答“卖得最多的商品排第几”，适合看销量榜；
--   dense_rank_by_amount 按销售额排名且不跳号，适合连续的金额榜；
--   row_num_by_orders 给出不重复的固定序号，适合做分页或 Top N 截取。

-- ============================================================
-- 查询 2：累计销售金额（按订单时间）
-- 排序字段：order_time, order_id（order_id 作为平局打破，保证顺序确定）
-- 窗口：从第一行到当前行（UNBOUNDED PRECEDING -> CURRENT ROW）
-- ============================================================
SELECT order_id,
       order_time,
       total_amount,
       SUM(total_amount) OVER (
           ORDER BY order_time, order_id
           ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
       ) AS cumulative_amount,
       COUNT(*) OVER (
           ORDER BY order_time, order_id
           ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
       ) AS cumulative_order_count
FROM dbo.orders
WHERE order_status IN ('已支付','已完成')
ORDER BY order_time, order_id;
GO

-- 业务含义：cumulative_amount 表示截至该笔订单时点的累计营业额，
-- 可用于观察销售额随时间的增长趋势；排序字段必须明确，否则累计值不确定。

-- 累计值的另一种口径（按商品顺序累计销量，需要时启用）：
-- SELECT product_id, product_name,
--        SUM(sale_price) OVER (ORDER BY product_id
--            ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS 累计参考售价
-- FROM dbo.product;

-- ============================================================
-- 查询 3：移动平均（最近 3 笔订单）
-- 窗口范围：当前行 + 前 2 行（2 PRECEDING -> CURRENT ROW），共 3 行
-- 开头不足 3 行时，按实际行数计算平均。
-- ============================================================
SELECT order_id,
       order_time,
       total_amount,
       AVG(total_amount) OVER (
           ORDER BY order_time, order_id
           ROWS BETWEEN 2 PRECEDING AND CURRENT ROW
       ) AS moving_avg_3_orders,
       MIN(total_amount) OVER (
           ORDER BY order_time, order_id
           ROWS BETWEEN 2 PRECEDING AND CURRENT ROW
       ) AS moving_min_3,
       MAX(total_amount) OVER (
           ORDER BY order_time, order_id
           ROWS BETWEEN 2 PRECEDING AND CURRENT ROW
       ) AS moving_max_3
FROM dbo.orders
WHERE order_status IN ('已支付','已完成')
ORDER BY order_time, order_id;
GO

-- 业务含义：moving_avg_3_orders 平滑了单笔订单的偶然波动，
-- 反映近期客单价水平，可用于判断最近经营是否异常。
-- 改“最近 3 天 / 3 个月”：把窗口改为按日期分组的自关联统计，
-- 例如按天汇总后再对“前 2 天到当天”求 AVG，窗口大小仍为 3。

PRINT 'window_query.sql 执行完成：排名、累计值、移动平均三类查询';
GO
