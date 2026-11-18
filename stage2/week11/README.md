# 第11周 触发器与窗口函数

## 一、本周目标

使用触发器自动记录库存变化并检查订单完成条件；使用窗口函数完成排名、累计值和移动平均查询。

## 二、交付物

| 文件 | 内容 |
|---|---|
| `trigger.sql` | 库存审计触发器 `trg_inventory_audit`、订单完成规则触发器 `trg_order_complete_check`，含审计表 `inventory_change_log` 与订单状态约束扩展 |
| `window_query.sql` | 排名查询（RANK/DENSE_RANK/ROW_NUMBER）、累计值查询、移动平均查询 |
| `test_trigger_window.sql` | 单条插入/修改、多条修改、删除、正常完成、非法与拒绝、约束非法数据的完整测试 |
| `结果记录.md` | 各用例输入、预期结果与业务预期说明 |

## 三、数据库对象

| 类型 | 名称 | 说明 |
|---|---|---|
| 表 | dbo.inventory_change_log | 触发器自动维护的库存变化审计表 |
| 触发器 | dbo.trg_inventory_audit | inventory 插入/修改/删除时自动记录，支持多行 |
| 触发器 | dbo.trg_order_complete_check | 订单改为“已完成”时校验明细/商品/数量/库存/金额，拒绝非法与重复完成 |

## 四、执行方式

前提：已依次完成 stage1（01–09）、week6 迁移、week10（00_schema_change/procedure/function）。

```bash
# 1. 建触发器（以 sa 或 db_owner）
sqlcmd -S localhost -U sa -P "你的sa密码" -C -d retail_store -i trigger.sql

# 2. 窗口查询
sqlcmd -S localhost -U sa -P "你的sa密码" -C -d retail_store -i window_query.sql

# 3. 测试（自动清理测试数据，不污染基线）
sqlcmd -S localhost -U sa -P "你的sa密码" -C -d retail_store -i test_trigger_window.sql
```

所有 `.sql` 文件均保存为 **UTF-8 with BOM**，可重复执行。

## 五、设计要点

1. 触发器用 `inserted`/`deleted` 集合处理，能正确应对一次影响多行的语句。
2. 库存审计与第10周的 `inventory_adjustment`（存储过程审计）分开，职责清晰，互不冲突。
3. 订单金额校验口径：`明细原价合计 = total_amount + discount_amount`，含 0.02 舍入容差。
4. 窗口函数不减少明细行数，只在每行旁附加统计；累计值排序字段、移动平均窗口大小均明确。
