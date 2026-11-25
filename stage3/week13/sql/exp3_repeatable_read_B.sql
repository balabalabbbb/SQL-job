-- ============================================================
-- exp3_repeatable_read_B.sql   实验3 隔离级别对照 —— 会话 B（补货方）
-- ============================================================
USE retail_store;
GO

-- B1：补货入库 +5 并提交
BEGIN TRANSACTION;
UPDATE dbo.inventory
SET quantity = quantity + 5, last_updated = SYSDATETIME()
WHERE product_id = 'P';
COMMIT TRANSACTION;
GO
-- 在 A 的 REPEATABLE READ 场景下，本句会被 A 的共享锁阻塞，直到 A 提交后才继续
