-- ============================================================
-- exp1_lock_wait_B.sql   实验1 写入等待 —— 会话 B（补货事务）
-- 隔离级别：默认 READ COMMITTED
-- 用法：等 A 执行 A1 并暂停后，再执行本脚本
-- ============================================================
USE retail_store;
GO

-- B1：开启补货事务，尝试给同一 P 增加 5 件
-- 预期：B 被 A 阻塞，status=suspended、wait_type=LCK_M_U，
--       P 行更新锁（mode=U）为 WAIT；A 提交或回滚后 B 才继续
BEGIN TRANSACTION;
UPDATE dbo.inventory
SET quantity = quantity + 5, last_updated = SYSDATETIME()
WHERE product_id = 'P';
GO

-- B2：A 释放锁后本句才得以执行，提交补货
COMMIT TRANSACTION;
GO

-- 结果核对（第三个窗口）：
--   SELECT product_id, quantity FROM dbo.inventory WHERE product_id = 'P';
--   A 提交 -> 13；A 回滚 -> 15
