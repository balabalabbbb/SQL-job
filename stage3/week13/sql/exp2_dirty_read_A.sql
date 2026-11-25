-- ============================================================
-- exp2_dirty_read_A.sql   实验2 脏读对照 —— 会话 A（补货事务，制造未提交值）
-- 隔离级别：默认 READ COMMITTED
-- ============================================================
USE retail_store;
GO

-- A1：把 P 从 10 改为 15，执行后【暂停、不提交】
BEGIN TRANSACTION;
UPDATE dbo.inventory
SET quantity = 15, last_updated = SYSDATETIME()
WHERE product_id = 'P';
GO

-- A2：B 完成读取后执行回滚，P 恢复为 10
ROLLBACK TRANSACTION;
GO
