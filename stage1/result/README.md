# 执行结果目录

> **注意**：本目录下的文本结果和截图均为 **MySQL 8.0.28 环境下的历史执行记录**。项目脚本已迁移至 SQL Server，后续将在 SQL Server 环境重新验证并更新结果。历史记录保留作为参考。

本目录包含小卖部管理系统 v0.1 全部 SQL 脚本在本地环境中的实际执行结果，作为可复现性的证据。

## 结果文件清单

| 序号 | 文件名 | 对应脚本 | 内容说明 |
|---|---|---|---|
| 01 | `01_create_database_result.txt` | `../sql/01_create_database.sql` | 成功建库结果，显示 retail_store 数据库创建信息 |
| 02 | `02_create_tables_result.txt` | `../sql/02_create_tables.sql` | 6张表创建成功，外键检查切换验证 |
| 03 | `03_insert_sample_data_result.txt` | `../sql/03_insert_sample_data.sql` | 58条样例数据插入成功，各表记录数统计 |
| 04 | `04_crud_operations_result.txt` | `../sql/04_crud_operations.sql` | 增删改查操作结果，含事务处理和数据恢复说明 |
| 05 | `05_index_optimization_result.txt` | `../sql/05_index_optimization.sql` | 14个辅助索引创建成功，各表索引数量统计 |
| 06 | `06_queries_result.txt` | `../sql/06_queries.sql` | 16个多表查询的完整结果，含连接查询、聚合统计、子查询 |
| 07 | `07_views_result.txt` | `../sql/07_views.sql` | 7个统计视图创建及验证查询结果 |
| 08 | `08_constraints_result.txt` | `../sql/08_constraints.sql` | 6类完整性约束验证结果，正例成功，反例预期报错说明 |
| 09 | `09_roles_result.txt` | `../sql/09_roles.sql` | 4个角色创建、权限授予、测试用户创建结果 |
| 10 | `10_privilege_test_result.txt` | 越权测试 | 8个越权/正常操作测试结果，越权被拒绝，正常成功 |

## 验证环境（历史记录）

- **数据库版本**：MySQL 8.0.28（已迁移至 SQL Server）
- **操作系统**：Windows
- **执行时间**：2026-09-23

## 截图证据（screenshots/ 目录）

以下截图均在本地 MySQL 8.0.28 命令行中实际执行后截取（历史记录，脚本已迁移至SQL Server）：

| 序号 | 截图文件 | 内容说明 |
|---|---|---|
| 01 | `01_成功建库与正常用例.png` | 成功连接 MySQL，SHOW DATABASES 显示 retail_store 数据库，USE + SHOW TABLES 显示 6 张表和 7 个视图 |
| 02 | `02_关键查询结果.png` | 三个关键查询：订单详情多表连接（10条）、分类销售聚合统计（4类）、会员消费排行子查询（5人） |
| 03 | `03_非法数据被拒.png` | 三类非法数据被约束拒绝：负售价违反 CHECK、手机号格式违反 CHECK、类型错误被拒 |
| 04 | `04_CRUD结果.png` | 增删改查全过程：INSERT 成功 → SELECT 显示 → UPDATE 修改成功 → DELETE 删除 → 再查 Empty set |
| 05 | `05_统计视图_商品销售与库存.png` | v_product_sales 商品销售排行（前5）、v_inventory_status 库存状态（需补货/缺货） |
| 06 | `06_统计视图_每日销售与员工业绩.png` | v_daily_sales 每日销售统计（4天）、v_employee_performance 员工业绩（3人） |
| 07 | `07_店员权限结果.png` | 店员 cashier_test：查员工表被拒、删商品被拒（越权），查商品成功（正常权限） |
| 08 | `08_店长权限结果.png` | 店长 manager_test：查看员工表成功、删除测试商品成功（最高权限，无越权限制） |
| 09 | `09_会员权限结果.png` | 会员 member_test：修改商品价格被拒（越权 ERROR 1142），查看商品成功（正常权限） |
| 10 | `10_顾客权限结果.png` | 顾客 guest_test：查看订单被拒（越权 ERROR 1142），查看商品成功（正常权限） |

**角色权限截图覆盖全部4个角色**：店长（最高权限）、店员（越权×2+正常×1）、会员（越权×1+正常×1）、顾客（越权×1+正常×1），每个角色均展示越权被拒与正常权限成功的对比。

文本结果与截图互为补充：文本结果保证完整可复现，截图提供关键操作的直观证据。
