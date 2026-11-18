-- ============================================================
-- 00_setup.sql
-- 小卖部管理系统 v1.0 - 第12周 递归查询与业务事务（建表脚本）
-- ============================================================
-- 新增两张表（均为幂等，可重复执行）：
--   1. dbo.category_hierarchy  商品分类层级表（自引用，支持递归 CTE）
--   2. dbo.restock_order       补货入库单表（含单据状态，支持事务）
-- 不改动原有 category、product、inventory 等表结构与基线数据。
-- 以 sa / db_owner 执行。
-- ============================================================

USE retail_store;
GO

-- ------------------------------------------------------------
-- 1. 分类层级表（父级编号 parent_id，自引用外键）
-- ------------------------------------------------------------
IF OBJECT_ID('dbo.category_hierarchy', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.category_hierarchy (
        cat_id    INT NOT NULL,
        cat_name  VARCHAR(50) NOT NULL,
        parent_id INT NULL,
        CONSTRAINT pk_category_hierarchy PRIMARY KEY CLUSTERED (cat_id),
        CONSTRAINT fk_cat_parent FOREIGN KEY (parent_id)
            REFERENCES dbo.category_hierarchy (cat_id)
    );
    PRINT '已创建表 dbo.category_hierarchy';
END
GO

-- ------------------------------------------------------------
-- 2. 补货入库单表
-- ------------------------------------------------------------
IF OBJECT_ID('dbo.restock_order', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.restock_order (
        restock_id       VARCHAR(20)  NOT NULL,
        product_id       VARCHAR(10)  NOT NULL,
        restock_quantity INT          NOT NULL,
        restock_status   VARCHAR(10)  NOT NULL DEFAULT '待入库',
        operator_id      INT          NULL,
        create_time      DATETIME2(3) NOT NULL DEFAULT SYSDATETIME(),
        inbound_time     DATETIME2(3) NULL,
        CONSTRAINT pk_restock_order PRIMARY KEY CLUSTERED (restock_id),
        CONSTRAINT fk_restock_product FOREIGN KEY (product_id)
            REFERENCES dbo.product (product_id),
        CONSTRAINT chk_restock_status CHECK (restock_status IN ('待入库','已入库','已取消')),
        CONSTRAINT chk_restock_quantity CHECK (restock_quantity > 0)
    );
    PRINT '已创建表 dbo.restock_order';
END
GO

PRINT '00_setup.sql 执行完成：层级表与补货单表已就绪';
GO
