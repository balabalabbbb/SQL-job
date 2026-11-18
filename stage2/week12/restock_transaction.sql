-- ============================================================
-- restock_transaction.sql
-- 第12周 模拟补货入库事务（存储过程封装，原子提交 / 失败回滚）
-- ============================================================
-- 事务边界：一次调用 = 一个事务，内部完成
--   单据/商品/数量校验 -> 增加库存 -> （可选模拟失败）-> 更新单据状态 -> 提交
-- 重复入库防护：仅“待入库”单据可执行，已入库单据直接拒绝。
-- 库存审计触发器 trg_inventory_audit 在同一事务内写日志，
-- 事务回滚时审计日志一并回滚。
-- ============================================================

USE retail_store;
GO

CREATE OR ALTER PROCEDURE dbo.usp_restock_inbound_transaction
    @restock_id    VARCHAR(20),
    @simulate_fail BIT = 0          -- 1 = 在加库存后、单据完成前主动抛错，验证回滚
AS
BEGIN
    SET NOCOUNT ON;

    -- ===== 前置检查（事务开启前）=====
    IF NOT EXISTS (SELECT 1 FROM dbo.restock_order WHERE restock_id = @restock_id)
        THROW 52101, '补货单不存在，不能入库', 1;

    IF EXISTS (SELECT 1 FROM dbo.restock_order WHERE restock_id = @restock_id AND restock_status = '已入库')
        THROW 52102, '补货单已入库，不能重复增加库存', 1;

    IF EXISTS (SELECT 1 FROM dbo.restock_order WHERE restock_id = @restock_id AND restock_quantity <= 0)
        THROW 52103, '补货数量必须为正数', 1;

    IF NOT EXISTS (
        SELECT 1
        FROM dbo.restock_order r
        INNER JOIN dbo.product p ON p.product_id = r.product_id
        INNER JOIN dbo.inventory inv ON inv.product_id = r.product_id
        WHERE r.restock_id = @restock_id
    )
        THROW 52104, '商品或库存记录不存在，不能入库', 1;

    BEGIN TRY
        BEGIN TRANSACTION;

        -- 1) 增加库存（部分数据已写入；trg_inventory_audit 会在同事务写审计）
        UPDATE inv
        SET inv.quantity = inv.quantity + r.restock_quantity,
            inv.last_updated = SYSDATETIME()
        FROM dbo.inventory inv
        INNER JOIN dbo.restock_order r ON r.product_id = inv.product_id
        WHERE r.restock_id = @restock_id;

        IF @@ROWCOUNT = 0
            THROW 52104, '库存更新失败，事务回滚', 1;

        -- 2) 模拟“单据完成前发生意外”：此时库存已加，但单据状态尚未更新
        IF @simulate_fail = 1
            THROW 52199, '模拟入库中途失败（测试回滚）', 1;

        -- 3) 全部成功，更新补货单为已入库并记录入库时间
        UPDATE dbo.restock_order
        SET restock_status = '已入库',
            inbound_time = SYSDATETIME()
        WHERE restock_id = @restock_id;

        COMMIT TRANSACTION;
        PRINT '补货单 ' + @restock_id + ' 已入库并提交，库存增加一次';
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0
            ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO

PRINT 'restock_transaction.sql 执行完成：usp_restock_inbound_transaction 已就绪';
GO
