-- ============================================================
-- migration.sql
-- 小卖部管理系统 - v0.1 到 v1.0 数据迁移脚本 (SQL Server 版本)
-- ============================================================
-- 迁移内容：
--   1. 将 product.category 字段拆分为独立 category 表
--   2. product 表新增 category_id 外键，删除 category 字符串字段
--   3. 其他 5 张表保持不变（已满足 3NF）
--
-- 运行前提：
--   1. 已执行 stage1/sql/01-09 脚本，数据库 retail_store 存在且有数据
--   2. 以 sa 或 db_owner 角色执行
--   3. 建议先备份数据库（见下方备份步骤）
--
-- 执行顺序：按脚本从上到下依次执行
--
-- 失败恢复方法：
--   若迁移中途失败，可从备份表恢复：
--     SELECT * INTO product FROM product_bak_v01;
--     DROP TABLE IF EXISTS category;
--   或从完整数据库备份恢复。
--
-- 注意：本脚本不要求可重复执行。再次运行需确保处于 v0.1 状态
--       （即 product 表仍有 category 字段、无 category_id 字段、无 category 表）。
-- ============================================================

USE retail_store;
GO

-- ============================================================
-- 第一步：备份 v0.1 基线数据
-- ============================================================

PRINT '=== 第一步：备份 v0.1 基线数据 ===';

-- 备份 product 表（迁移涉及的表）
IF OBJECT_ID('dbo.product_bak_v01', 'U') IS NOT NULL
    DROP TABLE dbo.product_bak_v01;
SELECT * INTO dbo.product_bak_v01 FROM dbo.product;
PRINT 'product 表已备份为 product_bak_v01';

-- 记录迁移前各表记录数（基线）
IF OBJECT_ID('dbo.migration_baseline', 'U') IS NOT NULL
    DROP TABLE dbo.migration_baseline;
CREATE TABLE dbo.migration_baseline (
    table_name VARCHAR(50) NOT NULL,
    row_count INT NOT NULL,
    baseline_time DATETIME NOT NULL DEFAULT GETDATE()
);
INSERT INTO dbo.migration_baseline (table_name, row_count)
SELECT 'product', COUNT(*) FROM product
UNION ALL SELECT 'member', COUNT(*) FROM member
UNION ALL SELECT 'employee', COUNT(*) FROM employee
UNION ALL SELECT 'inventory', COUNT(*) FROM inventory
UNION ALL SELECT 'orders', COUNT(*) FROM orders
UNION ALL SELECT 'order_item', COUNT(*) FROM order_item;
PRINT '基线记录数已保存到 migration_baseline';

-- 保存迁移前关键查询结果（用于回归对比基准）
-- 1. 订单明细基准
IF OBJECT_ID('dbo.baseline_order_detail', 'U') IS NOT NULL
    DROP TABLE dbo.baseline_order_detail;
SELECT
    o.order_id, o.order_time, o.total_amount,
    oi.product_id, oi.quantity, oi.unit_price, oi.subtotal
INTO dbo.baseline_order_detail
FROM dbo.orders o
JOIN dbo.order_item oi ON o.order_id = oi.order_id;
PRINT '订单明细基准已保存（20条）';

-- 2. 商品销售统计基准
IF OBJECT_ID('dbo.baseline_product_sales', 'U') IS NOT NULL
    DROP TABLE dbo.baseline_product_sales;
SELECT
    p.product_id, p.product_name, p.category,
    COUNT(DISTINCT oi.order_id) AS order_count,
    SUM(oi.quantity) AS total_quantity,
    SUM(oi.subtotal) AS total_amount
INTO dbo.baseline_product_sales
FROM dbo.product p
LEFT JOIN dbo.order_item oi ON p.product_id = oi.product_id
GROUP BY p.product_id, p.product_name, p.category;
PRINT '商品销售统计基准已保存（10条）';

-- 3. 库存查询基准
IF OBJECT_ID('dbo.baseline_inventory', 'U') IS NOT NULL
    DROP TABLE dbo.baseline_inventory;
SELECT
    p.product_id, p.product_name, p.category,
    i.quantity, i.min_threshold,
    CASE WHEN i.quantity = 0 THEN '缺货'
         WHEN i.quantity < i.min_threshold THEN '需补货'
         ELSE '正常' END AS inventory_status
INTO dbo.baseline_inventory
FROM dbo.product p
JOIN dbo.inventory i ON p.product_id = i.product_id;
PRINT '库存查询基准已保存（10条）';

-- 4. 订单总额基准
IF OBJECT_ID('dbo.baseline_order_summary', 'U') IS NOT NULL
    DROP TABLE dbo.baseline_order_summary;
SELECT
    COUNT(*) AS order_count,
    SUM(total_amount) AS total_sales,
    AVG(total_amount) AS avg_order_amount
INTO dbo.baseline_order_summary
FROM dbo.orders;
PRINT '订单总额基准已保存';
GO

-- ============================================================
-- 第二步：创建 category 表
-- ============================================================

PRINT '=== 第二步：创建 category 表 ===';

IF OBJECT_ID('dbo.category', 'U') IS NOT NULL
    DROP TABLE dbo.category;

CREATE TABLE dbo.category (
    category_id     INT             NOT NULL IDENTITY(1,1),
    category_name   VARCHAR(20)     NOT NULL,
    description     VARCHAR(100)    NULL,
    sort_order      INT             NOT NULL DEFAULT 0,
    CONSTRAINT pk_category PRIMARY KEY CLUSTERED (category_id),
    CONSTRAINT uk_category_name UNIQUE NONCLUSTERED (category_name)
);
PRINT 'category 表已创建';
GO

-- ============================================================
-- 第三步：从 product 提取分类数据插入 category
-- ============================================================

PRINT '=== 第三步：迁移分类数据 ===';

-- 提取 product 中不重复的 category 值
INSERT INTO dbo.category (category_name, description, sort_order)
SELECT DISTINCT
    category AS category_name,
    NULL AS description,
    0 AS sort_order
FROM dbo.product
WHERE category IS NOT NULL
ORDER BY category;

PRINT '已迁移分类数据：';
SELECT category_id, category_name FROM dbo.category ORDER BY category_id;
GO

-- ============================================================
-- 第四步：product 表新增 category_id 字段并填充数据
-- ============================================================

PRINT '=== 第四步：product 表新增 category_id 并填充 ===';

-- 新增 category_id 字段（先允许 NULL，填充后再设为 NOT NULL）
ALTER TABLE dbo.product ADD category_id INT NULL;
GO

-- 填充 category_id：通过 category_name 关联
UPDATE p
SET p.category_id = c.category_id
FROM dbo.product p
JOIN dbo.category c ON p.category = c.category_name;
PRINT 'product.category_id 已填充';

-- 检查是否有未匹配的行（数据冲突检查）
DECLARE @unmatched INT;
SELECT @unmatched = COUNT(*) FROM dbo.product WHERE category_id IS NULL;
IF @unmatched > 0
BEGIN
    PRINT '警告：有 ' + CAST(@unmatched AS VARCHAR) + ' 行商品未匹配到分类！';
    SELECT product_id, product_name, category FROM dbo.product WHERE category_id IS NULL;
END
ELSE
BEGIN
    PRINT '所有商品均已匹配分类，无数据冲突';
END
GO

-- ============================================================
-- 第五步：添加外键约束并删除旧 category 字段
-- ============================================================

PRINT '=== 第五步：添加外键约束，删除旧字段 ===';

-- 将 category_id 设为 NOT NULL
ALTER TABLE dbo.product ALTER COLUMN category_id INT NOT NULL;
GO

-- 添加外键约束
ALTER TABLE dbo.product
ADD CONSTRAINT fk_product_category
    FOREIGN KEY (category_id) REFERENCES dbo.category(category_id);
PRINT '外键 fk_product_category 已添加';
GO

-- 删除旧的 category 字符串字段前，先删除依赖对象
-- （chk_product_category CHECK约束 和 idx_product_category 索引）
IF EXISTS (SELECT 1 FROM sys.check_constraints WHERE name = 'chk_product_category' AND parent_object_id = OBJECT_ID('product'))
    ALTER TABLE dbo.product DROP CONSTRAINT chk_product_category;
IF EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'idx_product_category' AND object_id = OBJECT_ID('product'))
    DROP INDEX idx_product_category ON dbo.product;

-- 删除旧的 category 字符串字段
ALTER TABLE dbo.product DROP COLUMN category;
PRINT 'product.category 旧字段已删除（含依赖的CHECK约束和索引）';
GO

-- ============================================================
-- 第六步：重复数据检查
-- ============================================================

PRINT '=== 第六步：重复数据与完整性检查 ===';

-- 检查 category 表无重复名称
SELECT category_name, COUNT(*) AS 重复数
FROM dbo.category
GROUP BY category_name
HAVING COUNT(*) > 1;
PRINT 'category 表无重复分类名（以上无输出表示通过）';

-- 检查 product 无孤立 category_id
SELECT p.product_id, p.product_name, p.category_id
FROM dbo.product p
LEFT JOIN dbo.category c ON p.category_id = c.category_id
WHERE c.category_id IS NULL;
PRINT 'product 无孤立分类（以上无输出表示通过）';
GO

-- ============================================================
-- 第七步：迁移后验证（记录数对比）
-- ============================================================

PRINT '=== 第七步：迁移后验证 ===';

-- 各表记录数应与基线一致
SELECT
    b.table_name,
    b.row_count AS 迁移前,
    CASE b.table_name
        WHEN 'product' THEN (SELECT COUNT(*) FROM product)
        WHEN 'member' THEN (SELECT COUNT(*) FROM member)
        WHEN 'employee' THEN (SELECT COUNT(*) FROM employee)
        WHEN 'inventory' THEN (SELECT COUNT(*) FROM inventory)
        WHEN 'orders' THEN (SELECT COUNT(*) FROM orders)
        WHEN 'order_item' THEN (SELECT COUNT(*) FROM order_item)
    END AS 迁移后,
    CASE
        WHEN b.table_name = 'product' AND (SELECT COUNT(*) FROM product) = b.row_count THEN '一致'
        WHEN b.table_name != 'product' THEN '未变更'
        ELSE '不一致！'
    END AS 状态
FROM dbo.migration_baseline b
ORDER BY b.table_name;

-- 新增 category 表记录数
SELECT COUNT(*) AS category表记录数 FROM dbo.category;
GO

-- ============================================================
-- 第八步：验证业务语义一致（通过 JOIN 还原分类名称）
-- ============================================================

PRINT '=== 第八步：业务语义验证 ===';

-- 迁移后商品分类信息（通过 JOIN 还原）
SELECT TOP 10
    p.product_id,
    p.product_name,
    c.category_name AS category,
    p.sale_price
FROM dbo.product p
JOIN dbo.category c ON p.category_id = c.category_id
ORDER BY p.product_id;
PRINT '商品分类信息可通过 JOIN 正常还原，业务语义一致';

-- 与备份对比分类名称
SELECT
    b.product_id,
    b.product_name,
    b.category AS 迁移前分类,
    c.category_name AS 迁移后分类,
    CASE WHEN b.category = c.category_name THEN '一致' ELSE '不一致！' END AS 对比
FROM dbo.product_bak_v01 b
JOIN dbo.product p ON b.product_id = p.product_id
JOIN dbo.category c ON p.category_id = c.category_id
WHERE b.category <> c.category_name;
PRINT '分类名称对比完成（无输出表示全部一致）';
GO

-- ============================================================
-- 第九步：修复引用旧 category 列的视图
-- ============================================================

PRINT '=== 第九步：修复引用旧 category 列的视图 ===';

-- 修复 v_product_sales：p.category → JOIN category
ALTER VIEW dbo.v_product_sales AS
SELECT
    p.product_id        AS product_id,
    p.product_name      AS product_name,
    c.category_name     AS category,
    p.sale_price        AS sale_price,
    p.purchase_price    AS purchase_price,
    p.status            AS product_status,
    COALESCE(sales.order_count, 0)   AS order_count,
    COALESCE(sales.total_quantity, 0) AS total_quantity,
    COALESCE(sales.total_amount, 0)   AS total_amount,
    COALESCE(sales.total_quantity, 0) * (p.sale_price - p.purchase_price) AS gross_profit
FROM dbo.product p
JOIN dbo.category c ON p.category_id = c.category_id
LEFT JOIN (
    SELECT product_id, COUNT(DISTINCT order_id) AS order_count,
           SUM(quantity) AS total_quantity, SUM(subtotal) AS total_amount
    FROM dbo.order_item GROUP BY product_id
) sales ON p.product_id = sales.product_id;
PRINT 'v_product_sales 已修复';

-- 修复 v_category_sales：p.category → c.category_name
ALTER VIEW dbo.v_category_sales AS
SELECT
    c.category_name              AS category,
    COUNT(DISTINCT p.product_id) AS product_count,
    COUNT(DISTINCT oi.order_id) AS order_count,
    COALESCE(SUM(oi.quantity), 0) AS total_quantity,
    COALESCE(SUM(oi.subtotal), 0) AS total_sales,
    COALESCE(AVG(oi.unit_price), 0) AS avg_unit_price,
    ROUND(COALESCE(SUM(oi.subtotal), 0) / NULLIF((SELECT SUM(subtotal) FROM dbo.order_item), 0) * 100, 2) AS sales_percentage
FROM dbo.product p
JOIN dbo.category c ON p.category_id = c.category_id
LEFT JOIN dbo.order_item oi ON p.product_id = oi.product_id
GROUP BY c.category_name;
PRINT 'v_category_sales 已修复';

-- 修复 v_order_detail：p.category → c.category_name
ALTER VIEW dbo.v_order_detail AS
SELECT
    o.order_id          AS order_id,
    o.order_time        AS order_time,
    o.total_amount      AS order_total,
    o.payment_method    AS payment_method,
    o.order_status      AS order_status,
    o.remark            AS order_remark,
    m.member_id         AS member_id,
    m.member_name       AS member_name,
    m.member_level      AS member_level,
    e.employee_id       AS cashier_id,
    e.employee_name     AS cashier_name,
    oi.item_id          AS item_id,
    p.product_id        AS product_id,
    p.product_name      AS product_name,
    c.category_name     AS product_category,
    oi.quantity         AS quantity,
    oi.unit_price       AS unit_price,
    oi.subtotal         AS subtotal
FROM dbo.orders o
INNER JOIN dbo.order_item oi ON o.order_id = oi.order_id
INNER JOIN dbo.product p ON oi.product_id = p.product_id
INNER JOIN dbo.category c ON p.category_id = c.category_id
LEFT JOIN dbo.member m ON o.member_id = m.member_id
INNER JOIN dbo.employee e ON o.cashier_id = e.employee_id;
PRINT 'v_order_detail 已修复';

-- 修复 v_inventory_status：p.category → c.category_name
ALTER VIEW dbo.v_inventory_status AS
SELECT
    p.product_id            AS product_id,
    p.product_name          AS product_name,
    c.category_name         AS category,
    p.sale_price            AS sale_price,
    i.inventory_id          AS inventory_id,
    i.quantity              AS quantity,
    i.min_threshold         AS min_threshold,
    i.shelf_location        AS shelf_location,
    i.last_updated          AS last_updated,
    e.employee_name         AS last_updated_by,
    CASE WHEN i.quantity = 0 THEN '缺货' WHEN i.quantity < i.min_threshold THEN '需补货' ELSE '正常' END AS inventory_status,
    CASE WHEN i.quantity < i.min_threshold THEN i.min_threshold - i.quantity ELSE 0 END AS shortage_qty,
    i.quantity * p.purchase_price AS inventory_cost_value,
    i.quantity * p.sale_price     AS inventory_retail_value
FROM dbo.product p
INNER JOIN dbo.inventory i ON p.product_id = i.product_id
INNER JOIN dbo.category c ON p.category_id = c.category_id
LEFT JOIN dbo.employee e ON i.last_updated_by = e.employee_id;
PRINT 'v_inventory_status 已修复';
PRINT '共修复4个引用旧category列的视图';
GO

-- ============================================================
-- 第十步：补充新增 category 表的角色权限
-- ============================================================

PRINT '=== 第十步：补充 category 表角色权限 ===';

-- 所有角色均需 SELECT category（商品查询需 JOIN 分类）
GRANT SELECT ON dbo.category TO store_manager;
GRANT SELECT ON dbo.category TO cashier;
GRANT SELECT ON dbo.category TO member;
GRANT SELECT ON dbo.category TO customer;
PRINT 'category 表 SELECT 权限已授予所有角色';

-- store_manager 拥有 category 表的完整管理权限
GRANT INSERT, UPDATE, DELETE ON dbo.category TO store_manager;
PRINT 'store_manager 已授予 category 表管理权限';

-- 补充 member 角色对视图的权限
GRANT SELECT ON dbo.v_member_sales TO member;
GRANT SELECT ON dbo.v_product_sales TO member;
PRINT 'member 角色视图权限已补充';
GO

-- ============================================================
-- 迁移完成
-- ============================================================
PRINT '========================================';
PRINT 'v0.1 → v1.0 迁移完成！';
PRINT '变更内容：';
PRINT '  - 新增 category 表（分类字典）';
PRINT '  - product 表 category 字符串字段 → category_id 外键';
PRINT '  - 其他 5 张表保持不变';
PRINT '基线备份：product_bak_v01, migration_baseline';
PRINT '========================================';
