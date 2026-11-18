-- ============================================================
-- trigger.sql
-- 小卖部管理系统 v1.0 - 第11周 触发器
-- ============================================================
-- 交付内容：
--   1. 库存审计触发器 dbo.trg_inventory_audit
--      库存发生插入 / 修改 / 删除时，自动记录：
--      商品编号、调整前数量、调整后数量、变化数量、操作时间、操作类型、操作人员
--   2. 订单完成规则触发器 dbo.trg_order_complete_check
--      订单状态改为“已完成”时，检查订单明细、商品、购买数量、库存、订单金额；
--      条件不满足拒绝修改；已经完成的订单不能重复完成。
--
-- 运行前提：已依次完成 stage1、week6 迁移、week10（00_schema_change / procedure / function）
-- 以 sa 或 db_owner 执行；本脚本可重复执行。
-- 注意：本文件保存为 UTF-8 with BOM，以保证中文正常解析。
-- ============================================================

USE retail_store;
GO

SET NOCOUNT ON;
GO

-- ============================================================
-- 第 0 部分：扩展订单状态约束，加入“已完成”
-- 说明：原 chk_orders_status 只允许 待支付/已支付/已退款/已取消，
--       不加入“已完成”会导致后续 UPDATE 状态被 CHECK 拒绝。
-- ============================================================
IF EXISTS (SELECT 1 FROM sys.check_constraints
           WHERE name = 'chk_orders_status'
             AND parent_object_id = OBJECT_ID('dbo.orders'))
    ALTER TABLE dbo.orders DROP CONSTRAINT chk_orders_status;
GO

ALTER TABLE dbo.orders
ADD CONSTRAINT chk_orders_status
    CHECK (order_status IN ('待支付','已支付','已完成','已退款','已取消'));
GO

-- ============================================================
-- 第 1 部分：库存审计表 dbo.inventory_change_log
-- 说明：与第10周的 inventory_adjustment（存储过程审计）分开，
--       本表由触发器自动维护，专门记录每一次库存行级变化。
-- ============================================================
IF OBJECT_ID('dbo.inventory_change_log', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.inventory_change_log (
        log_id          INT IDENTITY(1,1) NOT NULL,
        product_id      VARCHAR(10)   NOT NULL,
        quantity_before INT           NULL,
        quantity_after  INT           NULL,
        change_quantity INT           NOT NULL,
        operation_type  VARCHAR(10)   NOT NULL,
        operator        NVARCHAR(128) NOT NULL,
        operation_time  DATETIME2(3)  NOT NULL DEFAULT SYSDATETIME(),
        CONSTRAINT pk_inventory_change_log PRIMARY KEY CLUSTERED (log_id),
        CONSTRAINT chk_log_operation_type CHECK (operation_type IN ('INSERT','UPDATE','DELETE'))
    );
    PRINT '已创建表 dbo.inventory_change_log';
END
GO

-- ============================================================
-- 第 2 部分：库存审计触发器（AFTER INSERT/UPDATE/DELETE，支持多行）
-- 关键：inserted / deleted 是集合，可能一次包含多行，
--       必须用集合 SELECT 处理，不能用单个变量只存一行。
-- ============================================================
CREATE OR ALTER TRIGGER dbo.trg_inventory_audit
ON dbo.inventory
AFTER INSERT, UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;

    -- 2.1 INSERT：inserted 中存在、deleted 中不存在（按主键 inventory_id 判断）
    INSERT INTO dbo.inventory_change_log
        (product_id, quantity_before, quantity_after, change_quantity,
         operation_type, operator, operation_time)
    SELECT i.product_id, NULL, i.quantity, i.quantity,
           'INSERT', SUSER_SNAME(), SYSDATETIME()
    FROM inserted i
    WHERE NOT EXISTS (SELECT 1 FROM deleted d WHERE d.inventory_id = i.inventory_id);

    -- 2.2 DELETE：deleted 中存在、inserted 中不存在
    INSERT INTO dbo.inventory_change_log
        (product_id, quantity_before, quantity_after, change_quantity,
         operation_type, operator, operation_time)
    SELECT d.product_id, d.quantity, NULL, -d.quantity,
           'DELETE', SUSER_SNAME(), SYSDATETIME()
    FROM deleted d
    WHERE NOT EXISTS (SELECT 1 FROM inserted i WHERE i.inventory_id = d.inventory_id);

    -- 2.3 UPDATE：inserted 与 deleted 按主键匹配
    INSERT INTO dbo.inventory_change_log
        (product_id, quantity_before, quantity_after, change_quantity,
         operation_type, operator, operation_time)
    SELECT i.product_id, d.quantity, i.quantity, i.quantity - d.quantity,
           'UPDATE', SUSER_SNAME(), SYSDATETIME()
    FROM inserted i
    INNER JOIN deleted d ON d.inventory_id = i.inventory_id;
END;
GO

-- ============================================================
-- 第 3 部分：订单完成规则触发器
-- 仅在订单状态被更新为“已完成”时触发校验，任一条件不满足则回滚并报错。
-- ============================================================
CREATE OR ALTER TRIGGER dbo.trg_order_complete_check
ON dbo.orders
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    -- 没有任何订单被改为“已完成”，直接结束，不影响普通更新
    IF NOT EXISTS (
        SELECT 1 FROM inserted i
        INNER JOIN deleted d ON d.order_id = i.order_id
        WHERE i.order_status = '已完成'
    )
        RETURN;

    -- 检查 1：已经完成的订单不能重复完成（旧状态已经是“已完成”）
    IF EXISTS (
        SELECT 1 FROM inserted i
        INNER JOIN deleted d ON d.order_id = i.order_id
        WHERE i.order_status = '已完成' AND d.order_status = '已完成'
    )
    BEGIN
        ROLLBACK TRANSACTION;
        THROW 51001, '订单已经完成，不能重复完成', 1;
    END

    -- 检查 2：订单必须存在明细
    IF EXISTS (
        SELECT 1 FROM inserted i
        INNER JOIN deleted d ON d.order_id = i.order_id
        WHERE i.order_status = '已完成'
          AND NOT EXISTS (SELECT 1 FROM dbo.order_item oi WHERE oi.order_id = i.order_id)
    )
    BEGIN
        ROLLBACK TRANSACTION;
        THROW 51002, '订单没有明细，不能完成', 1;
    END

    -- 检查 3：明细中的商品必须真实存在
    IF EXISTS (
        SELECT 1 FROM inserted i
        INNER JOIN dbo.order_item oi ON oi.order_id = i.order_id
        LEFT JOIN dbo.product p ON p.product_id = oi.product_id
        WHERE i.order_status = '已完成' AND p.product_id IS NULL
    )
    BEGIN
        ROLLBACK TRANSACTION;
        THROW 51003, '明细中存在不存在的商品，不能完成', 1;
    END

    -- 检查 4：购买数量必须大于 0
    IF EXISTS (
        SELECT 1 FROM inserted i
        INNER JOIN dbo.order_item oi ON oi.order_id = i.order_id
        WHERE i.order_status = '已完成' AND oi.quantity <= 0
    )
    BEGIN
        ROLLBACK TRANSACTION;
        THROW 51004, '购买数量必须大于 0，不能完成', 1;
    END

    -- 检查 5：库存记录必须存在且库存非负
    IF EXISTS (
        SELECT 1 FROM inserted i
        INNER JOIN dbo.order_item oi ON oi.order_id = i.order_id
        LEFT JOIN dbo.inventory inv ON inv.product_id = oi.product_id
        WHERE i.order_status = '已完成'
          AND (inv.inventory_id IS NULL OR inv.quantity < 0)
    )
    BEGIN
        ROLLBACK TRANSACTION;
        THROW 51005, '商品库存记录缺失或库存为负，不能完成', 1;
    END

    -- 检查 6：订单金额不能为负
    IF EXISTS (
        SELECT 1 FROM inserted
        WHERE order_status = '已完成' AND total_amount < 0
    )
    BEGIN
        ROLLBACK TRANSACTION;
        THROW 51006, '订单金额不能为负数', 1;
    END

    -- 检查 7：金额一致性
    -- 业务口径：明细原价合计 = 折后订单总额(total_amount) + 折扣金额(discount_amount)
    -- 允许 0.02 的舍入容差。
    IF EXISTS (
        SELECT 1 FROM (
            SELECT i.order_id,
                   SUM(oi.subtotal)               AS sum_subtotal,
                   MAX(i.total_amount)            AS total_amt,
                   MAX(i.discount_amount)         AS disc_amt
            FROM inserted i
            INNER JOIN dbo.order_item oi ON oi.order_id = i.order_id
            WHERE i.order_status = '已完成'
            GROUP BY i.order_id
        ) t
        WHERE ABS(t.sum_subtotal - t.total_amt - t.disc_amt) > 0.02
    )
    BEGIN
        ROLLBACK TRANSACTION;
        THROW 51007, '订单金额与明细、折扣不一致，不能完成', 1;
    END
END;
GO

-- ============================================================
-- 第 4 部分：授权应用账户读取审计表
-- ============================================================
GRANT SELECT ON dbo.inventory_change_log TO retail_app;
GO

PRINT 'trigger.sql 执行完成：trg_inventory_audit、trg_order_complete_check 已就绪';
GO
