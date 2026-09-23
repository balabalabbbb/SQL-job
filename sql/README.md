# SQL 脚本目录

本目录汇总了小卖部管理系统 v0.1 的全部 SQL 脚本，按执行顺序编号。

## 脚本清单

| 序号 | 文件名 | 说明 | 对应周次 |
|---|---|---|---|
| 01 | `01_create_database.sql` | 创建数据库 retail_store，设置 utf8mb4 字符集 | 第三周 |
| 02 | `02_create_tables.sql` | 创建6张表，含主码/外码/唯一/CHECK等全部约束 | 第三周 |
| 03 | `03_insert_sample_data.sql` | 插入58条样例数据（商品10/会员5/员工3/库存10/订单10/明细20） | 第三周 |
| 04 | `04_crud_operations.sql` | 增删改查操作演示，含事务处理和数据恢复说明 | 第三周 |
| 05 | `05_index_optimization.sql` | 14个辅助索引，提升查询性能（可选） | 第三周优化 |
| 06 | `06_queries.sql` | 16个多表查询，覆盖INNER/LEFT JOIN、GROUP BY/HAVING、子查询 | 第四周 |
| 07 | `07_views.sql` | 7个统计视图（订单详情/商品销售/库存状态/会员消费/员工业绩/每日销售/分类销售） | 第四周 |
| 08 | `08_constraints.sql` | 6类完整性约束验证，含正反例 | 第四周 |
| 09 | `09_roles.sql` | 4个数据库角色（店长/店员/会员/顾客），最小权限原则，含越权测试 | 第四周 |

## 执行顺序

```bash
# 1. 建库
mysql -u root -p < 01_create_database.sql

# 2. 建表
mysql -u root -p retail_store < 02_create_tables.sql

# 3. 插数
mysql -u root -p retail_store < 03_insert_sample_data.sql

# 4. CRUD演示（可选，会修改数据）
mysql -u root -p retail_store < 04_crud_operations.sql

# 5. 索引优化（可选）
mysql -u root -p retail_store < 05_index_optimization.sql

# 6. 多表查询
mysql -u root -p retail_store < 06_queries.sql

# 7. 统计视图
mysql -u root -p retail_store < 07_views.sql

# 8. 约束验证
mysql -u root -p retail_store < 08_constraints.sql

# 9. 角色权限
mysql -u root -p retail_store < 09_roles.sql
```

## 注意事项

- 执行 `04_crud_operations.sql` 会修改和删除样例数据，如需恢复请重新执行 `02` 和 `03`
- `08_constraints.sql` 中的反例测试以注释形式呈现，手动取消注释可验证报错
- `09_roles.sql` 会创建4个测试用户，密码分别为 Manager@123 / Cashier@123 / Member@123 / Guest@123
- 越权测试需用对应测试用户登录执行，详见脚本内测试用例
