-- ============================================================
-- 02_create_tables.sql
-- 小卖部管理系统 - 数据表创建脚本 (SQL Server 版本)
-- ============================================================
-- 执行说明：
--   1. 先执行 01_create_database.sql 创建并选择数据库
--   2. 执行本脚本创建六张数据表
--   3. 建表顺序：先创建被外键引用的表，再创建引用表
--   4. 删除表时按相反顺序（子表先删，父表后删）
-- ============================================================

USE retail_store;

-- ============================================================
-- 删除已有表（按外键依赖反序：先删子表，再删父表）
-- ============================================================
DROP TABLE IF EXISTS order_item;
DROP TABLE IF EXISTS orders;
DROP TABLE IF EXISTS inventory;
DROP TABLE IF EXISTS employee;
DROP TABLE IF EXISTS member;
DROP TABLE IF EXISTS product;

-- ============================================================
-- 1. 商品表 product
-- ============================================================
-- 说明：记录小卖部所有售卖商品的基本信息
-- 主码：product_id
-- 候选码：无（product_name+category+unit理论上可唯一，但不强制）
-- 外码：无
-- ============================================================

CREATE TABLE product (
    product_id      VARCHAR(10)     NOT NULL,
    product_name    VARCHAR(100)    NOT NULL,
    category        VARCHAR(20)     NOT NULL,
    sale_price      DECIMAL(8,2)    NOT NULL,
    purchase_price  DECIMAL(8,2)    NOT NULL,
    unit            VARCHAR(10)     NOT NULL,
    supplier        VARCHAR(50)     NULL,
    production_date DATE            NULL,
    shelf_life_days INT             NULL,
    status          VARCHAR(10)     NOT NULL    DEFAULT '在售',

    -- 主码约束
    PRIMARY KEY (product_id),

    -- 检查约束
    CONSTRAINT chk_product_sale_price      CHECK (sale_price > 0),
    CONSTRAINT chk_product_purchase_price  CHECK (purchase_price > 0),
    CONSTRAINT chk_product_price_relation  CHECK (purchase_price <= sale_price),
    CONSTRAINT chk_product_category        CHECK (category IN ('食品','饮料','日用品','文具','其他')),
    CONSTRAINT chk_product_unit            CHECK (unit IN ('瓶','包','个','袋','盒','桶','支','罐','斤','其他')),
    CONSTRAINT chk_product_status          CHECK (status IN ('在售','下架','缺货')),
    CONSTRAINT chk_product_shelf_life      CHECK (shelf_life_days IS NULL OR shelf_life_days > 0)
);

-- 添加表和列注释（SQL Server 用扩展属性）
EXEC sp_addextendedproperty @name=N'MS_Description', @value=N'商品表：小卖部售卖商品的基本信息', @level0type=N'SCHEMA', @level0name=N'dbo', @level1type=N'TABLE', @level1name=N'product';


-- ============================================================
-- 2. 会员表 member
-- ============================================================
-- 说明：记录注册会员的基本信息、积分余额、会员等级和消费统计
-- 主码：member_id
-- 候选码：phone（手机号码唯一）
-- 外码：无
-- ============================================================

CREATE TABLE member (
    member_id           VARCHAR(10)     NOT NULL,
    member_name         VARCHAR(50)     NOT NULL,
    phone               VARCHAR(11)     NOT NULL,
    register_time       DATETIME        NOT NULL    DEFAULT GETDATE(),
    points_balance      INT             NOT NULL    DEFAULT 0,
    member_level        VARCHAR(10)     NOT NULL    DEFAULT '普通',
    total_spent         DECIMAL(12,2)   NOT NULL    DEFAULT 0.00,
    last_purchase_time  DATETIME        NULL,
    member_status       VARCHAR(10)     NOT NULL    DEFAULT '正常',

    -- 主码约束
    PRIMARY KEY (member_id),

    -- 候选码（唯一约束）
    CONSTRAINT uk_member_phone UNIQUE (phone),

    -- 检查约束
    CONSTRAINT chk_member_points        CHECK (points_balance >= 0),
    CONSTRAINT chk_member_level         CHECK (member_level IN ('普通','银卡','金卡')),
    CONSTRAINT chk_member_total_spent   CHECK (total_spent >= 0),
    CONSTRAINT chk_member_status        CHECK (member_status IN ('正常','冻结','注销')),
    -- SQL Server 不支持 REGEXP，用 LIKE + ISNUMERIC 模拟手机号格式校验：1开头+10位数字
    CONSTRAINT chk_member_phone_format  CHECK (LEN(phone) = 11 AND phone LIKE '1%' AND ISNUMERIC(phone) = 1)
);

EXEC sp_addextendedproperty @name=N'MS_Description', @value=N'会员表：注册会员的个人信息和积分', @level0type=N'SCHEMA', @level0name=N'dbo', @level1type=N'TABLE', @level1name=N'member';


-- ============================================================
-- 3. 员工表 employee
-- ============================================================
-- 说明：记录店铺工作人员的基本信息、岗位、登录账号和状态
-- 主码：employee_id（自增）
-- 候选码：login_account（登录账号唯一）
-- 外码：无
-- ============================================================

CREATE TABLE employee (
    employee_id     INT             NOT NULL    IDENTITY(1,1),
    employee_name   VARCHAR(50)     NOT NULL,
    position        VARCHAR(10)     NOT NULL,
    login_account   VARCHAR(20)     NOT NULL,
    login_password  VARCHAR(64)     NOT NULL,
    phone           VARCHAR(11)     NULL,
    hire_date       DATE            NOT NULL,
    employee_status VARCHAR(10)     NOT NULL    DEFAULT '在职',
    last_login_time DATETIME        NULL,

    -- 主码约束
    PRIMARY KEY (employee_id),

    -- 候选码（唯一约束）
    CONSTRAINT uk_employee_account UNIQUE (login_account),

    -- 检查约束
    CONSTRAINT chk_employee_position  CHECK (position IN ('店长','店员')),
    CONSTRAINT chk_employee_status    CHECK (employee_status IN ('在职','离职','休假')),
    CONSTRAINT chk_employee_phone     CHECK (phone IS NULL OR (LEN(phone) = 11 AND phone LIKE '1%' AND ISNUMERIC(phone) = 1))
);

EXEC sp_addextendedproperty @name=N'MS_Description', @value=N'员工表：店铺工作人员信息和登录凭证', @level0type=N'SCHEMA', @level0name=N'dbo', @level1type=N'TABLE', @level1name=N'employee';


-- ============================================================
-- 4. 库存表 inventory
-- ============================================================
-- 说明：记录每个商品的当前库存数量、货架位置、最低库存阈值
-- 主码：inventory_id（自增）
-- 候选码：product_id（一个商品对应一条库存记录）
-- 外码：product_id → product(product_id)
--       last_updated_by → employee(employee_id)
-- ============================================================

CREATE TABLE inventory (
    inventory_id    INT             NOT NULL    IDENTITY(1,1),
    product_id      VARCHAR(10)     NOT NULL,
    quantity        INT             NOT NULL    DEFAULT 0,
    shelf_location  VARCHAR(20)     NULL,
    min_threshold   INT             NOT NULL    DEFAULT 10,
    last_updated    DATETIME        NOT NULL    DEFAULT GETDATE(),
    last_updated_by INT             NOT NULL,

    -- 主码约束
    PRIMARY KEY (inventory_id),

    -- 候选码（唯一约束）：一个商品对应一条库存记录
    CONSTRAINT uk_inventory_product UNIQUE (product_id),

    -- 外码约束
    CONSTRAINT fk_inventory_product   FOREIGN KEY (product_id)      REFERENCES product(product_id),
    CONSTRAINT fk_inventory_employee  FOREIGN KEY (last_updated_by) REFERENCES employee(employee_id),

    -- 检查约束
    CONSTRAINT chk_inventory_quantity    CHECK (quantity >= 0),
    CONSTRAINT chk_inventory_threshold   CHECK (min_threshold >= 0)
);

EXEC sp_addextendedproperty @name=N'MS_Description', @value=N'库存表：商品库存数量、位置和预警阈值', @level0type=N'SCHEMA', @level0name=N'dbo', @level1type=N'TABLE', @level1name=N'inventory';


-- ============================================================
-- 5. 订单表 orders
-- ============================================================
-- 说明：记录顾客每笔交易订单的主信息
-- 主码：order_id
-- 候选码：无
-- 外码：member_id → member(member_id)（可空，非会员订单）
--       cashier_id → employee(employee_id)
-- 注意：表名用orders而非order，因为order是SQL保留字
-- ============================================================

CREATE TABLE orders (
    order_id        VARCHAR(20)     NOT NULL,
    order_time      DATETIME        NOT NULL    DEFAULT GETDATE(),
    total_amount    DECIMAL(10,2)   NOT NULL    DEFAULT 0.00,
    payment_method  VARCHAR(10)     NOT NULL,
    order_status    VARCHAR(10)     NOT NULL    DEFAULT '已支付',
    member_id       VARCHAR(10)     NULL,
    cashier_id      INT             NOT NULL,
    remark          VARCHAR(200)    NULL,

    -- 主码约束
    PRIMARY KEY (order_id),

    -- 外码约束
    CONSTRAINT fk_orders_member    FOREIGN KEY (member_id)   REFERENCES member(member_id),
    CONSTRAINT fk_orders_employee  FOREIGN KEY (cashier_id)  REFERENCES employee(employee_id),

    -- 检查约束
    CONSTRAINT chk_orders_total_amount   CHECK (total_amount >= 0),
    CONSTRAINT chk_orders_payment_method CHECK (payment_method IN ('现金','微信','支付宝','其他')),
    CONSTRAINT chk_orders_status         CHECK (order_status IN ('待支付','已支付','已退款','已取消'))
);

EXEC sp_addextendedproperty @name=N'MS_Description', @value=N'订单表：顾客交易订单的主表信息', @level0type=N'SCHEMA', @level0name=N'dbo', @level1type=N'TABLE', @level1name=N'orders';


-- ============================================================
-- 6. 订单明细表 order_item
-- ============================================================
-- 说明：记录每个订单中包含的商品明细，一单多商品必须拆分明细
-- 主码：item_id（自增）
-- 候选码：(order_id, product_id)（同一订单中同一商品通常只出现一行）
-- 外码：order_id → orders(order_id)
--       product_id → product(product_id)
-- 注意：unit_price字段冗余存储成交时单价，用于记录历史价格，
--       防止商品涨价后影响历史订单，这是有意的反范式设计
-- ============================================================

CREATE TABLE order_item (
    item_id     INT             NOT NULL    IDENTITY(1,1),
    order_id    VARCHAR(20)     NOT NULL,
    product_id  VARCHAR(10)     NOT NULL,
    quantity    INT             NOT NULL    DEFAULT 1,
    unit_price  DECIMAL(8,2)    NOT NULL,
    subtotal    DECIMAL(10,2)   NOT NULL,

    -- 主码约束
    PRIMARY KEY (item_id),

    -- 候选码（唯一约束）：同一订单中同一商品只出现一行
    CONSTRAINT uk_order_item_order_product UNIQUE (order_id, product_id),

    -- 外码约束
    CONSTRAINT fk_order_item_orders   FOREIGN KEY (order_id)   REFERENCES orders(order_id),
    CONSTRAINT fk_order_item_product  FOREIGN KEY (product_id) REFERENCES product(product_id),

    -- 检查约束
    CONSTRAINT chk_order_item_quantity   CHECK (quantity > 0),
    CONSTRAINT chk_order_item_unit_price CHECK (unit_price > 0),
    CONSTRAINT chk_order_item_subtotal   CHECK (subtotal > 0),
    CONSTRAINT chk_order_item_calc       CHECK (subtotal = quantity * unit_price)
);

EXEC sp_addextendedproperty @name=N'MS_Description', @value=N'订单明细表：订单中每个商品的明细记录', @level0type=N'SCHEMA', @level0name=N'dbo', @level1type=N'TABLE', @level1name=N'order_item';


-- ============================================================
-- 验证：显示所有已创建的表
-- ============================================================

SELECT name AS 表名, create_date AS 创建时间
FROM sys.tables
ORDER BY name;

-- 显示各表字段（可选）
SELECT TABLE_NAME AS 表名, COLUMN_NAME AS 字段名, DATA_TYPE AS 数据类型, IS_NULLABLE AS 允许空
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_CATALOG = 'retail_store'
ORDER BY TABLE_NAME, ORDINAL_POSITION;

-- ============================================================
-- 数据表创建完成
-- 建表顺序：product → member → employee → inventory → orders → order_item
-- 删除顺序：order_item → orders → inventory → employee → member → product
-- 下一步：执行 03_insert_sample_data.sql 插入样例数据
-- ============================================================
