-- ============================================================
-- restock_transaction.sql
-- 第12周 模拟补货入库事务（存储过程封装，原子提交 / 失败回滚）
-- ============================================================
-- 事务边界：一次调用 = 一个事务，内部完成
--   单据/商品/数量校验 -> 带锁读库存 -> 增加库存 -> 写库存调整流水
--   -> （可选模拟失败）-> 更新单据状态 -> 提交
-- 与第10周口径对齐：库存增加同时写 inventory_adjustment 调整轨迹，
--   并复用 UPDLOCK,HOLDLOCK 防止并发超扣。
-- 重复入库防护：仅“待入库”单据可执行，已入库单据直接拒绝。
-- 库存审计触发器 trg_inventory_audit 在同一事务内写日志，
-- 事务回滚时库存、调整流水、审计日志一并回滚。
-- ------------------------------------------------------------
-- 输入参数：
--   @restock_id VARCHAR(20)，待入库补货单编号；
--   @simulate_fail BIT = 0，置 1 时在加库存/写流水后、单据完成前抛错以验证回滚。
-- 测试数据准备：见 test_week12.sql 阶段0/二，自动准备商品、库存及
--   待入库补货单 RST12OK / RST12FAIL。
-- 调用顺序：00_setup.sql -> recursive_query.sql -> order_transaction.sql
--   -> 本脚本(建过程) -> test_week12.sql（执行 EXEC 调用并验证）。
-- ============================================================

USE retail_store;
GO

CREATE OR ALTER PROCEDURE dbo.usp_restock_inbound_transaction
    @restock_id    VARCHAR(20),
    @simulate_fail BIT = 0          -- 1 = 在部分写入后主动抛错，验证回滚
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

    -- 读取单据信息
    DECLARE @pid VARCHAR(10), @qty INT, @operator INT;
    SELECT @pid = product_id, @qty = restock_quantity, @operator = ISNULL(operator_id, 1)
    FROM dbo.restock_order
    WHERE restock_id = @restock_id;

    BEGIN TRY
        BEGIN TRANSACTION;

        -- 1) 带更新锁读取当前库存（调整前数量）
        DECLARE @before INT, @after INT;
        SELECT @before = quantity
        FROM dbo.inventory WITH (UPDLOCK, HOLDLOCK)
        WHERE product_id = @pid;

        IF @before IS NULL
            THROW 52104, '库存记录缺失，事务回滚', 1;
        SET @after = @before + @qty;

        -- 2) 增加库存
        UPDATE dbo.inventory
        SET quantity = @after,
            last_updated = SYSDATETIME()
        WHERE product_id = @pid;

        -- 3) 写库存调整流水（与第10周 usp_adjust_inventory 审计口径一致）
        INSERT INTO dbo.inventory_adjustment
            (product_id, adjust_quantity, quantity_before, quantity_after, reason, operator_id)
        VALUES
            (@pid, @qty, @before, @after, '补货入库', @operator);

        -- 4) 模拟“单据完成前发生意外”：此时库存与流水已写入，但单据状态尚未更新
        IF @simulate_fail = 1
            THROW 52199, '模拟入库中途失败（测试回滚）', 1;

        -- 5) 全部成功，更新补货单为已入库并记录入库时间
        UPDATE dbo.restock_order
        SET restock_status = '已入库',
            inbound_time = SYSDATETIME()
        WHERE restock_id = @restock_id;

        COMMIT TRANSACTION;
        PRINT '补货单 ' + @restock_id + ' 已入库并提交，库存增加一次，调整流水已记录';
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
