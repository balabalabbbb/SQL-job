# 小卖部管理系统 - 第10周 存储过程与函数

## 一、项目概述

本周在 SQL Server 的 `retail_store` 数据库中，把补货选择、销售统计、库存调整、折扣计算等业务规则封装成可重复调用的**存储过程**和**函数**，全部带参数、输入检查和错误处理；随后将 Spring Boot 应用中已有的对应实现替换为数据库对象调用，页面层只负责调用与展示，不再重写业务规则。

**交付对象：**

| 类型 | 名称 | 说明 |
|------|------|------|
| 存储过程 | dbo.usp_sales_statistics | 销售统计：OUTPUT 汇总 + 明细结果集 |
| 存储过程 | dbo.usp_adjust_inventory | 库存调整：事务 + 校验 + 审计记录 |
| 标量函数 | dbo.fn_restock_qty | 建议补货量 |
| 表值函数 | dbo.fn_sales_summary | 商品销售汇总（可在 SELECT 中调用） |
| 标量函数 | dbo.fn_discount_rate | 折扣率 |
| 标量函数 | dbo.fn_discount_amount | 折扣金额 |
| 标量函数 | dbo.fn_category_discount_rate | 商品分类折扣率 |

## 二、目录结构

```
week10/
├── 00_schema_change.sql      # 结构变更：inventory_adjustment 表 + orders 折扣字段
├── procedure.sql             # 两个存储过程
├── function.sql              # 五个函数
├── test_procedure.sql        # 存储过程测试用例 P01–P15
├── test_function.sql         # 函数测试用例 F01–F18
├── reset_demo.sql            # 演示数据重置（可重复执行）
├── result_proc_raw.txt       # 存储过程测试真实输出
├── result_func_raw.txt       # 函数测试真实输出
├── 结果记录.md               # 测试结果记录（输入/预期/实际/错误/未写入验证）
├── 存储过程与函数区别.md     # 两类对象区别说明
├── 阶段报告.md               # 第10周阶段报告
├── AI使用记录.md             # AI 使用记录
├── 小组分工报告.md           # 小组分工说明
└── result/
    ├── test_report.html      # 测试结果 HTML 报告
    └── images/               # 14 张验证配图
```

## 三、环境要求

| 项目 | 要求 |
|------|------|
| 数据库 | SQL Server 2025，数据库 retail_store |
| 连接工具 | sqlcmd（或任意 SQL Server 客户端） |
| 应用账户 | retail_app（db_datareader + db_datawriter，无 DDL） |
| Web 应用 | JDK 17 + Maven + Spring Boot（位于 stage2/week7-9） |

## 四、执行步骤

### 步骤 1：结构变更（需 sa 或 db_owner）

```bash
sqlcmd -S localhost -U sa -P "Root@123456" -C -d retail_store -i 00_schema_change.sql
```

新建 `inventory_adjustment` 审计表，为 `orders` 增加 `discount_rate`、`discount_amount` 字段，并完成授权。

### 步骤 2：创建存储过程

```bash
sqlcmd -S localhost -U sa -P "Root@123456" -C -d retail_store -i procedure.sql
```

### 步骤 3：创建函数

```bash
sqlcmd -S localhost -U sa -P "Root@123456" -C -d retail_store -i function.sql
```

> 三个脚本均使用 `CREATE OR ALTER` / `IF NOT EXISTS`，可安全重复执行。含中文的脚本统一保存为 **UTF-8 with BOM**。

### 步骤 4：运行测试

```bash
sqlcmd -S localhost -U sa -P "Root@123456" -C -d retail_store -i test_function.sql
sqlcmd -S localhost -U sa -P "Root@123456" -C -d retail_store -i test_procedure.sql
```

预期结果：函数 **18/18**、存储过程 **15/15** 全部通过。

## 五、数据库对象说明

### 5.1 销售统计存储过程

`usp_sales_statistics(@start_date, @end_date, @order_count OUTPUT, @sales_qty OUTPUT, @sales_amount OUTPUT)`
- 三个 OUTPUT 参数返回整体汇总（订单数、销售数量、销售金额），一个结果集返回商品销售明细。
- 校验日期为空、开始晚于结束，错误号 50001–50003。

### 5.2 库存调整存储过程

`usp_adjust_inventory(@product_id, @adjust_qty, @reason, @operator_id)`
- 显式事务，事务内用 `WITH (UPDLOCK, HOLDLOCK)` 读取库存防并发超扣。
- 校验商品/操作员/数量为零/原因为空/库存不足，更新库存并写入审计表，错误号 50010–50017。

### 5.3 函数

| 函数 | 类型 | 规则 |
|------|------|------|
| fn_restock_qty | 标量 | 目标默认 = 阈值×2，达标返回 0，不存在返回 NULL |
| fn_sales_summary | 表值 | 返回商品编号/名称/数量/金额/订单数，可 SELECT/JOIN |
| fn_discount_rate | 标量 | 会员等级折扣与金额门槛取更优，冻结会员不享折扣 |
| fn_discount_amount | 标量 | 折前金额 ×(1−折扣率)，非法输入返回 NULL |
| fn_category_discount_rate | 标量 | 饮料 0.98、食品 0.99，其余 1.00 |

## 六、业务口径说明

1. 销售统计只计入 `order_status = '已支付'` 的订单，已取消、已退款不计入销售。
2. 日期范围**包含开始和结束当天**，结束日以"次日零点"为上界。
3. 补货目标未显式传入时，目标库存 = 最低预警阈值 × 2。
4. 折扣规则：会员等级（钻石 0.85 / 金卡 0.90 / 银卡 0.95 / 普通 1.00）与金额门槛（满 200 享 0.90、满 100 享 0.95）取更优惠者；分类折扣饮料 0.98、食品 0.99。
5. 订单 `total_amount` 保存折后成交价，明细保持原价快照，积分按折后金额计算。

## 七、重置与干净复现

测试与浏览器演示会改变数据，执行重置脚本可整体恢复干净基线：

```bash
sqlcmd -S localhost -U sa -P "Root@123456" -C -d retail_store -i reset_demo.sql
```

重置后：基线订单 13 笔、审计记录 0、P0001=41、P0005=8。

> 说明：`inventory_adjustment.adjustment_id` 为 IDENTITY 自增列，删除记录后编号不重置，因此新记录编号可能从更大的值开始，属正常现象。

## 八、测试账号

| 角色 | 账号 | 密码/方式 | 权限 |
|------|------|-----------|------|
| 店长 | manager01 | Manager@123 | 全部操作，含销售统计、库存调整 |
| 店员 | cashier01 | Manager@123 | 查询/库存/下单 |
| 会员 | 13800138001 | 手机号登录 | 查询/下单，无销售统计与调整 |

## 九、Spring Boot 整合

应用通过 `DatabaseProgramDao`（JdbcTemplate + SimpleJdbcCall）统一调用全部过程与函数：
- 标量函数用 `queryForObject`，表值函数用查询，存储过程用 `SimpleJdbcCall`，结果集通过 `returningResultSet` 映射。
- `translateError` 把错误号 ≥50000 的业务错误转换为 `BusinessRuleException`（HTTP 409），前端显示中文友好提示，原始错误号、SQL state、堆栈仅保留在后端日志。

启动应用：

```bash
mvn clean package -DskipTests
java -jar target/retail-store-1.0.0.jar
```

浏览器访问 http://localhost:8080
