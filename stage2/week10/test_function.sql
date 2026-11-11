-- ============================================================
-- test_function.sql
-- 第10周 函数调用与测试脚本（正常 + 异常用例）
-- ============================================================
-- 覆盖：补货量、销售汇总、折扣率、折扣金额
-- 异常类型：空值、错误编号、错误日期、非法折扣、无销售记录
-- 结果：写入临时表 #func_test，最后统一输出 PASS/FAIL。
-- ============================================================

USE retail_store;
GO
SET NOCOUNT ON;

IF OBJECT_ID('tempdb..#func_test') IS NOT NULL DROP TABLE #func_test;
CREATE TABLE #func_test (
    test_id      VARCHAR(6),
    test_name    VARCHAR(60),
    input_param  VARCHAR(80),
    expected     VARCHAR(40),
    actual       VARCHAR(40),
    result       VARCHAR(10)
);
GO

-- ------------------------------------------------------------
-- 一、补货量函数 fn_restock_qty
-- ------------------------------------------------------------
DECLARE @r INT;

-- F01 正常：P0005 当前低于目标，应返回正数
SET @r = dbo.fn_restock_qty('P0005', DEFAULT);
INSERT #func_test VALUES ('F01','补货量-低于目标返回正数','P0005, 默认目标',
    '>0', CAST(@r AS VARCHAR), CASE WHEN @r > 0 THEN 'PASS' ELSE 'FAIL' END);

-- F02 达标：P0001 库存已达目标，返回 0
SET @r = dbo.fn_restock_qty('P0001', DEFAULT);
INSERT #func_test VALUES ('F02','补货量-已达标返回0','P0001',
    '0', CAST(@r AS VARCHAR), CASE WHEN @r = 0 THEN 'PASS' ELSE 'FAIL' END);

-- F03 错误编号：不存在的商品，返回 NULL（明确处理）
SET @r = dbo.fn_restock_qty('P9999', DEFAULT);
INSERT #func_test VALUES ('F03','补货量-错误商品编号返回NULL','P9999',
    'NULL', ISNULL(CAST(@r AS VARCHAR),'NULL'), CASE WHEN @r IS NULL THEN 'PASS' ELSE 'FAIL' END);

-- F04 指定目标库存：P0005 目标100，返回 100-当前库存
SET @r = dbo.fn_restock_qty('P0005', 100);
INSERT #func_test VALUES ('F04','补货量-指定目标库存','P0005, target=100',
    '100-当前库存', CAST(@r AS VARCHAR), CASE WHEN @r = 100 - (SELECT quantity FROM inventory WHERE product_id='P0005') THEN 'PASS' ELSE 'FAIL' END);

-- F05 空值入参：商品编号为 NULL，返回 NULL
SET @r = dbo.fn_restock_qty(NULL, DEFAULT);
INSERT #func_test VALUES ('F05','补货量-空值编号返回NULL','NULL',
    'NULL', ISNULL(CAST(@r AS VARCHAR),'NULL'), CASE WHEN @r IS NULL THEN 'PASS' ELSE 'FAIL' END);

-- F06 非负验证：所有商品的补货量均不为负
INSERT #func_test
SELECT 'F06','补货量-返回值恒非负','全部商品',
    'MIN>=0', CAST(ISNULL(MIN(dbo.fn_restock_qty(product_id, DEFAULT)),0) AS VARCHAR),
    CASE WHEN MIN(dbo.fn_restock_qty(product_id, DEFAULT)) >= 0 THEN 'PASS' ELSE 'FAIL' END
FROM product;

-- ------------------------------------------------------------
-- 二、销售汇总表值函数 fn_sales_summary
-- ------------------------------------------------------------
-- F07 正常范围：可在 SELECT 中调用，行数 = 商品数
DECLARE @cnt INT;
SELECT @cnt = COUNT(*) FROM dbo.fn_sales_summary('2026-09-01','2026-09-30');
INSERT #func_test VALUES ('F07','销售汇总-正常日期范围返回全部商品','2026-09-01~09-30',
    '=商品数10', CAST(@cnt AS VARCHAR), CASE WHEN @cnt = (SELECT COUNT(*) FROM product) THEN 'PASS' ELSE 'FAIL' END);

-- F08 错误日期（开始晚于结束）：内联函数无法抛错，返回空/0值，校验由存储过程与应用层负责
SELECT @cnt = COUNT(*) FROM dbo.fn_sales_summary('2026-09-30','2026-09-01')
WHERE order_count > 0;
INSERT #func_test VALUES ('F08','销售汇总-错误日期返回空(校验在过程层)','2026-09-30~09-01',
    '0条有销售', CAST(@cnt AS VARCHAR), CASE WHEN @cnt = 0 THEN 'PASS' ELSE 'FAIL' END);

-- F09 无销售范围（未来日期）：所有商品订单数为 0
SELECT @cnt = SUM(order_count) FROM dbo.fn_sales_summary('2030-01-01','2030-01-31');
INSERT #func_test VALUES ('F09','销售汇总-无销售记录返回0','2030-01-01~01-31',
    '订单数合计0', CAST(ISNULL(@cnt,0) AS VARCHAR), CASE WHEN ISNULL(@cnt,0) = 0 THEN 'PASS' ELSE 'FAIL' END);

-- F10 表值函数可参与 JOIN（与 category 关联）
SELECT @cnt = COUNT(*)
FROM dbo.fn_sales_summary('2026-09-01','2026-09-30') s
JOIN dbo.product p ON p.product_id = s.product_id;
INSERT #func_test VALUES ('F10','销售汇总-可在SELECT/JOIN中调用','JOIN product',
    '=商品数10', CAST(@cnt AS VARCHAR), CASE WHEN @cnt = (SELECT COUNT(*) FROM product) THEN 'PASS' ELSE 'FAIL' END);

-- ------------------------------------------------------------
-- 三、折扣率函数 fn_discount_rate
-- ------------------------------------------------------------
DECLARE @rate DECIMAL(4,3);

-- F11 金卡会员（无金额门槛）：0.90
SET @rate = dbo.fn_discount_rate('M0003', 50);
INSERT #func_test VALUES ('F11','折扣率-金卡会员','M0003, 50元',
    '0.900', CAST(@rate AS VARCHAR), CASE WHEN @rate = 0.900 THEN 'PASS' ELSE 'FAIL' END);

-- F12 金额门槛：散客满200 → 0.90
SET @rate = dbo.fn_discount_rate(NULL, 250);
INSERT #func_test VALUES ('F12','折扣率-散客满200门槛','NULL, 250元',
    '0.900', CAST(@rate AS VARCHAR), CASE WHEN @rate = 0.900 THEN 'PASS' ELSE 'FAIL' END);

-- F13 不存在的会员：返回 NULL
SET @rate = dbo.fn_discount_rate('M9999', 100);
INSERT #func_test VALUES ('F13','折扣率-错误会员编号返回NULL','M9999',
    'NULL', ISNULL(CAST(@rate AS VARCHAR),'NULL'), CASE WHEN @rate IS NULL THEN 'PASS' ELSE 'FAIL' END);

-- F14 折扣率合法区间 [0,1]
INSERT #func_test
SELECT 'F14','折扣率-结果均在[0,1]','全部会员各金额',
    'MIN>=0且MAX<=1', '见左',
    CASE WHEN MIN(dbo.fn_discount_rate(member_id, 150)) >= 0
          AND MAX(dbo.fn_discount_rate(member_id, 150)) <= 1 THEN 'PASS' ELSE 'FAIL' END
FROM member;

-- ------------------------------------------------------------
-- 四、折扣金额函数 fn_discount_amount
-- ------------------------------------------------------------
DECLARE @amt DECIMAL(10,2);

-- F15 正常：150元 9折 → 折扣金额 15.00
SET @amt = dbo.fn_discount_amount(150, 0.900);
INSERT #func_test VALUES ('F15','折扣金额-正常计算','150, 0.900',
    '15.00', CAST(@amt AS VARCHAR), CASE WHEN @amt = 15.00 THEN 'PASS' ELSE 'FAIL' END);

-- F16 非法折扣率（1.5 > 1）：返回 NULL
SET @amt = dbo.fn_discount_amount(100, 1.5);
INSERT #func_test VALUES ('F16','折扣金额-非法折扣率返回NULL','100, 1.5',
    'NULL', ISNULL(CAST(@amt AS VARCHAR),'NULL'), CASE WHEN @amt IS NULL THEN 'PASS' ELSE 'FAIL' END);

-- F17 非法金额（负数）：返回 NULL
SET @amt = dbo.fn_discount_amount(-5, 0.9);
INSERT #func_test VALUES ('F17','折扣金额-非法负金额返回NULL','-5, 0.9',
    'NULL', ISNULL(CAST(@amt AS VARCHAR),'NULL'), CASE WHEN @amt IS NULL THEN 'PASS' ELSE 'FAIL' END);

-- F18 无折扣时折扣金额为 0
SET @amt = dbo.fn_discount_amount(100, 1.000);
INSERT #func_test VALUES ('F18','折扣金额-无折扣为0','100, 1.000',
    '0.00', CAST(@amt AS VARCHAR), CASE WHEN @amt = 0 THEN 'PASS' ELSE 'FAIL' END);

-- ------------------------------------------------------------
-- 输出测试结果
-- ------------------------------------------------------------
SELECT test_id AS 编号, test_name AS 测试项, input_param AS 输入,
       expected AS 预期, actual AS 实际, result AS 结论
FROM #func_test ORDER BY test_id;

SELECT
    SUM(CASE WHEN result='PASS' THEN 1 ELSE 0 END) AS 通过数,
    SUM(CASE WHEN result='FAIL' THEN 1 ELSE 0 END) AS 失败数,
    COUNT(*) AS 总数
FROM #func_test;

DROP TABLE #func_test;
GO
