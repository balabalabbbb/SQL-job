# 第三阶段提交物（数据库业务与事务实验）

本目录为第三阶段（week10–week13）对外提交的成品文件，代码与过程记录仍在同级 `week10`–`week13` 各目录中。

| 文件 | 说明 |
|---|---|
| `阶段报告.docx` | 阶段总报告，含四个部分正文与 19 张真实运行截图（图 1–图 19）及图注 |
| `组内分工.md` | 小组分工与贡献占比 |

## 真实运行截图（19 张）

全部截图为 2026-11-25 在本机 Windows Terminal + sqlcmd 上对 `retail_store` 库的**实际执行画面**（非拼接、非推导），与各周 `result/` 下的原始输出文本出自同一次运行。原图同时归档在对应周的 `result/screenshots/` 目录。

| 图号 | 文件 | 所在路径 | 内容要点 |
|---|---|---|---|
| 图 1 | `01_存储过程正常调用.png` | `week10/result/screenshots/` | `usp_sales_statistics` 正常调用：订单数 9、销量 37、金额 141.00 |
| 图 2 | `02_存储过程测试15项全通过.png` | `week10/result/screenshots/` | P01–P15 逐项比对，15 项全部 PASS |
| 图 3 | `03_函数测试18项全通过.png` | `week10/result/screenshots/` | F01–F18 逐项比对，18 项全部 PASS |
| 图 4 | `04_库存调整补货与出库.png` | `week10/result/screenshots/` | P0005 由 8 → 18 → 15，调整流水 2 条 |
| 图 5 | `05_函数非法输入返回NULL.png` | `week10/result/screenshots/` | 商品不存在、空编号、折扣率越界、负金额统一返回 NULL |
| 图 6 | `06_库存审计触发器.png` | `week11/result/screenshots/` | 6 条真实变化各写 1 条日志（log_id 676–681） |
| 图 7 | `07_订单完成触发器五规则.png` | `week11/result/screenshots/` | 51001/51002/51007/51005/51008 五类拒绝全部触发 |
| 图 8 | `08_窗口函数排名.png` | `week11/result/screenshots/` | RANK 并列跳号、DENSE_RANK 不跳号、ROW_NUMBER 唯一 |
| 图 9 | `09_窗口函数累计与移动平均.png` | `week11/result/screenshots/` | 累计金额 7.00→151.50，近 3 笔移动平均逐行滑动 |
| 图 10 | `10_递归CTE层级路径.png` | `week12/result/screenshots/` | 根节点 7 行层级 1–3，叶子 1 行，不存在编号 0 行 |
| 图 11 | `11_订单完成事务提交.png` | `week12/result/screenshots/` | ORD13OK 提交，P8101 50→47、P8102 40→38，`@@TRANCOUNT=0` |
| 图 12 | `12_订单完成事务回滚51008.png` | `week12/result/screenshots/` | 库存不足报 51008，回滚后订单仍已支付、库存与日志不变 |
| 图 13 | `13_补货入库事务提交.png` | `week12/result/screenshots/` | RST13OK 提交，P8102 40→60，单据变已入库 |
| 图 14 | `14_补货入库事务回滚52199.png` | `week12/result/screenshots/` | 模拟中途失败报 52199，库存、单据状态、流水均回滚 |
| 图 15 | `15_实验1锁等待.png` | `week13/result/screenshots/` | A 排他锁 GRANT、B 的 U 锁 WAIT，A 提交后 B 继续，最终 P=15 |
| 图 16 | `16_实验2脏读对照.png` | `week13/result/screenshots/` | READ UNCOMMITTED 读到未提交 15；READ COMMITTED 只读到 10 |
| 图 17 | `17_实验3不可重复读对照.png` | `week13/result/screenshots/` | READ COMMITTED 两次读 10→15；REPEATABLE READ 两次均为 10 |
| 图 18 | `18_实验4死锁与按序更新.png` | `week13/result/screenshots/` | 交叉更新互相等待、A 报 1205；按 product_id 升序后无 1205 |
| 图 19 | `19_实验5并发购买回归.png` | `week13/result/screenshots/` | 重复完成报 52002；双会话竞争仅 A 成功，最终 P=4 |

## 编号差异说明

截图复跑为避免与历史数据冲突，对测试编号做了替换：审计/规则测试用 P9101–P9102 与 ORD9101–ORD9105，事务测试用 P8101/P8102 与 ORD13OK/ORD13SHORT、RST13OK/RST13FAIL，并发实验会话号为 52/53/62/71/72。各周文档末尾的「真实运行截图」一节已逐条列出对应关系与实测值差异，结论（用例通过、事务原子性、锁与隔离级别行为）与正文一致。
