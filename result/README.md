# 执行结果目录

本目录包含小卖部管理系统 v0.1 全部 SQL 脚本在本地 MySQL 8.0.28 环境中的实际执行结果，作为可复现性的证据。

## 结果文件清单

| 序号 | 文件名 | 对应脚本 | 内容说明 |
|---|---|---|---|
| 01 | `01_create_database_result.txt` | `sql/01_create_database.sql` | 成功建库结果，显示 retail_store 数据库创建信息 |
| 02 | `02_create_tables_result.txt` | `sql/02_create_tables.sql` | 6张表创建成功，外键检查切换验证 |
| 03 | `03_insert_sample_data_result.txt` | `sql/03_insert_sample_data.sql` | 58条样例数据插入成功，各表记录数统计 |
| 04 | `04_crud_operations_result.txt` | `sql/04_crud_operations.sql` | 增删改查操作结果，含事务处理和数据恢复说明 |
| 05 | `05_index_optimization_result.txt` | `sql/05_index_optimization.sql` | 14个辅助索引创建成功，各表索引数量统计 |
| 06 | `06_queries_result.txt` | `sql/06_queries.sql` | 16个多表查询的完整结果，含连接查询、聚合统计、子查询 |
| 07 | `07_views_result.txt` | `sql/07_views.sql` | 7个统计视图创建及验证查询结果 |
| 08 | `08_constraints_result.txt` | `sql/08_constraints.sql` | 6类完整性约束验证结果，正例成功，反例预期报错说明 |
| 09 | `09_roles_result.txt` | `sql/09_roles.sql` | 4个角色创建、权限授予、测试用户创建结果 |
| 10 | `10_privilege_test_result.txt` | 越权测试 | 8个越权/正常操作测试结果，越权被拒绝，正常成功 |

## 验证环境

- **数据库版本**：MySQL 8.0.28
- **操作系统**：Windows
- **字符集**：utf8mb4
- **执行时间**：2026-09-23

## 关于截图

任务要求提交截图作为证据。本目录提供的是 SQL 执行结果的文本输出，可作为可复现性的文字证据。

**需手动补充的截图**（建议在本地执行脚本时截取）：
1. 成功建库截图（SHOW DATABASES 或 Navicat 界面）
2. 正常用例查询结果截图
3. 非法数据被拒绝截图（取消 constraint.sql 中反例注释后执行）
4. 越权访问被拒绝截图（用测试用户登录执行越权操作）
5. 关键查询结果截图（query.sql 中代表性查询）
6. CRUD操作结果截图
7. 统计视图查询结果截图
8. 不同角色权限对比截图

文本结果与截图互为补充，文本结果保证可复现，截图提供直观证据。
