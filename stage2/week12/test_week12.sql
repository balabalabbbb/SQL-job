-- ============================================================
-- test_week12.sql
-- 第12周 递归查询与业务事务 综合验证脚本
-- ============================================================
-- 覆盖：
--   订单事务：正常提交、重复完成、订单不存在、无明细、库存不足
--   补货事务：正常提交、重复入库、中途失败回滚、补货单不存在、补货量非正数拒绝
-- 每步前后检查 orders / order_item / inventory / restock_order /
--   inventory_change_log 全部相关表，不只展示报错。
-- 独立测试数据 P8001/P8002、ORD12*、RST12*，结尾自动清理，可重复执行。
-- ============================================================

USE retail_store;
GO
SET NOCOUNT ON;
GO

-- ============================================================
-- 阶段 0：清理残留 + 准备测试商品 P、Q 及库存
-- ============================================================
DELETE FROM order_item       WHERE order_id LIKE 'ORD12%';
DELETE FROM orders           WHERE order_id LIKE 'ORD12%';
DELETE FROM restock_order    WHERE restock_id LIKE 'RST12%';
DELETE FROM inventory_adjustment WHERE product_id IN ('P8001','P8002') AND reason = '补货入库';
DELETE FROM inventory        WHERE product_id IN ('P8001','P8002');
DELETE FROM inventory_change_log WHERE product_id IN ('P8001','P8002');
DELETE FROM product          WHERE product_id IN ('P8001','P8002');
GO

INSERT INTO product (product_id, product_name, category_id, sale_price, purchase_price, unit, status)
VALUES ('P8001','测试商品P',1,10.00,6.00,'个','在售'),
       ('P8002','测试商品Q',1,20.00,12.00,'个','在售');
INSERT INTO inventory (product_id, quantity, min_threshold, shelf_location, last_updated_by)
VALUES ('P8001',50,10,'T-81',1),
       ('P8002',40,10,'T-82',1);
GO

PRINT '===== 初始库存（P8001=50，P8002=40）=====';
SELECT product_id, quantity FROM inventory
WHERE product_id IN ('P8001','P8002') ORDER BY product_id;
GO

-- ############################################################
-- # 一、订单完成事务
-- ############################################################

-- 1.1 准备正常订单 ORD12OK（含 P、Q 两种商品，金额一致）
INSERT INTO orders (order_id, order_time, total_amount, payment_method, order_status, member_id, cashier_id)
VALUES ('ORD12OK','2026-11-18 09:00:00',70.00,'现金','已支付',NULL,1);
INSERT INTO order_item (order_id, product_id, quantity, unit_price, subtotal)
VALUES ('ORD12OK','P8001',3,10.00,30.00),
       ('ORD12OK','P8002',2,20.00,40.00);
GO

PRINT '----- 订单测试1：正常完成（预期提交，P8001=47、P8002=38）-----';
EXEC dbo.usp_complete_order_transaction @order_id = 'ORD12OK';
SELECT order_id, order_status FROM orders WHERE order_id = 'ORD12OK';
SELECT product_id, quantity FROM inventory
WHERE product_id IN ('P8001','P8002') ORDER BY product_id;
GO

PRINT '----- 订单测试2：重复完成（预期 52002，库存不再变化）-----';
EXEC dbo.usp_complete_order_transaction @order_id = 'ORD12OK';
GO

PRINT '----- 订单测试3：订单不存在（预期 52001）-----';
EXEC dbo.usp_complete_order_transaction @order_id = 'ORD12NOEXIST';
GO

-- 1.4 无明细订单
INSERT INTO orders (order_id, order_time, total_amount, payment_method, order_status, member_id, cashier_id)
VALUES ('ORD12NODTL','2026-11-18 09:10:00',10.00,'现金','已支付',NULL,1);
PRINT '----- 订单测试4：无明细（预期 52003）-----';
EXEC dbo.usp_complete_order_transaction @order_id = 'ORD12NODTL';
GO

-- 1.5 库存不足订单（P8001 当前 47，需求 9999）
INSERT INTO orders (order_id, order_time, total_amount, payment_method, order_status, member_id, cashier_id)
VALUES ('ORD12SHORT','2026-11-18 09:20:00',99990.00,'现金','已支付',NULL,1);
INSERT INTO order_item (order_id, product_id, quantity, unit_price, subtotal)
VALUES ('ORD12SHORT','P8001',9999,10.00,99990.00);
PRINT '----- 订单测试5：库存不足（预期回滚，订单仍已支付、库存不变）-----';
EXEC dbo.usp_complete_order_transaction @order_id = 'ORD12SHORT';
GO
SELECT order_id, order_status FROM orders WHERE order_id = 'ORD12SHORT';
SELECT product_id, quantity FROM inventory WHERE product_id = 'P8001';
GO

-- ############################################################
-- # 二、补货入库事务
-- ############################################################

-- 2.1 正常补货单 RST12OK（P8002 补 20）
INSERT INTO restock_order (restock_id, product_id, restock_quantity, operator_id)
VALUES ('RST12OK','P8002',20,1);
PRINT '----- 补货测试1：正常入库（预期提交，P8002 增加20，单据已入库）-----';
EXEC dbo.usp_restock_inbound_transaction @restock_id = 'RST12OK', @simulate_fail = 0;
SELECT restock_id, product_id, restock_quantity, restock_status, inbound_time
FROM restock_order WHERE restock_id = 'RST12OK';
SELECT product_id, quantity FROM inventory WHERE product_id = 'P8002';
-- 核对库存调整流水（预期 1 条，reason=补货入库，前后数量正确）
SELECT product_id, adjust_quantity, quantity_before, quantity_after, reason
FROM inventory_adjustment
WHERE product_id = 'P8002' AND reason = '补货入库';
GO

PRINT '----- 补货测试2：重复入库（预期 52102，库存不再增加）-----';
EXEC dbo.usp_restock_inbound_transaction @restock_id = 'RST12OK', @simulate_fail = 0;
GO

-- 2.3 中途失败补货单 RST12FAIL（P8001 补 10，模拟失败）
INSERT INTO restock_order (restock_id, product_id, restock_quantity, operator_id)
VALUES ('RST12FAIL','P8001',10,1);
PRINT '----- 补货测试3：中途失败（预期 52199，库存与单据全部回滚）-----';
SELECT quantity AS P8001_before FROM inventory WHERE product_id = 'P8001';
EXEC dbo.usp_restock_inbound_transaction @restock_id = 'RST12FAIL', @simulate_fail = 1;
GO
PRINT '【回滚后核对：P8001 库存不变，单据仍待入库，调整流水与审计均无新增】';
SELECT product_id, quantity FROM inventory WHERE product_id = 'P8001';
SELECT restock_id, restock_status, inbound_time FROM restock_order WHERE restock_id = 'RST12FAIL';
-- 调整流水应被回滚：预期 0 条
SELECT COUNT(*) AS adjustment_rollback_count
FROM inventory_adjustment
WHERE product_id = 'P8001' AND reason = '补货入库';
GO

PRINT '----- 补货测试4：补货单不存在（预期 52101）-----';
EXEC dbo.usp_restock_inbound_transaction @restock_id = 'RST12NOEXIST', @simulate_fail = 0;
GO

-- 2.5 补货量非正数：由表 CHECK 约束 chk_restock_quantity 在写入时拒绝（Msg 547）
PRINT '----- 补货测试5：补货量非正数（预期 547 拒绝，不写入）-----';
INSERT INTO restock_order (restock_id, product_id, restock_quantity, operator_id)
VALUES ('RST12ZERO','P8001',0,1);
INSERT INTO restock_order (restock_id, product_id, restock_quantity, operator_id)
VALUES ('RST12NEG','P8001',-5,1);
GO

-- ############################################################
-- # 三、审计表核对（触发器在事务内的记录情况）
-- ############################################################
PRINT '===== 审计表 inventory_change_log（P8001/P8002）=====';
SELECT log_id, product_id, quantity_before, quantity_after, change_quantity, operation_type
FROM inventory_change_log
WHERE product_id IN ('P8001','P8002')
ORDER BY log_id;
GO

-- ############################################################
-- # 四、清理测试数据，恢复干净环境
-- ############################################################
DELETE FROM order_item       WHERE order_id LIKE 'ORD12%';
DELETE FROM orders           WHERE order_id LIKE 'ORD12%';
DELETE FROM restock_order    WHERE restock_id LIKE 'RST12%';
DELETE FROM inventory_adjustment WHERE product_id IN ('P8001','P8002') AND reason = '补货入库';
DELETE FROM inventory        WHERE product_id IN ('P8001','P8002');
DELETE FROM inventory_change_log WHERE product_id IN ('P8001','P8002');
DELETE FROM product          WHERE product_id IN ('P8001','P8002');
GO

PRINT '测试完成，测试数据已清理';
SELECT @@TRANCOUNT AS trancount_should_be_0;
GO
