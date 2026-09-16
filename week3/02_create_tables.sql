-- ============================================================
-- 02_create_tables.sql
-- 小卖部管理系统 - 数据表创建脚本
-- ============================================================
-- 执行说明：
--   1. 先执行 01_create_database.sql 创建并选择数据库
--   2. 执行本脚本创建六张数据表
--   3. 建表顺序：先创建被外键引用的表，再创建引用表
--   4. 删除表时按相反顺序
-- ============================================================

USE retail_store;

-- ============================================================
-- 1. 商品表 product
-- ============================================================
-- 说明：记录小卖部所有售卖商品的基本信息
-- 主码：product_id
-- 候选码：无（product_name+category+unit理论上可唯一，但不强制）
-- 外码：无
-- ============================================================

DROP TABLE IF EXISTS product;

CREATE TABLE product (
    product_id      VARCHAR(10)     NOT NULL    COMMENT '商品唯一编号，格式P+4位数字，如P0001',
    product_name    VARCHAR(100)    NOT NULL    COMMENT '商品名称',
    category        VARCHAR(20)     NOT NULL    COMMENT '商品分类：食品/饮料/日用品/文具/其他',
    sale_price      DECIMAL(8,2)    NOT NULL    COMMENT '销售单价（元），大于0',
    purchase_price  DECIMAL(8,2)    NOT NULL    COMMENT '进货单价（元），大于0，小于等于销售价',
    unit            VARCHAR(10)     NOT NULL    COMMENT '计量单位：瓶/包/个/袋/盒/斤/其他',
    supplier        VARCHAR(50)     NULL        COMMENT '供应商名称',
    production_date DATE            NULL        COMMENT '生产日期',
    shelf_life_days INT             NULL        COMMENT '保质期（天），大于0',
    status          VARCHAR(10)     NOT NULL    DEFAULT '在售'  COMMENT '商品状态：在售/下架/缺货',

    -- 主码约束
    PRIMARY KEY (product_id),

    -- 检查约束
    CONSTRAINT chk_product_sale_price      CHECK (sale_price > 0),
    CONSTRAINT chk_product_purchase_price  CHECK (purchase_price > 0),
    CONSTRAINT chk_product_price_relation  CHECK (purchase_price <= sale_price),
    CONSTRAINT chk_product_category        CHECK (category IN ('食品','饮料','日用品','文具','其他')),
    CONSTRAINT chk_product_unit            CHECK (unit IN ('瓶','包','个','袋','盒','斤','其他')),
    CONSTRAINT chk_product_status          CHECK (status IN ('在售','下架','缺货')),
    CONSTRAINT chk_product_shelf_life      CHECK (shelf_life_days IS NULL OR shelf_life_days > 0)

) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='商品表：小卖部售卖商品的基本信息';


-- ============================================================
-- 2. 会员表 member
-- ============================================================
-- 说明：记录注册会员的基本信息、积分余额、会员等级和消费统计
-- 主码：member_id
-- 候选码：phone（手机号码唯一）
-- 外码：无
-- ============================================================

DROP TABLE IF EXISTS member;

CREATE TABLE member (
    member_id           VARCHAR(10)     NOT NULL    COMMENT '会员唯一编号，格式M+4位数字，如M0001',
    member_name         VARCHAR(50)     NOT NULL    COMMENT '会员姓名',
    phone               VARCHAR(11)     NOT NULL    COMMENT '手机号码，11位数字，唯一',
    register_time       DATETIME        NOT NULL    DEFAULT CURRENT_TIMESTAMP   COMMENT '注册时间',
    points_balance      INT             NOT NULL    DEFAULT 0   COMMENT '积分余额，大于等于0',
    member_level        VARCHAR(10)     NOT NULL    DEFAULT '普通'  COMMENT '会员等级：普通/银卡/金卡',
    total_spent         DECIMAL(12,2)   NOT NULL    DEFAULT 0.00  COMMENT '累计消费金额（元），大于等于0',
    last_purchase_time  DATETIME        NULL        COMMENT '最后消费时间',
    member_status       VARCHAR(10)     NOT NULL    DEFAULT '正常'  COMMENT '会员状态：正常/冻结/注销',

    -- 主码约束
    PRIMARY KEY (member_id),

    -- 候选码（唯一约束）
    CONSTRAINT uk_member_phone UNIQUE (phone),

    -- 检查约束
    CONSTRAINT chk_member_points        CHECK (points_balance >= 0),
    CONSTRAINT chk_member_level         CHECK (member_level IN ('普通','银卡','金卡')),
    CONSTRAINT chk_member_total_spent   CHECK (total_spent >= 0),
    CONSTRAINT chk_member_status        CHECK (member_status IN ('正常','冻结','注销')),
    CONSTRAINT chk_member_phone_format  CHECK (phone REGEXP '^1[0-9]{10}$')

) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='会员表：注册会员的个人信息和积分';


-- ============================================================
-- 3. 员工表 employee
-- ============================================================
-- 说明：记录店铺工作人员的基本信息、岗位、登录账号和状态
-- 主码：employee_id（自增）
-- 候选码：login_account（登录账号唯一）
-- 外码：无
-- ============================================================

DROP TABLE IF EXISTS employee;

CREATE TABLE employee (
    employee_id     INT             NOT NULL    AUTO_INCREMENT  COMMENT '员工唯一编号，自增主键',
    employee_name   VARCHAR(50)     NOT NULL    COMMENT '员工姓名',
    position        VARCHAR(10)     NOT NULL    COMMENT '岗位：店长/店员',
    login_account   VARCHAR(20)     NOT NULL    COMMENT '登录账号，3-20字符，字母数字组合，唯一',
    login_password  VARCHAR(64)     NOT NULL    COMMENT '登录密码（bcrypt哈希值），严禁明文存储',
    phone           VARCHAR(11)     NULL        COMMENT '手机号码',
    hire_date       DATE            NOT NULL    COMMENT '入职时间',
    employee_status VARCHAR(10)     NOT NULL    DEFAULT '在职'  COMMENT '员工状态：在职/离职/休假',
    last_login_time DATETIME        NULL        COMMENT '最后登录时间',

    -- 主码约束
    PRIMARY KEY (employee_id),

    -- 候选码（唯一约束）
    CONSTRAINT uk_employee_account UNIQUE (login_account),

    -- 检查约束
    CONSTRAINT chk_employee_position  CHECK (position IN ('店长','店员')),
    CONSTRAINT chk_employee_status    CHECK (employee_status IN ('在职','离职','休假')),
    CONSTRAINT chk_employee_phone     CHECK (phone IS NULL OR phone REGEXP '^1[0-9]{10}$')

) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='员工表：店铺工作人员信息和登录凭证';


-- ============================================================
-- 4. 库存表 inventory
-- ============================================================
-- 说明：记录每个商品的当前库存数量、货架位置、最低库存阈值
-- 主码：inventory_id（自增）
-- 候选码：product_id（一个商品对应一条库存记录）
-- 外码：product_id → product(product_id)
--       last_updated_by → employee(employee_id)
-- ============================================================

DROP TABLE IF EXISTS inventory;

CREATE TABLE inventory (
    inventory_id    INT             NOT NULL    AUTO_INCREMENT  COMMENT '库存记录唯一编号，自增主键',
    product_id      VARCHAR(10)     NOT NULL    COMMENT '关联的商品编号',
    quantity        INT             NOT NULL    DEFAULT 0   COMMENT '当前库存数量，大于等于0',
    shelf_location  VARCHAR(20)     NULL        COMMENT '货架位置，如A-01表示A区第1层',
    min_threshold   INT             NOT NULL    DEFAULT 10  COMMENT '最低库存阈值，低于此值触发预警，大于等于0',
    last_updated    DATETIME        NOT NULL    DEFAULT CURRENT_TIMESTAMP   COMMENT '库存最后更新时间',
    last_updated_by INT             NOT NULL    COMMENT '最后更新操作人（员工编号）',

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

) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='库存表：商品库存数量、位置和预警阈值';


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

DROP TABLE IF EXISTS orders;

CREATE TABLE orders (
    order_id        VARCHAR(14)     NOT NULL    COMMENT '订单唯一编号，格式ORD+yyyyMMdd+4位序号，如ORD202609150001',
    order_time      DATETIME        NOT NULL    DEFAULT CURRENT_TIMESTAMP   COMMENT '下单时间',
    total_amount    DECIMAL(10,2)   NOT NULL    DEFAULT 0.00  COMMENT '订单总金额（元），大于等于0',
    payment_method  VARCHAR(10)     NOT NULL    COMMENT '支付方式：现金/微信/支付宝/其他',
    order_status    VARCHAR(10)     NOT NULL    DEFAULT '已支付'  COMMENT '订单状态：待支付/已支付/已退款/已取消',
    member_id       VARCHAR(10)     NULL        COMMENT '关联的会员编号，非会员订单为空',
    cashier_id      INT             NOT NULL    COMMENT '收银员编号',
    remark          VARCHAR(200)    NULL        COMMENT '订单备注',

    -- 主码约束
    PRIMARY KEY (order_id),

    -- 外码约束
    CONSTRAINT fk_orders_member    FOREIGN KEY (member_id)   REFERENCES member(member_id),
    CONSTRAINT fk_orders_employee  FOREIGN KEY (cashier_id)  REFERENCES employee(employee_id),

    -- 检查约束
    CONSTRAINT chk_orders_total_amount   CHECK (total_amount >= 0),
    CONSTRAINT chk_orders_payment_method CHECK (payment_method IN ('现金','微信','支付宝','其他')),
    CONSTRAINT chk_orders_status         CHECK (order_status IN ('待支付','已支付','已退款','已取消'))

) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='订单表：顾客交易订单的主表信息';


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

DROP TABLE IF EXISTS order_item;

CREATE TABLE order_item (
    item_id     INT             NOT NULL    AUTO_INCREMENT  COMMENT '明细唯一编号，自增主键',
    order_id    VARCHAR(14)     NOT NULL    COMMENT '所属订单编号',
    product_id  VARCHAR(10)     NOT NULL    COMMENT '购买的商品编号',
    quantity    INT             NOT NULL    DEFAULT 1   COMMENT '购买数量，大于0',
    unit_price  DECIMAL(8,2)    NOT NULL    COMMENT '成交时商品单价（元），大于0，记录历史成交价',
    subtotal    DECIMAL(10,2)   NOT NULL    COMMENT '小计金额（元），等于quantity × unit_price，大于0',

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

) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='订单明细表：订单中每个商品的明细记录';


-- ============================================================
-- 验证：显示所有已创建的表
-- ============================================================

SHOW TABLES;

-- 显示各表结构（可选）
-- DESCRIBE product;
-- DESCRIBE member;
-- DESCRIBE employee;
-- DESCRIBE inventory;
-- DESCRIBE orders;
-- DESCRIBE order_item;

-- ============================================================
-- 数据表创建完成
-- 建表顺序：product → member → employee → inventory → orders → order_item
-- 删除顺序：order_item → orders → inventory → employee → member → product
-- 下一步：执行 03_insert_sample_data.sql 插入样例数据
-- ============================================================
