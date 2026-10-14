# 小卖部管理系统 Web 应用（第7-9周）

## 项目概述

基于 Flask 框架的四层架构 Web 应用，将前6周设计的 SQL Server 数据库（v1.0，7张表）应用到实际程序中，实现小卖部的日常经营管理。完成从用户登录、Web界面操作到数据写入的完整流程。

## 技术栈

- **Web 框架**: Flask 3.x
- **数据库**: SQL Server 2019
- **数据库驱动**: pyodbc 5.x
- **密码加密**: bcrypt
- **前端**: Jinja2 模板 + 原生 HTML/CSS/JavaScript

## 四层架构

```
┌─────────────────────────────────────────────────┐
│  页面层 (routes/)                                │
│  路由、请求校验、会话管理、模板渲染                │
│  auth_routes / product_routes / inventory_routes │
│  order_routes                                    │
├─────────────────────────────────────────────────┤
│  业务层 (services/)                              │
│  业务规则、事务边界、角色权限校验                  │
│  auth_service / order_service / product_service  │
│  inventory_service / exceptions (8类统一异常)     │
├─────────────────────────────────────────────────┤
│  数据访问层 (dal/)                               │
│  参数化SQL、连接管理、事务提交/回滚、连接释放      │
│  db.py (连接池+事务上下文)                        │
│  product_dal / inventory_dal / order_dal         │
│  member_dal / employee_dal                       │
├─────────────────────────────────────────────────┤
│  数据库层 (SQL Server)                           │
│  7张表、主外键约束、CHECK约束、角色权限            │
│  category / product / inventory / member         │
│  employee / orders / order_item                  │
└─────────────────────────────────────────────────┘
```

### 调用链路示例

**一条查询（商品列表）经过的层：**
```
浏览器 → /products/api/list (routes/product_routes.py)
       → require_login() 校验登录 (services/auth_service.py)
       → get_all_products() (services/product_service.py)
       → list_products() (dal/product_dal.py)
       → execute_query() 参数化SQL (dal/db.py)
       → SQL Server 执行 SELECT ... JOIN category
       → 结果逐层返回 → JSON 响应
```

**一条修改（创建订单）经过的层：**
```
浏览器 → /orders/api/create POST (routes/order_routes.py)
       → can_create_order() 权限校验 (services/auth_service.py)
       → create_order() 业务逻辑 (services/order_service.py)
         ├─ 校验商品存在 → get_product() (dal/product_dal.py)
         ├─ 校验库存充足 → get_inventory() (dal/inventory_dal.py)
         ├─ 开启事务 (dal/db.py transaction context)
         ├─ 写订单主表 → add_order() (dal/order_dal.py)
         ├─ 写订单明细 → add_order_item() (dal/order_dal.py)
         ├─ 扣减库存 → deduct_stock() (dal/inventory_dal.py)
         ├─ 更新积分 → add_points() (dal/member_dal.py)
         └─ 提交事务 / 失败回滚
       → JSON 响应
```

## 快速开始

### 1. 环境准备

- Python 3.10+
- SQL Server 2019+（已运行，启用TCP/IP）
- ODBC Driver 17 for SQL Server

### 2. 准备数据库

确保已执行第5-6周的建库脚本和迁移脚本，数据库为 `retail_store`，包含7张表和样例数据。

### 3. 安装依赖

```bash
pip install -r requirements.txt
```

### 4. 配置数据库连接

编辑 `config.py`，修改数据库连接信息：

```python
DB_CONFIG = {
    'server': 'localhost',
    'database': 'retail_store',
    'username': 'sa',
    'password': '你的密码',
    'driver': '{ODBC Driver 17 for SQL Server}',
}
```

### 5. 启动应用

```bash
python app.py
```

访问 http://127.0.0.1:5000

## 测试账号

| 角色 | 账号 | 密码 | 权限说明 |
|------|------|------|----------|
| 店长(manager) | manager01 | Manager@123 | 全部功能：商品CRUD、库存调整、订单创建/查询 |
| 店员(cashier) | cashier01 | Manager@123 | 查询、创建订单、库存调整，不可管理商品 |
| 顾客(customer) | 手机号 13800138001 | 无需密码 | 浏览商品、创建订单，不可管理商品和库存 |

## 核心功能

### 1. 登录认证
- 员工：账号 + 密码（bcrypt加密验证）
- 会员：手机号登录
- 会话管理：Flask session

### 2. 商品管理
- 查询：商品列表（含类别名称）、商品详情
- 新增：仅店长，含必填校验和价格非负校验
- 修改：仅店长
- 删除：仅店长
- 前端表单校验：必填项、数值范围

### 3. 库存管理
- 查询：库存列表、低库存预警（数量 ≤ 阈值标红）
- 调整：设置库存数量和预警阈值，仅员工可操作
- 库存不足时下单自动拒绝

### 4. 订单管理
- 创建订单：单事务完成6步原子操作
  1. 校验商品存在
  2. 校验库存充足
  3. 写入订单主表
  4. 写入订单明细
  5. 扣减库存
  6. 更新会员积分
- 订单查询：列表 + 明细查看
- 订单号生成：ORD + 日期(YYYYMMDD) + 4位序号

### 5. 角色权限
- 页面层：根据角色显示/隐藏操作按钮
- 业务层：`require_login()`、`require_role()` 后端强制校验
- 未登录 → 401，越权 → 403

### 6. 统一异常处理
8类业务异常，统一错误码和响应格式：

| 异常类 | 错误码 | HTTP状态 | 场景 |
|--------|--------|----------|------|
| ValidationError | VALIDATION_ERROR | 400 | 参数错误、重复主键 |
| AuthError | AUTH_ERROR | 401 | 未登录、认证失败 |
| PermissionDeniedError | PERMISSION_ERROR | 403 | 无权限操作 |
| NotFoundError | NOT_FOUND | 404 | 资源不存在 |
| BusinessRuleError | BUSINESS_RULE_ERROR | 409 | 库存不足、业务规则冲突 |
| DatabaseError | DATABASE_ERROR | 500 | 数据库连接失败 |
| ConstraintError | CONSTRAINT_ERROR | 400 | 约束冲突 |
| TransactionError | TRANSACTION_ERROR | 500 | 事务失败 |

前端只显示友好提示，不暴露SQL、堆栈、连接信息；详细错误写入后端日志。

### 7. 日志记录
- 请求日志：请求标识、时间、用户、角色、路径、方法
- 错误日志：错误码、HTTP状态、详细信息
- 日志文件：`logs/app.log`

## 集成测试

运行测试：
```bash
python integration_test.py
```

### 测试结果（18/18 通过）

| # | 测试项 | 结果 | 状态码 |
|---|--------|------|--------|
| 1 | 员工登录 | PASS | 200 |
| 2 | 商品列表查询 | PASS | 200 |
| 3 | 库存列表查询 | PASS | 200 |
| 4 | 订单列表查询 | PASS | 200 |
| 5 | 商品新增 | PASS | 200 |
| 6 | 商品修改 | PASS | 200 |
| 7 | 重复主键约束拒绝 | PASS | 400 |
| 8 | 商品删除 | PASS | 200 |
| 9 | 库存调整 | PASS | 200 |
| 10 | 创建订单（事务） | PASS | 200 |
| 11 | 订单明细查询 | PASS | 200 |
| 12 | 库存不足拒绝 | PASS | 409 |
| 13 | 非法外码拒绝 | PASS | 404 |
| 14 | 未登录拒绝 | PASS | 401 |
| 15 | 会员登录 | PASS | 200 |
| 16 | 顾客越权拒绝 | PASS | 403 |
| 17 | 店员登录 | PASS | 200 |
| 18 | 店员越权拒绝（商品管理） | PASS | 403 |

测试结果自动保存到 `test_results.txt`。

## 项目结构

```
week7-9/
├── app.py                  # Flask入口，统一异常处理、请求日志
├── config.py               # 数据库连接配置
├── requirements.txt        # 依赖清单
├── integration_test.py     # 集成测试脚本（18项）
├── test_results.txt        # 测试结果输出
├── dal/                    # 数据访问层
│   ├── __init__.py
│   ├── db.py               # 连接管理、参数化查询、事务上下文
│   ├── product_dal.py      # 商品数据访问
│   ├── inventory_dal.py    # 库存数据访问
│   ├── order_dal.py        # 订单数据访问
│   ├── member_dal.py       # 会员数据访问
│   └── employee_dal.py     # 员工数据访问
├── services/               # 业务层
│   ├── __init__.py
│   ├── exceptions.py       # 8类统一异常
│   ├── auth_service.py     # 认证授权、角色权限
│   ├── order_service.py    # 订单业务（事务）
│   ├── product_service.py  # 商品业务规则
│   └── inventory_service.py # 库存业务规则
├── routes/                 # 页面层
│   ├── __init__.py
│   ├── auth_routes.py      # 登录/登出
│   ├── product_routes.py   # 商品API
│   ├── inventory_routes.py # 库存API
│   └── order_routes.py     # 订单API
├── templates/              # 前端模板
│   ├── base.html           # 基础布局
│   ├── login.html          # 登录页
│   ├── index.html          # 首页/仪表盘
│   ├── products.html       # 商品管理（含新增/修改/删除）
│   ├── inventory.html      # 库存管理（含调整）
│   ├── orders.html         # 订单列表（含明细查看）
│   ├── order_create.html   # 创建订单
│   └── error.html          # 错误页
├── static/
│   └── style.css           # 样式
├── logs/
│   └── app.log             # 运行日志
├── README.md               # 操作手册（本文件）
├── 阶段报告.md             # 设计思路、实验过程、总结
├── 小组分工报告.md         # 成员分工
└── AI使用记录.md           # AI辅助过程记录
```

## 安全设计

1. **参数化查询**：所有SQL使用 `?` 占位符，禁止字符串拼接，防止SQL注入
2. **密码加密**：员工密码使用bcrypt哈希存储和验证
3. **后端权限校验**：页面隐藏按钮不等于权限控制，所有操作在业务层二次校验
4. **统一异常处理**：前端不暴露内部错误信息，详细错误仅记录在后端日志
5. **事务原子性**：订单创建使用数据库事务，失败自动回滚，保证数据一致性
