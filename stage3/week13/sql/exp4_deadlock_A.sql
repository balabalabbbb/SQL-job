-- ============================================================
-- exp4_deadlock_A.sql   实验4 死锁 —— 会话 A（订单事务，先 P 后 Q）
-- ============================================================
USE retail_store;
GO

-- A1：先更新 P 并持锁，执行后【暂停、不提交】
BEGIN TRANSACTION;
UPDATE dbo.inventory
SET quantity = quantity - 1, last_updated = SYSDATETIME()
WHERE product_id = 'P';
GO
-- A2：再请求更新 Q，被 B 阻塞 -> 等待
UPDATE dbo.inventory
SET quantity = quantity - 1, last_updated = SYSDATETIME()
WHERE product_id = 'Q';
GO
-- 形成循环后，死锁监视器终止 A 或 B（错误 1205），被终止方回滚；死锁后 P=10、Q=8

-- 改进版（统一按 product_id 升序 P->Q，一个批处理内顺序加锁）：
-- BEGIN TRANSACTION;
-- UPDATE dbo.inventory SET quantity = quantity - 1 WHERE product_id = 'P';
-- UPDATE dbo.inventory SET quantity = quantity - 1 WHERE product_id = 'Q';
-- COMMIT TRANSACTION;
-- GO
