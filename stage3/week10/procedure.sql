-- ============================================================
-- procedure.sql
-- 小卖部管理系统 v1.0 - 第10周 存储过程 (SQL Server)
-- ============================================================
-- 包含：
--   1. dbo.usp_sales_statistics  销售统计存储过程（日期范围 -> 汇总 + 商品明细）
--   2. dbo.usp_adjust_inventory  库存调整存储过程（带事务、校验、调整记录）
--
-- 特性：使用 CREATE OR ALTER，可重复执行；TRY...CATCH 统一异常处理。
-- 日期口径：开始日期、结束日期均"包含当天"。
-- ============================================================

USE retail_store;
GO

-- ------------------------------------------------------------
-- 存储过程 1：销售统计
-- 输入：@start_date 开始日期，@end_date 结束日期
-- 输出：三个 OUTPUT 参数返回整体汇总（订单数/销售数量/销售金额），
--       一个结果集返回商品销售明细
-- ------------------------------------------------------------
CREATE OR ALTER PROCEDURE dbo.usp_sales_statistics
    @start_date   DATE,
    @end_date     DATE,
    @order_count  INT            OUTPUT,
    @sales_qty    INT            OUTPUT,
    @sales_amount DECIMAL(10,2)  OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        -- ===== 输入检查 =====
        IF @start_date IS NULL
            THROW 50001, '开始日期不能为空', 1;
        IF @end_date IS NULL
            THROW 50002, '结束日期不能为空', 1;
        IF @start_date > @end_date
            THROW 50003, '开始日期不能晚于结束日期', 1;

        -- 结束日含当天：用"次日零点"作为上界
        DECLARE @end_exclusive DATE = DATEADD(DAY, 1, @end_date);

        -- ===== 整体汇总：通过 OUTPUT 参数返回（无销售时为 0）=====
        SELECT
            @order_count  = COUNT(DISTINCT o.order_id),       -- 订单数量
            @sales_qty    = ISNULL(SUM(oi.quantity), 0),      -- 销售数量
            @sales_amount = ISNULL(SUM(oi.subtotal), 0)       -- 销售金额
        FROM dbo.orders o
        LEFT JOIN dbo.order_item oi ON oi.order_id = o.order_id
        WHERE o.order_time >= @start_date
          AND o.order_time <  @end_exclusive
          AND o.order_status = N'已支付';                     -- 只统计已支付（已取消/已退款不计入销售）

        -- ===== 商品销售明细：唯一结果集（仅列有销售的商品）=====
        SELECT
            p.product_id,
            p.product_name,
            ISNULL(SUM(oi.quantity), 0)  AS sales_qty,
            ISNULL(SUM(oi.subtotal), 0)  AS sales_amount,
            COUNT(DISTINCT o.order_id)   AS order_count
        FROM dbo.product p
        LEFT JOIN dbo.order_item oi ON oi.product_id = p.product_id
        LEFT JOIN dbo.orders o
               ON o.order_id = oi.order_id
              AND o.order_time >= @start_date
              AND o.order_time <  @end_exclusive
              AND o.order_status = N'已支付'
        GROUP BY p.product_id, p.product_name
        HAVING COUNT(DISTINCT o.order_id) > 0
        ORDER BY sales_amount DESC, p.product_id;
    END TRY
    BEGIN CATCH
        -- 重新抛出，保留原始错误号与消息；应用层统一转换为前端友好提示
        THROW;
    END CATCH
END;
GO

-- ------------------------------------------------------------
-- 存储过程 2：库存调整
-- 输入：@product_id 商品编号，@adjust_qty 调整数量(正增负减)，
--       @reason 调整原因，@operator_id 操作员工编号
-- 输出：调整前后数量；同时写入 inventory 与 inventory_adjustment
-- ------------------------------------------------------------
CREATE OR ALTER PROCEDURE dbo.usp_adjust_inventory
    @product_id   VARCHAR(10),
    @adjust_qty   INT,
    @reason       VARCHAR(50),
    @operator_id  INT
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @qty_before INT, @qty_after INT;

    BEGIN TRY
        -- ===== 输入检查（事务外的基础校验）=====
        IF @product_id IS NULL OR LTRIM(RTRIM(@product_id)) = ''
            THROW 50010, '商品编号不能为空', 1;
        IF @operator_id IS NULL
            THROW 50011, '操作员工编号不能为空', 1;
        IF @adjust_qty = 0
            THROW 50012, '调整数量不能为零', 1;
        IF @reason IS NULL OR LTRIM(RTRIM(@reason)) = ''
            THROW 50013, '调整原因不能为空', 1;

        IF NOT EXISTS (SELECT 1 FROM dbo.product  WHERE product_id  = @product_id)
            THROW 50014, '商品不存在，无法调整库存', 1;
        IF NOT EXISTS (SELECT 1 FROM dbo.employee WHERE employee_id = @operator_id)
            THROW 50015, '操作员工不存在', 1;

        BEGIN TRANSACTION;
            -- 事务内加更新锁，防止两个会话同时调整同一商品导致超扣
            SELECT @qty_before = quantity
            FROM dbo.inventory WITH (UPDLOCK, HOLDLOCK)
            WHERE product_id = @product_id;

            IF @qty_before IS NULL
                THROW 50016, '该商品没有库存记录', 1;

            SET @qty_after = @qty_before + @adjust_qty;
            IF @qty_after < 0
                THROW 50017, '库存不足，调整后库存不能为负数', 1;

            -- 1) 更新库存主表
            UPDATE dbo.inventory
            SET quantity        = @qty_after,
                last_updated    = GETDATE(),
                last_updated_by = @operator_id
            WHERE product_id = @product_id;

            -- 2) 写入库存调整记录（审计轨迹）
            INSERT INTO dbo.inventory_adjustment
                (product_id, adjust_quantity, quantity_before, quantity_after, reason, operator_id)
            VALUES
                (@product_id, @adjust_qty, @qty_before, @qty_after, @reason, @operator_id);
        COMMIT TRANSACTION;

        -- 返回调整结果
        SELECT @product_id  AS product_id,
               @qty_before  AS quantity_before,
               @qty_after   AS quantity_after,
               @adjust_qty  AS adjust_quantity;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO

-- 授权应用账户执行这两个存储过程
GRANT EXECUTE ON dbo.usp_sales_statistics TO retail_app;
GRANT EXECUTE ON dbo.usp_adjust_inventory TO retail_app;
GO

PRINT 'procedure.sql 执行完成：usp_sales_statistics、usp_adjust_inventory';
GO
