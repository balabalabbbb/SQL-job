-- ============================================================
-- test_procedure.sql
-- 第10周 存储过程调用与测试脚本（正常 + 异常用例）
-- ============================================================
-- 覆盖：销售统计、库存调整
-- 异常类型：空值、错误编号、错误日期、非法数量、重复调用、库存不足
-- 关键验证：异常被拒绝时，库存与调整记录均不写入不完整数据。
-- ============================================================

USE retail_store;
GO
SET NOCOUNT ON;

IF OBJECT_ID('tempdb..#proc_test') IS NOT NULL DROP TABLE #proc_test;
CREATE TABLE #proc_test (
    test_id     VARCHAR(6),
    test_name   VARCHAR(60),
    input_param VARCHAR(80),
    expected    VARCHAR(40),
    actual      VARCHAR(60),
    result      VARCHAR(10)
);

-- 建立可重复基线：P0005 恢复为 8，清空调整记录
DELETE FROM dbo.inventory_adjustment;
UPDATE dbo.inventory SET quantity = 8 WHERE product_id = 'P0005';
GO

-- ============================================================
-- 一、销售统计存储过程 usp_sales_statistics（输出参数 + 明细结果集）
-- ============================================================
DECLARE @err INT, @msg VARCHAR(200);
DECLARE @oc INT, @sq INT, @sa DECIMAL(10,2);

-- P01 正常范围：9月，输出参数返回汇总
SET @err = 0;
BEGIN TRY
    EXEC dbo.usp_sales_statistics '2026-09-01','2026-09-30',
         @oc OUTPUT, @sq OUTPUT, @sa OUTPUT;
END TRY
BEGIN CATCH SET @err = ERROR_NUMBER(); SET @msg = ERROR_MESSAGE(); END CATCH
INSERT #proc_test VALUES ('P01','销售统计-正常范围','2026-09-01~09-30','成功,订单数>0',
    '订单数=' + ISNULL(CAST(@oc AS VARCHAR),'NULL') + ' 数量=' + ISNULL(CAST(@sq AS VARCHAR),'NULL')
    + ' 金额=' + ISNULL(CAST(@sa AS VARCHAR),'NULL'),
    CASE WHEN @err = 0 AND @oc > 0 THEN 'PASS' ELSE 'FAIL' END);

-- P02 开始日期为空：错误 50001
SET @err = 0;
BEGIN TRY
    EXEC dbo.usp_sales_statistics NULL,'2026-09-30', @oc OUTPUT, @sq OUTPUT, @sa OUTPUT;
END TRY
BEGIN CATCH SET @err = ERROR_NUMBER(); SET @msg = ERROR_MESSAGE(); END CATCH
INSERT #proc_test VALUES ('P02','销售统计-开始日期为空','NULL',
    '错误50001', '错误号=' + CAST(@err AS VARCHAR), CASE WHEN @err = 50001 THEN 'PASS' ELSE 'FAIL' END);

-- P03 结束日期为空：错误 50002
SET @err = 0;
BEGIN TRY
    EXEC dbo.usp_sales_statistics '2026-09-01', NULL, @oc OUTPUT, @sq OUTPUT, @sa OUTPUT;
END TRY
BEGIN CATCH SET @err = ERROR_NUMBER(); SET @msg = ERROR_MESSAGE(); END CATCH
INSERT #proc_test VALUES ('P03','销售统计-结束日期为空','NULL',
    '错误50002', '错误号=' + CAST(@err AS VARCHAR), CASE WHEN @err = 50002 THEN 'PASS' ELSE 'FAIL' END);

-- P04 错误日期（开始晚于结束）：错误 50003
SET @err = 0;
BEGIN TRY
    EXEC dbo.usp_sales_statistics '2026-09-30','2026-09-01', @oc OUTPUT, @sq OUTPUT, @sa OUTPUT;
END TRY
BEGIN CATCH SET @err = ERROR_NUMBER(); SET @msg = ERROR_MESSAGE(); END CATCH
INSERT #proc_test VALUES ('P04','销售统计-开始晚于结束','2026-09-30~09-01',
    '错误50003', '错误号=' + CAST(@err AS VARCHAR), CASE WHEN @err = 50003 THEN 'PASS' ELSE 'FAIL' END);

-- P05 无销售范围（未来日期）：不报错，输出参数为 0
SET @err = 0; SET @oc = -1; SET @sa = -1;
BEGIN TRY
    EXEC dbo.usp_sales_statistics '2030-01-01','2030-01-31', @oc OUTPUT, @sq OUTPUT, @sa OUTPUT;
END TRY
BEGIN CATCH SET @err = ERROR_NUMBER(); END CATCH
INSERT #proc_test VALUES ('P05','销售统计-无销售记录返回0','2030-01-01~01-31','订单数0,金额0',
    '订单数=' + ISNULL(CAST(@oc AS VARCHAR),'NULL') + ' 金额=' + ISNULL(CAST(@sa AS VARCHAR),'NULL'),
    CASE WHEN @err = 0 AND @oc = 0 AND @sa = 0 THEN 'PASS' ELSE 'FAIL' END);

-- P06 重复调用一致性：同一范围两次，输出金额应相同
DECLARE @a1 DECIMAL(10,2), @a2 DECIMAL(10,2);
EXEC dbo.usp_sales_statistics '2026-09-01','2026-09-30', @oc OUTPUT, @sq OUTPUT, @a1 OUTPUT;
EXEC dbo.usp_sales_statistics '2026-09-01','2026-09-30', @oc OUTPUT, @sq OUTPUT, @a2 OUTPUT;
INSERT #proc_test VALUES ('P06','销售统计-重复调用结果一致','同一范围调用2次',
    '两次金额相同', CAST(@a1 AS VARCHAR)+' / '+CAST(@a2 AS VARCHAR),
    CASE WHEN @a1 = @a2 THEN 'PASS' ELSE 'FAIL' END);

-- ============================================================
-- 二、库存调整存储过程 usp_adjust_inventory
-- ============================================================
-- P07 正常增加（补货入库）：8 → 18
SET @err = 0;
BEGIN TRY
    EXEC dbo.usp_adjust_inventory 'P0005', 10, '补货入库', 1;
END TRY
BEGIN CATCH SET @err = ERROR_NUMBER(); SET @msg = ERROR_MESSAGE(); END CATCH
INSERT #proc_test
SELECT 'P07','库存调整-正常增加','P0005 +10','库存=18',
    '实际库存=' + CAST(quantity AS VARCHAR),
    CASE WHEN @err = 0 AND quantity = 18 THEN 'PASS' ELSE 'FAIL' END
FROM inventory WHERE product_id = 'P0005';

-- P08 正常减少（出库）：18 → 15
SET @err = 0;
BEGIN TRY
    EXEC dbo.usp_adjust_inventory 'P0005', -3, '销售出库', 2;
END TRY
BEGIN CATCH SET @err = ERROR_NUMBER(); SET @msg = ERROR_MESSAGE(); END CATCH
INSERT #proc_test
SELECT 'P08','库存调整-正常减少','P0005 -3','库存=15',
    '实际库存=' + CAST(quantity AS VARCHAR),
    CASE WHEN @err = 0 AND quantity = 15 THEN 'PASS' ELSE 'FAIL' END
FROM inventory WHERE product_id = 'P0005';

-- P09 商品不存在：错误 50014
SET @err = 0;
BEGIN TRY
    EXEC dbo.usp_adjust_inventory 'P9999', 10, '测试', 1;
END TRY
BEGIN CATCH SET @err = ERROR_NUMBER(); SET @msg = ERROR_MESSAGE(); END CATCH
INSERT #proc_test VALUES ('P09','库存调整-商品不存在','P9999',
    '错误50014', '错误号=' + CAST(@err AS VARCHAR), CASE WHEN @err = 50014 THEN 'PASS' ELSE 'FAIL' END);

-- P10 操作员不存在：错误 50015
SET @err = 0;
BEGIN TRY
    EXEC dbo.usp_adjust_inventory 'P0005', 10, '测试', 999;
END TRY
BEGIN CATCH SET @err = ERROR_NUMBER(); SET @msg = ERROR_MESSAGE(); END CATCH
INSERT #proc_test VALUES ('P10','库存调整-操作员不存在','operator=999',
    '错误50015', '错误号=' + CAST(@err AS VARCHAR), CASE WHEN @err = 50015 THEN 'PASS' ELSE 'FAIL' END);

-- P11 调整数量为零：错误 50012
SET @err = 0;
BEGIN TRY
    EXEC dbo.usp_adjust_inventory 'P0005', 0, '测试', 1;
END TRY
BEGIN CATCH SET @err = ERROR_NUMBER(); SET @msg = ERROR_MESSAGE(); END CATCH
INSERT #proc_test VALUES ('P11','库存调整-数量为零','qty=0',
    '错误50012', '错误号=' + CAST(@err AS VARCHAR), CASE WHEN @err = 50012 THEN 'PASS' ELSE 'FAIL' END);

-- P12 调整原因为空：错误 50013
SET @err = 0;
BEGIN TRY
    EXEC dbo.usp_adjust_inventory 'P0005', 10, NULL, 1;
END TRY
BEGIN CATCH SET @err = ERROR_NUMBER(); SET @msg = ERROR_MESSAGE(); END CATCH
INSERT #proc_test VALUES ('P12','库存调整-原因为空','reason=NULL',
    '错误50013', '错误号=' + CAST(@err AS VARCHAR), CASE WHEN @err = 50013 THEN 'PASS' ELSE 'FAIL' END);

-- P13 库存不足：减少 -100 超过当前15，错误 50017，且数据不变
DECLARE @before_qty INT, @before_cnt INT;
SELECT @before_qty = quantity FROM inventory WHERE product_id = 'P0005';
SET @before_cnt = (SELECT COUNT(*) FROM inventory_adjustment);
SET @err = 0;
BEGIN TRY
    EXEC dbo.usp_adjust_inventory 'P0005', -100, '测试', 1;
END TRY
BEGIN CATCH SET @err = ERROR_NUMBER(); SET @msg = ERROR_MESSAGE(); END CATCH
DECLARE @after_qty INT, @after_cnt INT;
SELECT @after_qty = quantity FROM inventory WHERE product_id = 'P0005';
SET @after_cnt = (SELECT COUNT(*) FROM inventory_adjustment);
INSERT #proc_test VALUES ('P13','库存调整-库存不足拒绝且不写入','P0005 -100',
    '错误50017且库存/记录不变',
    '错误号=' + CAST(@err AS VARCHAR) + ' 库存' + CAST(@before_qty AS VARCHAR) + '->' + CAST(@after_qty AS VARCHAR)
    + ' 记录' + CAST(@before_cnt AS VARCHAR) + '->' + CAST(@after_cnt AS VARCHAR),
    CASE WHEN @err = 50017 AND @before_qty = @after_qty AND @before_cnt = @after_cnt THEN 'PASS' ELSE 'FAIL' END);

-- P14 重复调用：连续两次 +1，库存 15→16→17，产生两条记录
SET @err = 0;
BEGIN TRY
    EXEC dbo.usp_adjust_inventory 'P0005', 1, '盘点调整', 1;
    EXEC dbo.usp_adjust_inventory 'P0005', 1, '盘点调整', 1;
END TRY
BEGIN CATCH SET @err = ERROR_NUMBER(); SET @msg = ERROR_MESSAGE(); END CATCH
INSERT #proc_test
SELECT 'P14','库存调整-重复调用逐次生效','P0005 两次+1','库存=17,记录+2',
    '库存=' + CAST(i.quantity AS VARCHAR) + ' 调整记录数=' + CAST((SELECT COUNT(*) FROM inventory_adjustment) AS VARCHAR),
    CASE WHEN @err = 0 AND i.quantity = 17 THEN 'PASS' ELSE 'FAIL' END
FROM inventory i WHERE product_id = 'P0005';

-- P15 审计记录完整性：每条记录后量=前量+调整量
INSERT #proc_test
SELECT 'P15','调整记录-前后数量勾稽一致','全部调整记录',
    '全部满足勾稽', '违规条数=' + CAST(SUM(CASE WHEN quantity_after = quantity_before + adjust_quantity THEN 0 ELSE 1 END) AS VARCHAR),
    CASE WHEN SUM(CASE WHEN quantity_after = quantity_before + adjust_quantity THEN 0 ELSE 1 END) = 0 THEN 'PASS' ELSE 'FAIL' END
FROM inventory_adjustment;

-- ============================================================
-- 输出测试结果
-- ============================================================
SELECT test_id AS 编号, test_name AS 测试项, input_param AS 输入,
       expected AS 预期, actual AS 实际, result AS 结论
FROM #proc_test ORDER BY test_id;

SELECT
    SUM(CASE WHEN result='PASS' THEN 1 ELSE 0 END) AS 通过数,
    SUM(CASE WHEN result='FAIL' THEN 1 ELSE 0 END) AS 失败数,
    COUNT(*) AS 总数
FROM #proc_test;

DROP TABLE #proc_test;
GO
