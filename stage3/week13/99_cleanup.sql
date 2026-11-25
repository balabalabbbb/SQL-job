-- ============================================================
-- 99_cleanup.sql
-- 第13周 并发控制实验：清理全部专用测试数据（幂等）
-- ============================================================
-- 删除第13周创建的商品 P/Q 及其库存、订单、补货单、审计日志。
-- 实验全部结束后执行，使数据库恢复到实验前状态。
-- ============================================================

USE retail_store;
GO
SET NOCOUNT ON;
GO

-- 删除顺序说明：
-- 1) 有外键指向 product 的表（order_item/restock_order/inventory/inventory_adjustment）
--    必须在 product 之前删除；
-- 2) 审计触发器 trg_inventory_audit 在删除 inventory 时会自动向 inventory_change_log
--    回写 DELETE 记录，因此 changelog 必须放在最后删，否则会残留触发器新写入的审计行。

DELETE FROM dbo.order_item
WHERE order_id IN ('ORD_CONC_A','ORD_CONC_B');

DELETE FROM dbo.orders
WHERE order_id IN ('ORD_CONC_A','ORD_CONC_B');

DELETE FROM dbo.restock_order
WHERE restock_id IN ('RST_P5','RST_Q5');

-- 删除库存，触发审计触发器写入 DELETE 日志
DELETE FROM dbo.inventory
WHERE product_id IN ('P','Q');

DELETE FROM dbo.inventory_adjustment
WHERE product_id IN ('P','Q');

DELETE FROM dbo.product
WHERE product_id IN ('P','Q');

-- 最后清理审计日志（含上一步触发器刚写入的 DELETE 记录）
DELETE FROM dbo.inventory_change_log
WHERE product_id IN ('P','Q');
GO

-- 确认 P/Q 已彻底移除（应返回 0 行）
SELECT product_id FROM dbo.product WHERE product_id IN ('P','Q');
PRINT '99_cleanup.sql 执行完成：第13周专用测试数据已清理';
GO
