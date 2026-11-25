-- ============================================================
-- exp1_lock_wait_A.sql   实验1 写入等待 —— 会话 A（订单事务）
-- 隔离级别：默认 READ COMMITTED（本库 RCSI=0，走传统锁）
-- 用法：先执行 00_init.sql 建立基线 P=10，再与 exp1_lock_wait_B.sql 配合
-- ============================================================
USE retail_store;
GO

-- A1：开启订单事务，扣减 P 2 件（10->8），执行后【暂停、不提交】
-- 预期：A 持有 inventory 中 P 行的键排他锁（resource_type=KEY, mode=X, status=GRANT）
BEGIN TRANSACTION;
UPDATE dbo.inventory
SET quantity = quantity - 2, last_updated = SYSDATETIME()
WHERE product_id = 'P';
GO
-- 此时切到 B 会话执行 B1，观察 B 被阻塞。第三个窗口可查询：
--   SELECT session_id, blocking_session_id, status, wait_type
--   FROM sys.dm_exec_requests WHERE blocking_session_id <> 0;
--   SELECT request_session_id, resource_type, request_mode, request_status
--   FROM sys.dm_tran_locks WHERE resource_database_id = DB_ID('retail_store');

-- A2（二选一，按实验场景）：
-- 场景A【提交】：B 解除阻塞继续，最终 P = 13（10-2+5）
COMMIT TRANSACTION;
GO

-- 场景B【回滚】：注释掉上面的 COMMIT、改用下面的 ROLLBACK，
-- 扣减撤销，B 继续后最终 P = 15（10+5）
-- ROLLBACK TRANSACTION;
-- GO
