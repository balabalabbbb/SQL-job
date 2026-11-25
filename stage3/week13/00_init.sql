-- ============================================================
-- 00_init.sql
-- 小卖部管理系统 v2.0 - 第13周 并发控制实验：初始化（幂等，可重复执行）
-- ============================================================
-- 建立专用测试数据，不污染原有 P0001~P0010 基线：
--   商品 P（库存10）、商品 Q（库存8）
--   待入库补货单 RST_P5（P+5）、RST_Q5（Q+5）
--   两个待完成订单 ORD_CONC_A / ORD_CONC_B（各购买 P×6，无折扣）
-- 每轮实验前执行本脚本即可恢复干净基线。
-- 以 db_owner / Windows 管理员身份执行。
-- ============================================================

USE retail_store;
GO
SET NOCOUNT ON;
GO

-- 1) 清理上一轮实验残留（按外键依赖顺序）
DELETE FROM dbo.order_item
WHERE order_id IN ('ORD_CONC_A','ORD_CONC_B');

DELETE FROM dbo.orders
WHERE order_id IN ('ORD_CONC_A','ORD_CONC_B');

DELETE FROM dbo.restock_order
WHERE restock_id IN ('RST_P5','RST_Q5');

-- 清理 P/Q 的审计与调整日志，保证每轮证据从干净基线开始
DELETE FROM dbo.inventory_change_log
WHERE product_id IN ('P','Q');

DELETE FROM dbo.inventory_adjustment
WHERE product_id IN ('P','Q');

DELETE FROM dbo.inventory
WHERE product_id IN ('P','Q');

DELETE FROM dbo.product
WHERE product_id IN ('P','Q');
GO

-- 2) 专用实验商品
INSERT INTO dbo.product
    (product_id, product_name, sale_price, purchase_price, unit,
     supplier, status, category_id)
VALUES
    ('P', '并发实验商品P', 5.00, 3.00, '个', '实验供应商', '在售', 2),
    ('Q', '并发实验商品Q', 5.00, 3.00, '个', '实验供应商', '在售', 2);
GO

-- 3) 库存：P=10，Q=8（inventory_id 为 IDENTITY，不手填）
INSERT INTO dbo.inventory
    (product_id, quantity, shelf_location, min_threshold,
     last_updated, last_updated_by)
VALUES
    ('P', 10, 'A-01', 5, SYSDATETIME(), 1),
    ('Q', 8,  'A-02', 5, SYSDATETIME(), 1);
GO

-- 4) 待入库补货单
INSERT INTO dbo.restock_order
    (restock_id, product_id, restock_quantity, restock_status,
     operator_id, create_time)
VALUES
    ('RST_P5', 'P', 5, '待入库', 1, SYSDATETIME()),
    ('RST_Q5', 'Q', 5, '待入库', 1, SYSDATETIME());
GO

-- 5) 两个待完成订单（各 P×6，单价5，小计30，无折扣，金额自洽）
INSERT INTO dbo.orders
    (order_id, order_time, total_amount, payment_method, order_status,
     member_id, cashier_id, remark, discount_rate, discount_amount)
VALUES
    ('ORD_CONC_A', SYSDATETIME(), 30.00, '现金', '待支付',
     NULL, 1, '并发回归订单A', 1.000, 0.00),
    ('ORD_CONC_B', SYSDATETIME(), 30.00, '现金', '待支付',
     NULL, 1, '并发回归订单B', 1.000, 0.00);

INSERT INTO dbo.order_item
    (order_id, product_id, quantity, unit_price, subtotal)
VALUES
    ('ORD_CONC_A', 'P', 6, 5.00, 30.00),
    ('ORD_CONC_B', 'P', 6, 5.00, 30.00);
GO

-- 6) 清理重建过程中审计触发器写入的 P/Q 日志（删旧库存的 DELETE、插新库存的 INSERT），
--    保证基线 changelog 干净，与“每轮证据从干净基线开始”一致
DELETE FROM dbo.inventory_change_log
WHERE product_id IN ('P','Q');
GO

-- 7) 基线核对
SELECT product_id, quantity
FROM dbo.inventory
WHERE product_id IN ('P','Q')
ORDER BY product_id;

SELECT restock_id, product_id, restock_quantity, restock_status
FROM dbo.restock_order
ORDER BY restock_id;

PRINT '00_init.sql 执行完成：P=10、Q=8，测试订单与补货单已就绪';
GO
