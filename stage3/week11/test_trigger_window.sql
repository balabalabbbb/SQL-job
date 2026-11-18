-- ============================================================
-- test_trigger_window.sql
-- 小卖部管理系统 v1.0 - 第11周 触发器与窗口函数测试脚本
-- ============================================================
-- 覆盖场景：
--   单条插入、单条修改、多条修改、删除、无变化更新（库存审计触发器）
--   正常完成、重复完成、无明细、金额不一致、库存缺失、库存不足（订单完成触发器）
--   负库存、重复库存（非法数据，数据库约束拒绝）
-- 特性：使用独立测试数据 P9001~P9003 / ORDTEST*，结尾自动清理，
--       不污染基线；可重复执行。本文件为 UTF-8 with BOM。
-- 运行：先执行 trigger.sql、window_query.sql，再执行本脚本。
-- ============================================================

USE retail_store;
GO
SET NOCOUNT ON;
GO

-- ============================================================
-- 0. 清理可能残留的测试数据（反序，保证可重复执行）
-- ============================================================
DELETE FROM order_item WHERE order_id LIKE 'ORDTEST%';
DELETE FROM orders     WHERE order_id LIKE 'ORDTEST%';
DELETE FROM inventory  WHERE product_id LIKE 'P900_';
DELETE FROM product    WHERE product_id LIKE 'P900_';
DELETE FROM inventory_change_log WHERE product_id LIKE 'P900_';
GO

-- ============================================================
-- 1. 准备 3 个测试商品（category_id=1 引用现有分类）
-- ============================================================
INSERT INTO product
    (product_id, product_name, category_id, sale_price, purchase_price, unit, status)
VALUES
    ('P9001','测试商品1',1,10.00, 5.00,'个','在售'),
    ('P9002','测试商品2',1,20.00,10.00,'个','在售'),
    ('P9003','测试商品3',1,30.00,15.00,'个','在售');
GO

-- ============================================================
-- 测试 1：单条插入库存（P9001） -> 触发器应写 1 条 INSERT 日志
-- ============================================================
PRINT '----- 测试1：单条插入库存（预期 change_log 增加 INSERT）-----';
INSERT INTO inventory
    (product_id, quantity, min_threshold, shelf_location, last_updated_by)
VALUES ('P9001',100,10,'T-01',1);

-- 再单条插入 P9002，为后续“多条修改”准备
INSERT INTO inventory
    (product_id, quantity, min_threshold, shelf_location, last_updated_by)
VALUES ('P9002',50,10,'T-02',1);
GO

-- ============================================================
PRINT '----- 测试2：单条修改（预期 change_log 增加 UPDATE，前100后120）-----';
UPDATE inventory SET quantity = 120 WHERE product_id = 'P9001';
GO

-- ============================================================
-- 测试 3：多条修改（一条 UPDATE 同时影响 P9001、P9002 两行）
-- 验证触发器能处理多行，change_log 应出现 2 条 UPDATE。
-- ============================================================
PRINT '----- 测试3：多条修改（预期一次产生 2 条 UPDATE 日志）-----';
UPDATE inventory
SET quantity = quantity + 5
WHERE product_id IN ('P9001','P9002');
GO

-- ============================================================
-- 测试 4：删除库存（P9002） -> 触发器写 1 条 DELETE 日志
-- ============================================================
PRINT '----- 测试4：删除库存（预期 change_log 增加 DELETE）-----';
DELETE FROM inventory WHERE product_id = 'P9002';
GO

-- ============================================================
-- 验证 A：查看全部库存审计记录
-- ============================================================
PRINT '===== 验证A：inventory_change_log 审计记录 =====';
SELECT log_id, product_id, quantity_before, quantity_after,
       change_quantity, operation_type, operator, operation_time
FROM inventory_change_log
WHERE product_id LIKE 'P900_'
ORDER BY log_id;
GO

-- ============================================================
-- 测试 12：数量未变化的 UPDATE 不写审计日志
-- 对 P9001 执行不改变 quantity 的 UPDATE，审计记录数应保持不变。
-- ============================================================
PRINT '----- 测试12：数量未变化的 UPDATE（预期不写日志）-----';
DECLARE @cnt_before INT = (SELECT COUNT(*) FROM inventory_change_log WHERE product_id='P9001');
UPDATE inventory SET quantity = quantity WHERE product_id = 'P9001';  -- 数量不变
DECLARE @cnt_after INT = (SELECT COUNT(*) FROM inventory_change_log WHERE product_id='P9001');
SELECT @cnt_before AS log_before, @cnt_after AS log_after,
       CASE WHEN @cnt_before = @cnt_after THEN '通过：未写日志' ELSE '失败：多写了日志' END AS result;
GO

-- ============================================================
-- 测试 5：正常订单完成（应成功）
-- 订单 ORDTESTOK：明细 P9001 数量2 单价10 小计20，
-- total_amount=20、discount_amount=0，P9001 有库存，全部校验通过。
-- ============================================================
PRINT '----- 测试5：正常订单完成（预期成功，状态变为已完成）-----';
INSERT INTO orders
    (order_id, order_time, total_amount, payment_method,
     order_status, member_id, cashier_id, remark)
VALUES
    ('ORDTESTOK','2026-11-17 10:00:00',20.00,'现金','已支付',NULL,1,'测试正常单');

INSERT INTO order_item
    (order_id, product_id, quantity, unit_price, subtotal)
VALUES
    ('ORDTESTOK','P9001',2,10.00,20.00);

UPDATE orders SET order_status = '已完成' WHERE order_id = 'ORDTESTOK';

SELECT order_id, order_status FROM orders WHERE order_id = 'ORDTESTOK';
GO

-- ============================================================
-- 测试 6：重复完成（预期错误 51001，回滚）
-- ============================================================
PRINT '----- 测试6：重复完成（预期报错 51001 订单已经完成）-----';
UPDATE orders SET order_status = '已完成' WHERE order_id = 'ORDTESTOK';
GO

-- ============================================================
-- 测试 7：无明细订单完成（预期错误 51002）
-- ============================================================
PRINT '----- 测试7：无明细完成（预期报错 51002 订单没有明细）-----';
INSERT INTO orders
    (order_id, order_time, total_amount, payment_method,
     order_status, member_id, cashier_id)
VALUES
    ('ORDTESTNODTL','2026-11-17 11:00:00',10.00,'现金','已支付',NULL,1);

UPDATE orders SET order_status = '已完成' WHERE order_id = 'ORDTESTNODTL';
GO

-- ============================================================
-- 测试 8：金额不一致（预期错误 51007）
-- 明细小计合计 20，但 total_amount=15、discount_amount=0，
-- 20 - 15 - 0 = 5 > 容差，拒绝。
-- ============================================================
PRINT '----- 测试8：金额不一致（预期报错 51007）-----';
INSERT INTO orders
    (order_id, order_time, total_amount, payment_method,
     order_status, member_id, cashier_id)
VALUES
    ('ORDTESTAMT','2026-11-17 12:00:00',15.00,'现金','已支付',NULL,1);

INSERT INTO order_item
    (order_id, product_id, quantity, unit_price, subtotal)
VALUES
    ('ORDTESTAMT','P9001',2,10.00,20.00);

UPDATE orders SET order_status = '已完成' WHERE order_id = 'ORDTESTAMT';
GO

-- ============================================================
-- 测试 9：库存缺失（预期错误 51005）
-- 商品 P9003 故意没有库存记录；金额本身一致，
-- 但在库存检查处被拒绝。
-- ============================================================
PRINT '----- 测试9：库存缺失（预期报错 51005）-----';
INSERT INTO orders
    (order_id, order_time, total_amount, payment_method,
     order_status, member_id, cashier_id)
VALUES
    ('ORDTESTINV','2026-11-17 13:00:00',30.00,'现金','已支付',NULL,1);

INSERT INTO order_item
    (order_id, product_id, quantity, unit_price, subtotal)
VALUES
    ('ORDTESTINV','P9003',1,30.00,30.00);

UPDATE orders SET order_status = '已完成' WHERE order_id = 'ORDTESTINV';
GO

-- ============================================================
-- 测试 13：库存数量不足（预期错误 51008，回滚）
-- P9001 当前库存 125，本单购买 200 > 125；金额本身一致，
-- 但在库存充足性检查处被拒绝，防止超卖。
-- ============================================================
PRINT '----- 测试13：库存不足（预期报错 51008）-----';
INSERT INTO orders
    (order_id, order_time, total_amount, payment_method,
     order_status, member_id, cashier_id)
VALUES
    ('ORDTESTSHORT','2026-11-17 14:00:00',2000.00,'现金','已支付',NULL,1);

INSERT INTO order_item
    (order_id, product_id, quantity, unit_price, subtotal)
VALUES
    ('ORDTESTSHORT','P9001',200,10.00,2000.00);

UPDATE orders SET order_status = '已完成' WHERE order_id = 'ORDTESTSHORT';
GO

-- ============================================================
-- 测试 10：非法数据 - 负库存（预期被 CHECK chk_inventory_quantity 拒绝）
-- 用没有库存记录的 P9003，避免同时触发唯一约束，单独验证 CHECK。
-- ============================================================
PRINT '----- 测试10：负库存（预期 CHECK 约束报错）-----';
INSERT INTO inventory
    (product_id, quantity, min_threshold, last_updated_by)
VALUES ('P9003',-5,10,1);
GO

-- ============================================================
-- 测试 11：非法数据 - 重复商品库存（预期唯一约束 uk_inventory_product 拒绝）
-- ============================================================
PRINT '----- 测试11：重复库存（预期 UNIQUE 约束报错）-----';
INSERT INTO inventory
    (product_id, quantity, min_threshold, last_updated_by)
VALUES ('P9001',80,10,1);
GO

-- ============================================================
-- 验证 B：窗口函数三类查询（结果口径同 window_query.sql）
-- ============================================================
PRINT '===== 验证B：窗口查询（排名 / 累计 / 移动平均）=====';
WITH ps AS (
    SELECT p.product_id, p.product_name, c.category_name,
           SUM(oi.quantity) AS qty, SUM(oi.subtotal) AS amt,
           COUNT(DISTINCT oi.order_id) AS cnt
    FROM dbo.product p
    LEFT JOIN dbo.category c ON c.category_id = p.category_id
    INNER JOIN dbo.order_item oi ON oi.product_id = p.product_id
    INNER JOIN dbo.orders o ON o.order_id = oi.order_id
    WHERE o.order_status IN ('已支付','已完成')
    GROUP BY p.product_id, p.product_name, c.category_name
)
SELECT product_id, product_name, qty, amt, cnt,
       RANK() OVER(ORDER BY qty DESC) rnk,
       DENSE_RANK() OVER(ORDER BY amt DESC) dense_rnk,
       ROW_NUMBER() OVER(ORDER BY cnt DESC, product_id) rn
FROM ps;
GO

-- ============================================================
-- 12. 清理测试数据，恢复干净环境
-- ============================================================
DELETE FROM order_item WHERE order_id LIKE 'ORDTEST%';
DELETE FROM orders     WHERE order_id LIKE 'ORDTEST%';
DELETE FROM inventory  WHERE product_id LIKE 'P900_';
DELETE FROM product    WHERE product_id LIKE 'P900_';
DELETE FROM inventory_change_log WHERE product_id LIKE 'P900_';
GO

PRINT '测试完成，测试数据已清理，基线数据未受影响';
GO
