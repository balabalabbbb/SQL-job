-- ============================================================
-- reset_demo.sql
-- 第10周 演示数据重置脚本（可重复执行）
-- 作用：删除浏览器/接口演示产生的测试订单，恢复库存基线，
--       清空库存调整审计表，使全部测试可从干净状态复现。
-- 口径：基线订单 13 笔（2026-09-10 至 2026-10-14），
--       P0001 基线 41、P0005 基线 8。
-- ============================================================

USE retail_store;
GO

-- 1. 删除演示订单（先删明细，再删主表，遵守外键约束）
DELETE FROM dbo.order_item
WHERE order_id IN (SELECT order_id FROM dbo.orders
                   WHERE order_time >= '2026-11-01');
DELETE FROM dbo.orders
WHERE order_time >= '2026-11-01';

-- 2. 恢复库存基线
UPDATE dbo.inventory SET quantity = 41, last_updated = GETDATE()
WHERE product_id = 'P0001';
UPDATE dbo.inventory SET quantity = 8,  last_updated = GETDATE()
WHERE product_id = 'P0005';

-- 3. 清空库存调整审计表
DELETE FROM dbo.inventory_adjustment;

-- 4. 重置校验
SELECT
    (SELECT COUNT(*) FROM dbo.orders)                 AS 订单总数,
    (SELECT COUNT(*) FROM dbo.inventory_adjustment)   AS 审计记录数;
SELECT product_id, quantity FROM dbo.inventory
WHERE product_id IN ('P0001','P0005') ORDER BY product_id;
GO
