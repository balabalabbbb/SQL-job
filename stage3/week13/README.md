# 第13周 并发控制实验

围绕库存和补货记录，完成锁等待、隔离级别、死锁实验并验证改进，整理第三阶段版本 **v2.0**。

## 文件清单

| 文件 | 作用 |
|------|------|
| `00_init.sql` | 初始化专用测试数据（商品 P=10、Q=8，补货单 RST_P5/RST_Q5，订单 ORD_CONC_A/B），幂等可重复执行 |
| `99_cleanup.sql` | 清理全部专用测试数据，恢复实验前状态 |
| `conc_lib.ps1` | 双会话运行库：启动 sqlcmd 进程、分步写入、输出采集、监控查询、基线重置 |
| `exp1_lock_wait.ps1` | 实验1：同一库存写入等待（A 提交→13、A 回滚→15） |
| `exp2_dirty_read.ps1` | 实验2：脏读（READ UNCOMMITTED）与已提交读（READ COMMITTED）对照 |
| `exp3_repeatable_read.ps1` | 实验3：不可重复读与可重复读（REPEATABLE READ）对照 |
| `exp4_deadlock.ps1` | 实验4：死锁构造（1205）与按编号排序更新改进 |
| `exp5_regression.ps1` | 实验5：单订单正常/重复 + 双会话竞争购买 P×6 |
| `result/exp1~5_output.txt` | 各实验真实运行输出（证据） |
| `结果记录.md` | 完整证据、锁信息与业务分析 |
| `阶段报告.md` | 第三阶段 v2.0 阶段报告（设计思路/实验过程/总结/分工） |
| `ai_log.md` | AI 辅助记录 |

## 环境前提

- SQL Server 2019+（本实验在 2022 Express，实例 `localhost\SQLEXPRESS`）
- 已完成第 10~12 周，存在 `inventory / product / orders / order_item / restock_order` 表及存储过程
- 默认隔离级别 READ COMMITTED；本库 `READ_COMMITTED_SNAPSHOT = 0`（关闭）
- 以 Windows 身份验证（`-E`）连接；如用 SQL 账号，把 `conc_lib.ps1` 中 `-E` 改为 `-U .. -P ..`

## 一键运行（PowerShell 7）

```powershell
cd stage3\week13
# 依次运行五个实验，每个脚本内部自动重置基线、采集证据
.\exp1_lock_wait.ps1
.\exp2_dirty_read.ps1
.\exp3_repeatable_read.ps1
.\exp4_deadlock.ps1
.\exp5_regression.ps1
```

也可只做数据准备与清理：

```powershell
sqlcmd -S "localhost\SQLEXPRESS" -E -d retail_store -i .\00_init.sql
sqlcmd -S "localhost\SQLEXPRESS" -E -d retail_store -i .\99_cleanup.sql
```

## 双会话手动操作步骤（SSMS 演示版）

自动化脚本对应以下手动流程，可在 SSMS 打开两个查询窗口对照执行：

**实验1（写入等待）**
1. A：`BEGIN TRAN; UPDATE inventory SET quantity=quantity-2 WHERE product_id='P';`（不提交）
2. B：`BEGIN TRAN; UPDATE inventory SET quantity=quantity+5 WHERE product_id='P';`（观察 B 等待）
3. 第三个窗口查 `sys.dm_exec_requests` 看阻塞关系
4. A：`COMMIT`（B 继续）→ P=13；或 A：`ROLLBACK` → P=15

**实验2（脏读）**
1. A：`BEGIN TRAN; UPDATE inventory SET quantity=15 WHERE product_id='P';`（不提交）
2. B：`SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED; SELECT quantity FROM inventory WHERE product_id='P';`（读到 15）
3. A：`ROLLBACK`，B 再读 → 10

**实验3（可重复读）**
1. A：`SET TRANSACTION ISOLATION LEVEL REPEATABLE READ; BEGIN TRAN; SELECT .. 'P';`
2. B：`UPDATE inventory SET quantity=quantity+5 WHERE product_id='P';`（等待）
3. A 再读仍为 10，`COMMIT` 后 B 才继续

**实验4（死锁）**
1. A 更新 P、B 更新 Q（均不提交）
2. A 更新 Q、B 更新 P → 循环等待，约 5 秒后一会话收到 1205
3. 改进：两边都按 `product_id` 升序（P→Q）更新，重跑无死锁

## 注意事项

- 取消查询不等于回滚事务；每轮结束检查 `@@TRANCOUNT`，确认无遗留后再重置
- 锁可能落在键、行、页等资源，结合 `sys.dm_tran_locks` 的 `resource_type/request_mode/request_status` 对应到具体业务数据
- 死锁 1205 后如设计重试，应重试整个业务事务并限制次数，不能只补跑最后一句
- 实验仅在专用测试数据上进行，不修改数据库共享选项（RCSI 等）
