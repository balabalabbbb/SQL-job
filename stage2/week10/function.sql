-- ============================================================
-- function.sql
-- 小卖部管理系统 v1.0 - 第10周 函数 (SQL Server)
-- ============================================================
-- 包含：
--   1. dbo.fn_restock_qty            补货量标量函数
--   2. dbo.fn_sales_summary          销售汇总内联表值函数（可在 SELECT 中调用）
--   3. dbo.fn_discount_rate          折扣率标量函数（会员身份 + 订单金额）
--   4. dbo.fn_discount_amount        折扣金额标量函数
--   5. dbo.fn_category_discount_rate 商品分类折扣标量函数
--
-- 说明：SQL Server 函数内不能使用 TRY...CATCH / THROW / RAISERROR，
--       因此对"商品不存在、非法折扣"等异常统一返回 NULL，由调用方明确处理。
-- ============================================================

USE retail_store;
GO

-- ------------------------------------------------------------
-- 函数 1：补货量（标量）
-- 输入：@product_id 商品编号，@target_qty 目标库存（可空）
-- 规则：未传目标库存时，目标 = 最低阈值 × 2；
--       已达到目标返回 0，否则补到目标；商品/库存不存在返回 NULL。
--       所有成功返回值均 >= 0。
-- ------------------------------------------------------------
CREATE OR ALTER FUNCTION dbo.fn_restock_qty(
    @product_id  VARCHAR(10),
    @target_qty  INT = NULL
)
RETURNS INT
AS
BEGIN
    DECLARE @qty INT, @min INT;

    SELECT @qty = quantity, @min = min_threshold
    FROM dbo.inventory
    WHERE product_id = @product_id;

    -- 商品或库存记录不存在：返回 NULL 明确标识
    IF @qty IS NULL
        RETURN NULL;

    -- 目标库存：未显式传入时取最低阈值的 2 倍
    DECLARE @target INT = ISNULL(@target_qty, @min * 2);
    IF @target < 0
        SET @target = 0;

    -- 已达到目标返回 0；否则补到目标，差值恒为非负
    IF @qty >= @target
        RETURN 0;
    RETURN @target - @qty;
END;
GO

-- ------------------------------------------------------------
-- 函数 2：销售汇总（内联表值函数）
-- 输入：@start_date 开始日期，@end_date 结束日期（均含当天）
-- 输出：商品编号、商品名称、销售数量、销售金额、订单数量
-- 用法：SELECT * FROM dbo.fn_sales_summary('2026-09-01','2026-09-30');
-- ------------------------------------------------------------
CREATE OR ALTER FUNCTION dbo.fn_sales_summary(
    @start_date DATE,
    @end_date   DATE
)
RETURNS TABLE
AS
RETURN (
    SELECT
        p.product_id,
        p.product_name,
        ISNULL(SUM(oi.quantity), 0) AS sales_qty,
        ISNULL(SUM(oi.subtotal), 0) AS sales_amount,
        COUNT(DISTINCT o.order_id)  AS order_count
    FROM dbo.product p
    LEFT JOIN dbo.order_item oi ON oi.product_id = p.product_id
    LEFT JOIN dbo.orders o
           ON o.order_id = oi.order_id
          AND o.order_time >= @start_date
          AND o.order_time <  DATEADD(DAY, 1, @end_date)
          AND o.order_status = N'已支付'
    GROUP BY p.product_id, p.product_name
);
GO

-- ------------------------------------------------------------
-- 函数 3：折扣率（标量）
-- 输入：@member_id 会员编号（可空=散客），@original_amount 折前金额
-- 规则：会员等级折扣（钻石85/金卡90/银卡95/普通100）
--       与金额门槛折扣（满200再90、满100再95）取更优惠者；
--       冻结会员不享受折扣；会员不存在返回 NULL。
-- ------------------------------------------------------------
CREATE OR ALTER FUNCTION dbo.fn_discount_rate(
    @member_id       VARCHAR(10),
    @original_amount DECIMAL(10,2)
)
RETURNS DECIMAL(4,3)
AS
BEGIN
    DECLARE @level VARCHAR(10), @status VARCHAR(10);
    DECLARE @rate DECIMAL(4,3) = 1.000;

    IF @member_id IS NULL
    BEGIN
        -- 非会员散客：无会员折扣
        SET @rate = 1.000;
    END
    ELSE
    BEGIN
        SELECT @level = member_level, @status = member_status
        FROM dbo.member
        WHERE member_id = @member_id;

        IF @level IS NULL
            RETURN NULL;                          -- 会员不存在：明确处理

        IF @status = N'冻结'
            SET @rate = 1.000;                   -- 冻结会员不享受折扣
        ELSE
            SET @rate = CASE @level
                            WHEN N'钻石' THEN 0.850
                            WHEN N'金卡' THEN 0.900
                            WHEN N'银卡' THEN 0.950
                            ELSE 1.000            -- 普通会员
                        END;
    END;

    -- 订单金额门槛折扣
    DECLARE @amount_rate DECIMAL(4,3) = 1.000;
    IF @original_amount >= 200
        SET @amount_rate = 0.900;
    ELSE IF @original_amount >= 100
        SET @amount_rate = 0.950;

    -- 取两者中更优惠（更小）的折扣率
    IF @amount_rate < @rate
        SET @rate = @amount_rate;

    RETURN @rate;
END;
GO

-- ------------------------------------------------------------
-- 函数 4：折扣金额（标量）
-- 输入：@original_amount 折前金额，@rate 折扣率
-- 规则：折扣金额 = 折前金额 × (1 - 折扣率)，四舍五入到分；
--       非法金额或非法折扣率（超出 [0,1]）返回 NULL。
-- ------------------------------------------------------------
CREATE OR ALTER FUNCTION dbo.fn_discount_amount(
    @original_amount DECIMAL(10,2),
    @rate            DECIMAL(4,3)
)
RETURNS DECIMAL(10,2)
AS
BEGIN
    IF @original_amount IS NULL OR @original_amount < 0
        RETURN NULL;
    IF @rate IS NULL OR @rate < 0 OR @rate > 1
        RETURN NULL;
    RETURN ROUND(@original_amount * (1 - @rate), 2);
END;
GO

-- ------------------------------------------------------------
-- 函数 5：商品分类折扣率（标量）
-- 输入：@category_id 分类编号
-- 规则：当前促销——饮料(4) 98 折、食品(2) 99 折，其余不打折；
--       不存在的分类编号返回 1.000（不影响正常下单）。
-- ------------------------------------------------------------
CREATE OR ALTER FUNCTION dbo.fn_category_discount_rate(
    @category_id INT
)
RETURNS DECIMAL(4,3)
AS
BEGIN
    DECLARE @rate DECIMAL(4,3);
    SET @rate = CASE @category_id
                    WHEN 4 THEN 0.980
                    WHEN 2 THEN 0.990
                    ELSE 1.000
                END;
    RETURN @rate;
END;
GO

-- ------------------------------------------------------------
-- 授权
-- ------------------------------------------------------------
GRANT EXECUTE ON dbo.fn_restock_qty            TO retail_app;
GRANT SELECT  ON dbo.fn_sales_summary          TO retail_app;
GRANT EXECUTE ON dbo.fn_discount_rate          TO retail_app;
GRANT EXECUTE ON dbo.fn_discount_amount        TO retail_app;
GRANT EXECUTE ON dbo.fn_category_discount_rate TO retail_app;
GO

PRINT 'function.sql 执行完成：fn_restock_qty、fn_sales_summary、fn_discount_rate、fn_discount_amount、fn_category_discount_rate';
GO
