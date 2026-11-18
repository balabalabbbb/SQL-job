-- ============================================================
-- order_transaction.sql
-- 第12周 订单完成事务（存储过程封装，原子提交 / 失败回滚）
-- ============================================================
-- 事务边界：一次调用 = 一个事务，内部完成
--   状态/明细/数量校验 -> 改状态（第11周触发器校验原始库存）-> 带条件扣库存 -> 提交
-- 与第11周对象的关系：
--   trg_order_complete_check 只校验、不扣库存；本过程负责实际扣减，
--   故一次业务只扣一次库存，不重复。
-- 库存扣减用带条件的 UPDATE（quantity >= need）并检查行数，
-- 不靠事务外的一次查询判断充足。
-- ============================================================

USE retail_store;
GO

CREATE OR ALTER PROCEDURE dbo.usp_complete_order_transaction
    @order_id VARCHAR(30)
AS
BEGIN
    SET NOCOUNT ON;

    -- ===== 前置检查（事务开启前，快速拒绝明显非法输入）=====
    IF NOT EXISTS (SELECT 1 FROM dbo.orders WHERE order_id = @order_id)
        THROW 52001, '订单不存在，不能完成', 1;

    IF EXISTS (SELECT 1 FROM dbo.orders WHERE order_id = @order_id AND order_status = '已完成')
        THROW 52002, '订单已经完成，不能重复扣减库存', 1;

    IF NOT EXISTS (SELECT 1 FROM dbo.order_item WHERE order_id = @order_id)
        THROW 52003, '订单没有明细，不能完成', 1;

    BEGIN TRY
        BEGIN TRANSACTION;

        -- 1) 明细数量必须 > 0
        IF EXISTS (SELECT 1 FROM dbo.order_item WHERE order_id = @order_id AND quantity <= 0)
            THROW 52004, '存在购买数量不大于 0 的明细，不能完成', 1;

        -- 2) 先把订单状态改为“已完成”。
        --    此时库存尚未扣减，第11周触发器基于原始库存做明细/商品/金额/充足性校验，
        --    校验不通过会在这里抛错并由 CATCH 回滚。
        UPDATE dbo.orders
        SET order_status = '已完成'
        WHERE order_id = @order_id;

        -- 3) 带条件扣减库存：仅当该商品当前库存 >= 汇总需求量时才扣。
        --    一条集合 UPDATE 处理订单内全部商品。
        UPDATE inv
        SET inv.quantity = inv.quantity - need.req_quantity,
            inv.last_updated = SYSDATETIME()
        FROM dbo.inventory inv
        INNER JOIN (
            SELECT product_id, SUM(quantity) AS req_quantity
            FROM dbo.order_item
            WHERE order_id = @order_id
            GROUP BY product_id
        ) need ON need.product_id = inv.product_id
        WHERE inv.quantity >= need.req_quantity;

        -- 4) 受影响行数必须等于该订单涉及的不同商品数，否则说明有商品缺失/不足
        DECLARE @affected INT = @@ROWCOUNT;
        DECLARE @product_count INT = (
            SELECT COUNT(DISTINCT product_id)
            FROM dbo.order_item WHERE order_id = @order_id
        );
        IF @affected <> @product_count
            THROW 52005, '商品库存记录缺失或库存不足，事务回滚', 1;

        COMMIT TRANSACTION;
        PRINT '订单 ' + @order_id + ' 已完成并提交，库存已扣减一次';
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0
            ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO

PRINT 'order_transaction.sql 执行完成：usp_complete_order_transaction 已就绪';
GO
