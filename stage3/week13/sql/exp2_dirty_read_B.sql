-- ============================================================
-- exp2_dirty_read_B.sql   实验2 脏读对照 —— 会话 B（读取方）
-- ============================================================
USE retail_store;
GO

-- 场景A：READ UNCOMMITTED，A 未提交时即读到 15（脏读）
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;
SELECT quantity AS dirty_read FROM dbo.inventory WHERE product_id = 'P';  -- 预期 15
GO
-- A 回滚后再读，真实值为 10
SELECT quantity AS after_rollback FROM dbo.inventory WHERE product_id = 'P';  -- 预期 10
GO

-- 场景B（重置基线后）：READ COMMITTED，B 申请共享锁被 A 阻塞（wait_type=LCK_M_S），
-- A 回滚释放后只读到已提交的 10，读不到 15
-- SET TRANSACTION ISOLATION LEVEL READ COMMITTED;
-- SELECT quantity AS committed_read FROM dbo.inventory WHERE product_id = 'P';  -- 预期 10
-- GO
-- 说明：若库开启 RCSI，READ COMMITTED 走行版本、不等待，
-- 可在该 SELECT 加表提示 WITH (READCOMMITTEDLOCK) 强制传统锁；本库 RCSI=0，无需提示。
