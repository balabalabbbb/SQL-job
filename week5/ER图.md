# 第五周 ER 图（Mermaid 可编辑源文件）

> 本文档为 ER 图的可编辑源文件，使用 Mermaid erDiagram 语法。可在支持 Mermaid 的编辑器（如 Typora、VS Code + Mermaid 插件、GitHub）中直接渲染查看。
> 美观版导出图见 `ER图.html`（浏览器打开即可查看，可截图导出 PNG）。

## 符号图例

| 符号 | 含义 | 说明 |
|---|---|---|
| `||` | 恰好一个（必须参与） | 该端实体必须参与联系，且数量为1 |
| `o\|` | 零个或一个（可选参与） | 该端实体可以不参与联系，最多1个 |
| `o{` | 零个或多个（可选参与） | 该端实体可以不参与联系，数量为0或多 |
| `|{` | 一个或多个（必须参与） | 该端实体必须参与联系，至少1个 |

## ER 图

```mermaid
erDiagram
    MEMBER {
        int member_id PK "会员编号(主码)"
        string member_name "会员姓名"
        string phone UK "手机号(候选码)"
        datetime register_time "注册时间"
        int points_balance "积分余额"
        string member_level "会员等级"
        decimal total_spent "累计消费"
        datetime last_purchase_time "最后消费时间"
        string member_status "会员状态"
    }

    EMPLOYEE {
        int employee_id PK "员工编号(主码)"
        string employee_name "员工姓名"
        string position "岗位"
        string login_account UK "登录账号(候选码)"
        string login_password "密码哈希"
        string phone "手机号"
        date hire_date "入职日期"
        string employee_status "员工状态"
        datetime last_login_time "最后登录时间"
    }

    PRODUCT {
        string product_id PK "商品编号(主码)"
        string product_name "商品名称"
        string category "分类"
        decimal sale_price "售价"
        decimal purchase_price "进价"
        string unit "计量单位"
        string supplier "供应商"
        date production_date "生产日期"
        int shelf_life_days "保质期(天)"
        string status "商品状态"
    }

    INVENTORY {
        int inventory_id PK "库存记录编号(主码)"
        string product_id UK,FK "商品编号(候选码,外码)"
        int quantity "库存数量"
        string shelf_location "货架位置"
        int min_threshold "最低库存阈值"
        datetime last_updated "最后更新时间"
        int last_updated_by FK "更新人(外码)"
    }

    ORDERS {
        string order_id PK "订单号(主码)"
        datetime order_time "下单时间"
        decimal total_amount "总金额"
        string payment_method "支付方式"
        string order_status "订单状态"
        int member_id FK "会员编号(外码,可空)"
        int cashier_id FK "收银员编号(外码)"
        string remark "备注"
    }

    ORDER_ITEM {
        int item_id PK "明细编号(主码)"
        string order_id FK "订单号(外码)"
        string product_id FK "商品编号(外码)"
        int quantity "购买数量"
        decimal unit_price "成交单价"
        decimal subtotal "小计金额"
    }

    MEMBER o|--o{ ORDERS : "下单(可选,非会员订单member_id为空)"
    EMPLOYEE ||--o{ ORDERS : "收银(订单必须有收银员)"
    EMPLOYEE ||--o{ INVENTORY : "更新库存(库存必须有更新人)"
    PRODUCT ||--|| INVENTORY : "拥有(1:1,商品必须有库存记录)"
    ORDERS ||--|{ ORDER_ITEM : "包含(订单必须至少一条明细-业务规则)"
    PRODUCT ||--o{ ORDER_ITEM : "出现在(商品可出现在多条明细中)"
```

## 实体与联系说明

### 实体（6个）

| 实体 | 主码 | 候选码 | 业务含义 | 一行数据代表 |
|---|---|---|---|---|
| MEMBER（会员） | member_id | phone | 注册会员顾客 | 一个注册会员的账户信息 |
| EMPLOYEE（员工） | employee_id | login_account | 店铺工作人员 | 一名员工的账户和基本信息 |
| PRODUCT（商品） | product_id | 无 | 小卖部售卖的商品 | 一个可售卖的商品SKU |
| INVENTORY（库存） | inventory_id | product_id | 商品的库存信息 | 一个商品的当前库存状态 |
| ORDERS（订单） | order_id | 无 | 顾客的交易订单 | 一笔完成的交易记录 |
| ORDER_ITEM（订单明细） | item_id | (order_id, product_id) | 订单中每个商品的明细 | 一个订单中某商品的购买记录 |

### 联系（6个）

| 联系 | 实体A | 实体B | 基数 | A端参与 | B端参与 | 实现方式 |
|---|---|---|---|---|---|---|
| 下单 | MEMBER | ORDERS | 1:N | 可选（会员可无订单） | 可选（非会员订单） | orders.member_id 外码，可空 |
| 收银 | EMPLOYEE | ORDERS | 1:N | 必须（订单必须有收银员） | 可选（员工可无订单） | orders.cashier_id 外码，NOT NULL |
| 更新库存 | EMPLOYEE | INVENTORY | 1:N | 必须（库存必须有更新人） | 可选（员工可未更新过库存） | inventory.last_updated_by 外码，NOT NULL |
| 拥有库存 | PRODUCT | INVENTORY | 1:1 | 必须 | 必须 | inventory.product_id 外码 + UNIQUE |
| 包含明细 | ORDERS | ORDER_ITEM | 1:N | 必须（业务规则） | 必须 | order_item.order_id 外码，NOT NULL |
| 商品出现在明细 | PRODUCT | ORDER_ITEM | 1:N | 必须 | 可选（商品可无销售记录） | order_item.product_id 外码，NOT NULL |

### M:N 联系的处理

订单与商品之间本质上是 **M:N** 联系（一个订单包含多个商品，一个商品可出现在多个订单中），通过关联实体 **ORDER_ITEM（订单明细）** 实现，分解为两个 1:N 联系：
- ORDERS 1:N ORDER_ITEM
- PRODUCT 1:N ORDER_ITEM

ORDER_ITEM 除了外码外，还包含 quantity（数量）、unit_price（成交单价）、subtotal（小计）等联系自身的属性。
