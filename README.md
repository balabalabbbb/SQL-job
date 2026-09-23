# 小卖部管理系统 - 数据库课程项目

## 项目范围

本项目以校园小卖部为真实经营场景，设计并实现一个完整的关系型数据库管理系统，覆盖商品管理、库存管理、订单处理、会员管理和员工管理五大核心模块。

项目周期为17周，分四个阶段完成：
- **第1-4周**：数据库初建与CRUD
- **第5-8周**：（待规划）
- **第9-12周**：（待规划）
- **第13-17周**：（待规划）

## 核心对象

本系统包含以下六类核心对象：

| 对象 | 表名 | 说明 |
|---|---|---|
| 商品 | `product` | 小卖部售卖的商品基本信息，包括编号、名称、分类、单价等 |
| 库存 | `inventory` | 商品的库存数量、货架位置、最低库存阈值 |
| 订单 | `orders` | 顾客的交易订单，包括订单编号、下单时间、总金额、支付方式 |
| 订单明细 | `order_item` | 订单中每个商品的明细，包括商品编号、数量、小计金额 |
| 会员 | `member` | 注册会员的信息，包括姓名、手机号、积分余额、会员等级 |
| 员工 | `employee` | 店铺工作人员信息，包括姓名、岗位、登录账号、权限 |

## 业务角色

本系统涉及四类业务角色，各角色职责和权限边界明确，为数据库角色权限设计提供依据：

| 角色 | 说明 | 核心职责 | 数据库角色 |
|---|---|---|---|
| 店长 | 店铺最高管理者，负责全面运营 | 商品管理、库存管理、员工管理、销售统计、财务核对 | `store_manager` |
| 店员 | 日常运营执行者，负责收银和理货 | 收银结账、商品上架、库存盘点、会员注册、顾客服务 | `cashier` |
| 会员 | 注册会员顾客，享受积分和优惠 | 购物消费、查看积分、查看个人消费记录 | `member` |
| 非会员顾客 | 普通散客，无注册信息 | 购物消费，不享受会员权益 | `guest` |

### 角色权限矩阵

| 操作/数据 | 店长 | 店员 | 会员 | 非会员顾客 |
|---|---|---|---|---|
| 查看商品信息 | ✅ | ✅ | ✅ | ✅ |
| 修改商品信息 | ✅ | ❌ | ❌ | ❌ |
| 查看库存 | ✅ | ✅ | ❌ | ❌ |
| 更新库存 | ✅ | ✅ | ❌ | ❌ |
| 创建订单 | ✅ | ✅ | ❌ | ❌（店员代建） |
| 查看订单 | ✅ | ✅ | ✅（仅本人） | ❌ |
| 删除订单 | ✅ | ❌ | ❌ | ❌ |
| 查看会员信息 | ✅ | ✅ | ✅（仅本人） | ❌ |
| 管理员工 | ✅ | ❌ | ❌ | ❌ |
| 查看销售报表 | ✅ | ❌ | ❌ | ❌ |

详细角色职能说明请参考 `week1/角色与职能清单.md`。

## 环境要求

- 数据库管理系统：MySQL 8.0+（支持CHECK约束，推荐8.0.16及以上）
- 操作系统：Windows / Linux / macOS
- 字符集：utf8mb4
- 版本控制：Git + GitHub

## 整体链路

```
顾客进店 → 浏览商品 → 挑选商品 → 店员结账 → 生成订单 → 扣减库存
     ↓
  会员积分（如为会员）
     ↓
  交接班/销售统计
     ↓
  库存预警 → 补货采购
```

## 目录结构

```
SQL-job/
├── README.md                    # 项目说明文档
├── 第一阶段报告.md               # 第一阶段（1-4周）总报告
├── sql/                         # 统一SQL脚本目录（按执行顺序编号）
│   ├── 01_create_database.sql   # 建库脚本
│   ├── 02_create_tables.sql     # 建表脚本（含约束）
│   ├── 03_insert_sample_data.sql # 样例数据插入脚本
│   ├── 04_crud_operations.sql   # 增删改查操作脚本
│   ├── 05_index_optimization.sql # 索引优化脚本
│   ├── 06_queries.sql           # 多表查询（16个查询）
│   ├── 07_views.sql             # 统计视图（7个视图）
│   ├── 08_constraints.sql       # 完整性约束验证
│   ├── 09_roles.sql             # 角色权限管理
│   └── README.md                # SQL脚本说明
├── result/                      # 执行结果目录（本地MySQL实际输出）
│   ├── 01-10_*.txt              # 各脚本执行结果文本
│   └── README.md                # 结果说明
├── week1/                       # 第一周：需求分析与业务建模
│   ├── 业务流程.md
│   ├── 角色与职能清单.md
│   ├── 数据边界清单.md
│   ├── 阶段报告.md
│   ├── AI使用记录.md
│   └── 组内分工表.md
├── week2/                       # 第二周：关系模式设计
│   ├── 表清单与关系模式设计.md
│   ├── 阶段报告.md
│   ├── AI使用记录.md
│   └── 组内分工表.md
├── week3/                       # 第三周：DDL与数据修改
│   ├── 01_create_database.sql
│   ├── 02_create_tables.sql
│   ├── 03_insert_sample_data.sql
│   ├── 04_crud_operations.sql
│   ├── 05_index_optimization.sql
│   ├── 复现说明.md
│   ├── 阶段报告.md
│   ├── AI使用记录.md
│   └── 组内分工表.md
└── week4/                       # 第四周：连接查询、视图、完整性与授权
    ├── query.sql
    ├── view.sql
    ├── constraint.sql
    ├── role.sql
    ├── 阶段报告.md
    ├── AI使用记录.md
    └── 组内分工表.md
```

## 数据库设计概要

### 表结构统计

| 表名 | 字段数 | 主码 | 唯一约束 | 外键数 | CHECK约束数 |
|---|---|---|---|---|---|
| product（商品） | 10 | product_id | 0 | 0 | 7 |
| member（会员） | 9 | member_id | 1 (phone) | 0 | 5 |
| employee（员工） | 9 | employee_id | 1 (login_account) | 0 | 3 |
| inventory（库存） | 7 | inventory_id | 1 (product_id) | 2 | 2 |
| orders（订单） | 8 | order_id | 0 | 2 | 3 |
| order_item（明细） | 6 | item_id | 1 (order_id+product_id) | 2 | 4 |
| **合计** | **49** | **6** | **4** | **6** | **24** |

### 表间关系

- `product` 1:1 `inventory`（一个商品对应一条库存记录）
- `product` 1:N `order_item`（一个商品可出现在多个订单明细中）
- `orders` 1:N `order_item`（一个订单包含多个明细）
- `member` 1:N `orders`（一个会员可有多个订单，非会员订单member_id为空）
- `employee` 1:N `orders`（一个收银员可处理多个订单）
- `employee` 1:N `inventory`（一个员工可更新多条库存记录）

## 复现步骤

### 第一周（需求分析）
本周为需求分析阶段，不涉及代码运行。产出物为业务流程文档、角色职能清单、数据边界清单。

### 第二周（关系模式设计）
本周为设计阶段，不涉及代码运行。产出物为表清单与关系模式设计文档，包含字段定义、域、主码/候选码/外码和样例元组。

### 第三周（DDL与CRUD）
按顺序执行以下SQL脚本：

```bash
# 1. 创建数据库
mysql -u root -p < week3/01_create_database.sql

# 2. 创建数据表（含约束）
mysql -u root -p retail_store < week3/02_create_tables.sql

# 3. 插入样例数据
mysql -u root -p retail_store < week3/03_insert_sample_data.sql

# 4. 执行CRUD操作演示（可选，会修改和删除数据）
mysql -u root -p retail_store < week3/04_crud_operations.sql

# 5. 创建索引优化（可选，提升查询性能）
mysql -u root -p retail_store < week3/05_index_optimization.sql
```

详细说明请参考 `week3/复现说明.md`。

### 第四周（连接查询、视图、完整性与授权）
确保已完成第三周的建库、建表、插数后，按顺序执行：

```bash
# 1. 多表查询与统计查询（16个业务查询）
mysql -u root -p retail_store < week4/query.sql

# 2. 创建统计视图（7个视图）
mysql -u root -p retail_store < week4/view.sql

# 3. 完整性约束验证（6类约束正反例）
mysql -u root -p retail_store < week4/constraint.sql

# 4. 角色权限管理（4个角色 + 越权测试）
mysql -u root -p retail_store < week4/role.sql
```

**注意**：
- `constraint.sql` 中的反例测试以注释形式呈现，手动取消注释可验证报错
- `role.sql` 会创建4个测试用户，密码分别为 Manager@123 / Cashier@123 / Member@123 / Guest@123
- 越权测试需用对应测试用户登录执行，详见 `week4/role.sql` 中的测试用例

## v0.1 阶段完整复现

从空数据库开始，依次执行以下脚本即可完整复现v0.1版本：

```bash
# 第一阶段：建库建表插数（week3）
mysql -u root -p < week3/01_create_database.sql
mysql -u root -p retail_store < week3/02_create_tables.sql
mysql -u root -p retail_store < week3/03_insert_sample_data.sql

# 第二阶段：索引优化（可选）
mysql -u root -p retail_store < week3/05_index_optimization.sql

# 第三阶段：查询与视图（week4）
mysql -u root -p retail_store < week4/query.sql
mysql -u root -p retail_store < week4/view.sql

# 第四阶段：约束与权限（week4）
mysql -u root -p retail_store < week4/constraint.sql
mysql -u root -p retail_store < week4/role.sql
```

执行完成后，数据库包含：
- 6张表、49个字段、58条样例数据
- 24个CHECK约束、6个外键、4个唯一约束
- 7个统计视图
- 4个数据库角色（店长/店员/会员/顾客）
- 14个辅助索引

## 样例数据统计

| 表名 | 记录数 |
|---|---|
| product（商品） | 10 |
| member（会员） | 5 |
| employee（员工） | 3 |
| inventory（库存） | 10 |
| orders（订单） | 10 |
| order_item（订单明细） | 20 |
| **合计** | **58** |

## 小组成员

| 姓名 | 学号 | 角色 |
|---|---|---|
| 胡海博 | 24325098 | 组长 |
| 胡懿桓 | 24325103 | 组员 |
| 林一 | 24325168 | 组员 |

## 提交记录

| 周次 | 提交信息 | 日期 |
|---|---|---|
| 初始 | Initial commit | 2026-09-11 |
| 第一周 | Add week1 deliverables: business process, roles, data boundary, report, AI log, task allocation | 2026-09-11 |
| 第二周 | Add week2 deliverables: relational schema design for 6 tables with fields, domains, keys and sample data | 2026-09-16 |
| 第三周 | Add week3 deliverables: DDL scripts, sample data, CRUD operations and documentation | 2026-09-16 |
| 第三周优化 | Optimize SQL scripts: add FOREIGN_KEY_CHECKS toggle, transaction handling, index optimization, .gitignore | 2026-09-16 |
| 第四周 | Add week4 deliverables: multi-table queries, statistical views, constraint verification, role permissions and v0.1 release | 2026-09-23 |

## 版本信息

- **当前版本**：v0.1（第一阶段完成）
- **完成时间**：2026-09-23
- **验证环境**：MySQL 8.0.28 / Windows
- **验证状态**：所有脚本在本地MySQL环境执行通过，可完整复现
