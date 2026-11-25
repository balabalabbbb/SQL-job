-- ============================================================
-- exp4_deadlock_B.sql   实验4 死锁 —— 会话 B（补货事务，先 Q 后 P）
-- ============================================================
USE retail_store;
GO

-- B1：先更新 Q 并持锁，执行后【暂停、不提交】
BEGIN TRANSACTION;
UPDATE dbo.inventory
SET quantity = quantity - 1, last_updated = SYSDATETIME()
WHERE product_id = 'Q';
GO
-- B2：再请求更新 P，被 A 阻塞 -> 循环等待
UPDATE dbo.inventory
SET quantity = quantity - 1, last_updated = SYSDATETIME()
WHERE product_id = 'P';
GO
-- 收到 1205 的一方回滚；死锁后 P=10、Q=8，数据一致

-- 改进版（同样按 product_id 升序 P->Q）：
-- BEGIN TRANSACTION;
-- UPDATE dbo.inventory SET quantity = quantity - 1 WHERE product_id = 'P';
-- UPDATE dbo.inventory SET quantity = quantity - 1 WHERE product_id = 'Q';
-- COMMIT TRANSACTION;
-- GO
-- 改进后 B 在 P 上即被 A 普通阻塞（单向等待、无循环），最终 P=8、Q=6
