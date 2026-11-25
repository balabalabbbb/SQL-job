-- ============================================================
-- exp3_repeatable_read_A.sql   实验3 隔离级别对照 —— 会话 A（读取方）
-- ============================================================
USE retail_store;
GO

-- 场景A：READ COMMITTED 两次读取
SET TRANSACTION ISOLATION LEVEL READ COMMITTED;
BEGIN TRANSACTION;
SELECT quantity AS r1 FROM dbo.inventory WHERE product_id = 'P';  -- 第一次，预期 10
GO
-- 此处 B 完成补货并提交，A 再读第二次 -> 15（不可重复读）
SELECT quantity AS r2 FROM dbo.inventory WHERE product_id = 'P';  -- 预期 15
COMMIT TRANSACTION;
GO

-- 场景B（重置基线后）：REPEATABLE READ，共享锁保留到事务结束
-- SET TRANSACTION ISOLATION LEVEL REPEATABLE READ;
-- BEGIN TRANSACTION;
-- SELECT quantity AS r1 FROM dbo.inventory WHERE product_id = 'P';  -- 预期 10
-- GO
-- B 尝试补货被阻塞（wait_type=LCK_M_X），A 第二次仍读 10
-- SELECT quantity AS r2 FROM dbo.inventory WHERE product_id = 'P';  -- 预期 10
-- COMMIT TRANSACTION;  -- 提交后 B 才继续，最终 P=15
-- GO
