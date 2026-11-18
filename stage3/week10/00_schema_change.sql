-- ============================================================
-- 00_schema_change.sql
-- 小卖部管理系统 v1.0 - 第三阶段(第10周) 结构变更脚本 (SQL Server)
-- ============================================================
-- 变更内容：
--   1. 新增库存调整记录表 inventory_adjustment
--      （第5周业务规则文档已指出"库存变更日志表未实现"，本周补齐）
--   2. orders 表新增折扣字段 discount_rate / discount_amount
--      total_amount 语义保持为"折后应付金额(成交价)"，历史订单默认无折扣
--
-- 特性：本脚本可重复执行（IF NOT EXISTS 判断），以 sa 或 db_owner 运行。
-- ============================================================

USE retail_store;
GO

SET NOCOUNT ON;
GO

-- ------------------------------------------------------------
-- 一、新增库存调整记录表 inventory_adjustment
-- ------------------------------------------------------------
IF OBJECT_ID('dbo.inventory_adjustment', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.inventory_adjustment (
        adjustment_id    INT             NOT NULL IDENTITY(1,1),
        product_id       VARCHAR(10)     NOT NULL,
        adjust_quantity  INT             NOT NULL,            -- 正数=入库/增加，负数=出库/减少
        quantity_before  INT             NOT NULL,            -- 调整前数量
        quantity_after   INT             NOT NULL,            -- 调整后数量
        reason           VARCHAR(50)     NOT NULL,            -- 调整原因
        operator_id      INT             NOT NULL,            -- 操作员工编号
        adjust_time      DATETIME        NOT NULL DEFAULT GETDATE(),
        CONSTRAINT pk_inventory_adjustment PRIMARY KEY CLUSTERED (adjustment_id),
        CONSTRAINT fk_adj_product  FOREIGN KEY (product_id)  REFERENCES dbo.product(product_id),
        CONSTRAINT fk_adj_employee FOREIGN KEY (operator_id) REFERENCES dbo.employee(employee_id),
        CONSTRAINT chk_adj_qty_nonzero   CHECK (adjust_quantity <> 0),
        CONSTRAINT chk_adj_before_nonneg CHECK (quantity_before >= 0),
        CONSTRAINT chk_adj_after_nonneg  CHECK (quantity_after  >= 0)
    );
    PRINT '已创建表 dbo.inventory_adjustment';
END
ELSE
    PRINT '表 dbo.inventory_adjustment 已存在，跳过';
GO

-- ------------------------------------------------------------
-- 二、orders 表新增折扣字段
-- ------------------------------------------------------------
IF COL_LENGTH('dbo.orders', 'discount_rate') IS NULL
    ALTER TABLE dbo.orders ADD discount_rate DECIMAL(4,3) NOT NULL
        CONSTRAINT df_orders_discount_rate DEFAULT 1.000;   -- 1.000 表示无折扣
GO

IF COL_LENGTH('dbo.orders', 'discount_amount') IS NULL
    ALTER TABLE dbo.orders ADD discount_amount DECIMAL(10,2) NOT NULL
        CONSTRAINT df_orders_discount_amount DEFAULT 0.00;  -- 折扣金额
GO

-- 历史订单默认无折扣（DEFAULT 仅对新行生效，这里显式回填一次，保证语义一致）
UPDATE dbo.orders
SET discount_rate = 1.000, discount_amount = 0.00
WHERE discount_rate IS NULL OR discount_amount IS NULL;
GO

-- 折扣率合法区间 [0,1]
IF NOT EXISTS (SELECT 1 FROM sys.check_constraints
               WHERE name = 'chk_orders_discount_rate' AND parent_object_id = OBJECT_ID('dbo.orders'))
    ALTER TABLE dbo.orders ADD CONSTRAINT chk_orders_discount_rate
        CHECK (discount_rate >= 0 AND discount_rate <= 1);
GO

-- ------------------------------------------------------------
-- 三、授权：应用账户 retail_app 可读写新表、执行过程与函数
-- ------------------------------------------------------------
GRANT SELECT, INSERT ON dbo.inventory_adjustment TO retail_app;
GRANT SELECT, UPDATE ON dbo.orders TO retail_app;
GO

PRINT '========================================';
PRINT '结构变更完成：inventory_adjustment 表 + orders 折扣字段';
PRINT '========================================';
GO
