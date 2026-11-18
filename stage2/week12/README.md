# 第12周 递归查询与业务事务

在小卖部管理系统 v1.0 基础上，完成商品分类层级递归查询、订单完成事务和模拟补货入库事务，验证事务的原子提交与失败回滚。

## 文件清单与运行顺序

| 顺序 | 文件 | 作用 |
|---|---|---|
| 1 | `00_setup.sql` | 新建 `category_hierarchy` 层级表、`restock_order` 补货单表（幂等） |
| 2 | `recursive_query.sql` | 7 个层级样例 + 根/中间/叶子/不存在四类递归查询 |
| 3 | `order_transaction.sql` | 创建订单完成事务存储过程 `usp_complete_order_transaction` |
| 4 | `restock_transaction.sql` | 创建补货入库事务存储过程 `usp_restock_inbound_transaction` |
| 5 | `test_week12.sql` | 综合验证（提交/回滚/重复/拒绝），自动准备并清理测试数据 |
| — | `验证记录.md` | 初始数据—操作—预期—实际 记录表 |
| — | `ai_log.md` | AI 辅助与人工修改记录 |

```powershell
# 按顺序执行（go-sqlcmd）
sqlcmd -S "localhost\SQLEXPRESS" -C -d retail_store -i 00_setup.sql
sqlcmd -S "localhost\SQLEXPRESS" -C -d retail_store -i recursive_query.sql
sqlcmd -S "localhost\SQLEXPRESS" -C -d retail_store -i order_transaction.sql
sqlcmd -S "localhost\SQLEXPRESS" -C -d retail_store -i restock_transaction.sql
sqlcmd -S "localhost\SQLEXPRESS" -C -d retail_store -i test_week12.sql
```

## 一、表关系与统一库存扣减入口

围绕商品主数据 `product`，各表关系如下：

- `inventory`：通过 product_id 挂在 product 上，一商品一条库存（唯一约束）。
- `orders` 1—N `order_item`：订单明细通过 order_id 关联订单、通过 product_id 关联商品。
- `restock_order`：补货单通过 product_id 关联商品，用 restock_status 记录待入库/已入库。
- `inventory_change_log`：由第11周审计触发器在 inventory 变化时写入，记录前后数量与操作类型。
- `category_hierarchy`：独立的层级分类表，自引用 parent_id，不影响原 category 与 product 外键。

**统一库存扣减入口**：库存扣减只在订单完成事务 `usp_complete_order_transaction` 内发生；第11周触发器 `trg_order_complete_check` 只校验、不扣库存。已完成订单再次调用直接拒绝（52002），因此一次业务只扣一次、不会重复扣减。

## 二、递归逻辑

- 层级表 `category_hierarchy(cat_id, cat_name, parent_id)`，`parent_id` 自引用外键指向同表 `cat_id`。
- 递归 CTE 由两部分组成：
  - **锚点**：选中起点分类，`category_level = 1`，路径起点为自身名称。
  - **递归成员**：`INNER JOIN` 出 `parent_id = 上一层 cat_id` 的子分类，层级 +1，路径追加 ` > 子名称`，直到没有子节点自然终止。
- 输出列：`cat_id、cat_name、parent_id、category_level、hierarchy_path`。
- 路径列在锚点与递归部分统一为 `VARCHAR(400)`，`OPTION (MAXRECURSION 100)` 限制深度。

## 三、事务边界与对象调用关系

### 订单完成事务 `usp_complete_order_transaction @order_id`

一个调用对应一个事务，内部顺序：

1. 事务开启**前**前置检查：订单存在（52001）、未完成（52002）、有明细（52003）。
2. `BEGIN TRAN` 后检查明细数量 > 0（52004）。
3. 先更新订单状态为「已完成」——此时第11周触发器 `trg_order_complete_check` 基于**原始库存**做明细/商品/金额/充足性校验，不通过即抛错。
4. 再用**带条件**的集合 UPDATE 扣库存（`WHERE inventory.quantity >= 汇总需求量`），并核对受影响行数等于涉及商品数，否则抛 52005。
5. 全部成功 `COMMIT`；`CATCH` 中 `XACT_STATE()<>0` 则 `ROLLBACK` 并 `THROW`。

**为什么先改状态后扣库存**：让第11周触发器在库存被扣减前校验原始库存，避免「扣减后剩余库存被误判为不足」。触发器只校验、不扣库存，实际扣减由本存储过程负责，因此**一次业务只扣一次库存**，不重复。

### 补货入库事务 `usp_restock_inbound_transaction @restock_id, @simulate_fail`

1. 前置检查：单据存在（52101）、非已入库（52102）、数量为正（52103）、商品与库存记录存在（52104）。
2. `BEGIN TRAN` 后用 `UPDLOCK,HOLDLOCK` 读取调整前库存，再增加库存。
3. 写一条 `inventory_adjustment` 调整流水（原因「补货入库」，含前后数量），与第10周 `usp_adjust_inventory` 审计口径一致。
4. `@simulate_fail=1` 时在加库存/写流水后、单据状态更新前主动 `THROW 52199`，制造「部分写入后失败」。
5. 否则更新单据为「已入库」并写入入库时间，`COMMIT`；失败时 `ROLLBACK`，库存、调整流水与审计日志全部撤销。

## 四、设计要点（对应任务提示）

- 库存扣减使用带库存条件的 UPDATE 并检查行数，不依赖事务外的一次查询。
- 由存储过程这一层统一负责事务边界与提交，Web/存储过程/触发器不重复扣减、不各自提交。
- 审计表写入随事务回滚，不作为独立失败日志。
- 脚本全部幂等、可重复运行，为第13周并发（锁等待、隔离级别、死锁）实验做准备。
- 结束后 `@@TRANCOUNT = 0`，无残留事务。
