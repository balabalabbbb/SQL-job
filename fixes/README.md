# 复现兼容补丁（fixes）

本目录提供在**全新电脑上用 sqlcmd 复现本仓库**时所需的兼容脚本，解决原始脚本中已确认的批处理与命名问题。原始文件保持不动，修正脚本独立存放，均为幂等、可重复执行。

## 解决的问题

1. `01_create_database.sql` 中 `CREATE DATABASE` 与 `USE` 处于同一批，全新环境下报 Msg 911，整批不执行、数据库无法创建。
2. 仓库没有 `CREATE LOGIN retail_app`，却有多处对它的 GRANT，直接执行会报“主体不存在”。
3. `09_roles.sql` 中 `CREATE ROLE guest` 与 SQL Server 内置数据库用户 `guest` 同名，报 15023；且初次执行时视图尚未创建，对视图的 GRANT 报 15151。
4. `07_views.sql` 全文缺少 `GO`，`DROP VIEW` 与 `CREATE VIEW` 处于同一批，导致 7 个视图全部创建失败。
5. `week6/migration.sql` 中多个 `ALTER VIEW` 挤在同一批（Msg 111），且第 407 行 GRANT 引用了不存在的角色 `customer`。

## 补丁文件与执行顺序

| 顺序 | 文件 | 作用 | 执行时机 |
|---|---|---|---|
| 0 | `01_create_database_fixed.sql` | 正确分批创建并切换到 retail_store | 替代 stage1 的 `01_create_database.sql`，最先执行 |
| 1 | `00_prepare.sql` | 创建 `retail_app` 登录与用户、兼容角色 `customer` | 建库之后、执行含 GRANT 的脚本之前 |
| 2 | `07_views_fixed.sql` | 用正确的 `GO` 分批创建 7 个统计视图 | 替代 stage1 的 `07_views.sql` |
| 3 | `09_roles_fix.sql` | 补全三个自定义角色权限，guest 只读语义改由内置 guest 用户 + guest_test 实现 | stage1 `09_roles.sql` 之后 |
| 4 | `week6_view_fix.sql` | 用正确分批重新定义 week6 迁移后的 4 个视图 | `week6/migration.sql` 之后 |

## 参考执行命令

```bash
# 0) 建库（修正版，最先执行）
sqlcmd -S localhost\SQLEXPRESS -C -i 01_create_database_fixed.sql

# 1) 前置准备（登录/用户/兼容角色）
sqlcmd -S localhost\SQLEXPRESS -C -i 00_prepare.sql

# 2) 修正版视图（替代原始 07_views.sql）
sqlcmd -S localhost\SQLEXPRESS -C -i 07_views_fixed.sql

# 3) 角色权限补全
sqlcmd -S localhost\SQLEXPRESS -C -i 09_roles_fix.sql

# 4) week6 迁移后再执行视图修正
sqlcmd -S localhost\SQLEXPRESS -C -i week6_view_fix.sql
```

> 说明：以上补丁已在 Windows + SQL Server 2022 Express 真实环境验证通过。若使用 SSMS 图形界面手动分批执行，部分批处理问题不会出现，但仍需处理 `retail_app` 与 `guest` 命名问题。
