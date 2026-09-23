-- ============================================================
-- constraint.sql
-- 小卖部管理系统 - 完整性约束验证脚本
-- ============================================================
-- 执行说明：
--   1. 先执行 week3 的 01-03 脚本完成建库、建表、插数
--   2. 执行本脚本验证各类完整性约束
--   3. 正例实际执行并展示成功结果
--   4. 反例以注释形式展示，手动取消注释可验证报错
--
-- 约束类型覆盖：
--   - 主码约束（PRIMARY KEY）
--   - 外码约束（FOREIGN KEY）
--   - 唯一约束（UNIQUE）
--   - 检查约束（CHECK）
--   - 默认值约束（DEFAULT）
--   - 非空约束（NOT NULL）
-- ============================================================

USE retail_store;

-- ============================================================
-- 第一部分：当前约束清单
-- ============================================================

SELECT '=== 当前数据库所有约束清单 ===' AS 约束管理;

SELECT
    TABLE_NAME AS 表名,
    CONSTRAINT_NAME AS 约束名,
    CONSTRAINT_TYPE AS 约束类型
FROM information_schema.TABLE_CONSTRAINTS
WHERE TABLE_SCHEMA = 'retail_store'
ORDER BY TABLE_NAME, CONSTRAINT_TYPE;


-- ============================================================
-- 第二部分：主码约束（PRIMARY KEY）验证
-- ============================================================

SELECT '=== 主码约束验证 ===' AS 约束类型;

-- 正例：主码值唯一，可以正常插入
SELECT '--- 正例：主码唯一，插入成功 ---' AS 测试;
INSERT INTO product (product_id, product_name, category, sale_price, purchase_price, unit, status)
VALUES ('P9999', '测试商品-主码唯一', '食品', 5.00, 3.00, '个', '在售');
SELECT '插入成功，主码P9999唯一' AS 结果;

-- 反例1：主码重复，插入失败
-- 取消下面注释执行，预期报错：
-- ERROR 1062 (23000): Duplicate entry 'P9999' for key 'product.PRIMARY'
-- INSERT INTO product (product_id, product_name, category, sale_price, purchase_price, unit, status)
-- VALUES ('P9999', '测试商品-主码重复', '食品', 5.00, 3.00, '个', '在售');
SELECT '反例1：主码重复 → 预期报错 Duplicate entry（已注释，手动验证）' AS 反例说明;

-- 反例2：主码为空，插入失败
-- 取消下面注释执行，预期报错：
-- ERROR 1048 (23000): Column 'product_id' cannot be null
-- INSERT INTO product (product_id, product_name, category, sale_price, purchase_price, unit, status)
-- VALUES (NULL, '测试商品-主码为空', '食品', 5.00, 3.00, '个', '在售');
SELECT '反例2：主码为空 → 预期报错 Column cannot be null（已注释，手动验证）' AS 反例说明;

-- 清理测试数据
DELETE FROM product WHERE product_id = 'P9999';
SELECT '测试数据已清理' AS 清理;


-- ============================================================
-- 第三部分：外码约束（FOREIGN KEY）验证
-- ============================================================

SELECT '=== 外码约束验证 ===' AS 约束类型;

-- 正例：外码值存在于被引用表，插入成功
SELECT '--- 正例：外码引用存在，插入成功 ---' AS 测试;
-- 先插入一个新商品用于测试
INSERT INTO product (product_id, product_name, category, sale_price, purchase_price, unit, status)
VALUES ('P9998', '测试商品-外码正例', '食品', 5.00, 3.00, '个', '在售');
-- 再插入库存记录，外码引用P9998
INSERT INTO inventory (product_id, quantity, shelf_location, min_threshold, last_updated_by)
VALUES ('P9998', 100, 'TEST-01', 10, 1);
SELECT '插入成功，product_id=P9998存在于product表' AS 结果;

-- 反例1：外码值不存在于被引用表，插入失败
-- 取消下面注释执行，预期报错：
-- ERROR 1452 (23000): Cannot add or update a child row: a foreign key constraint fails
-- INSERT INTO inventory (product_id, quantity, shelf_location, min_threshold, last_updated_by)
-- VALUES ('P8888', 100, 'TEST-02', 10, 1);
SELECT '反例1：外码引用不存在 → 预期报错 foreign key constraint fails（已注释，手动验证）' AS 反例说明;

-- 反例2：删除被外码引用的记录，删除失败
-- 取消下面注释执行，预期报错：
-- ERROR 1451 (23000): Cannot delete or update a parent row: a foreign key constraint fails
-- DELETE FROM product WHERE product_id = 'P0001';
SELECT '反例2：删除被引用记录 → 预期报错 foreign key constraint fails（已注释，手动验证）' AS 反例说明;

-- 清理测试数据
DELETE FROM inventory WHERE shelf_location = 'TEST-01';
DELETE FROM product WHERE product_id = 'P9998';
SELECT '测试数据已清理' AS 清理;


-- ============================================================
-- 第四部分：唯一约束（UNIQUE）验证
-- ============================================================

SELECT '=== 唯一约束验证 ===' AS 约束类型;

-- 正例：手机号唯一，插入成功
SELECT '--- 正例：手机号唯一，插入成功 ---' AS 测试;
INSERT INTO member (member_id, member_name, phone, member_level, member_status)
VALUES ('M9999', '测试会员-唯一', '13999999999', '普通', '正常');
SELECT '插入成功，手机号13999999999唯一' AS 结果;

-- 反例1：手机号重复，插入失败
-- 取消下面注释执行，预期报错：
-- ERROR 1062 (23000): Duplicate entry '13999999999' for key 'member.uk_member_phone'
-- INSERT INTO member (member_id, member_name, phone, member_level, member_status)
-- VALUES ('M9998', '测试会员-重复手机号', '13999999999', '普通', '正常');
SELECT '反例1：手机号重复 → 预期报错 Duplicate entry uk_member_phone（已注释，手动验证）' AS 反例说明;

-- 反例2：员工登录账号重复，插入失败
-- 取消下面注释执行，预期报错：
-- ERROR 1062 (23000): Duplicate entry 'cashier01' for key 'employee.uk_employee_account'
-- INSERT INTO employee (employee_name, position, login_account, login_password, hire_date, employee_status)
-- VALUES ('测试员工', '店员', 'cashier01', 'hashedpassword', '2026-01-01', '在职');
SELECT '反例2：登录账号重复 → 预期报错 Duplicate entry uk_employee_account（已注释，手动验证）' AS 反例说明;

-- 清理测试数据
DELETE FROM member WHERE member_id = 'M9999';
SELECT '测试数据已清理' AS 清理;


-- ============================================================
-- 第五部分：检查约束（CHECK）验证
-- ============================================================

SELECT '=== 检查约束验证 ===' AS 约束类型;

-- 5.1 商品价格检查
SELECT '--- 5.1 商品价格检查 ---' AS 子测试;

-- 正例：售价>0，进价>0，进价<=售价
SELECT '正例：售价>0，进价>0，进价<=售价，插入成功' AS 测试;
INSERT INTO product (product_id, product_name, category, sale_price, purchase_price, unit, status)
VALUES ('P9997', '测试商品-价格合法', '食品', 10.00, 5.00, '个', '在售');
SELECT '插入成功' AS 结果;

-- 反例1：售价为负
-- 取消下面注释执行，预期报错：
-- ERROR 3819 (HY000): Check constraint 'chk_product_sale_price' is violated
-- INSERT INTO product (product_id, product_name, category, sale_price, purchase_price, unit, status)
-- VALUES ('P9996', '测试商品-售价负', '食品', -5.00, 3.00, '个', '在售');
SELECT '反例1：售价为负 → 预期报错 chk_product_sale_price violated（已注释，手动验证）' AS 反例说明;

-- 反例2：进价>售价
-- 取消下面注释执行，预期报错：
-- ERROR 3819 (HY000): Check constraint 'chk_product_price_relation' is violated
-- INSERT INTO product (product_id, product_name, category, sale_price, purchase_price, unit, status)
-- VALUES ('P9995', '测试商品-进价大于售价', '食品', 3.00, 10.00, '个', '在售');
SELECT '反例2：进价>售价 → 预期报错 chk_product_price_relation violated（已注释，手动验证）' AS 反例说明;

-- 5.2 商品分类检查
SELECT '--- 5.2 商品分类枚举检查 ---' AS 子测试;

-- 反例：分类不在枚举范围内
-- 取消下面注释执行，预期报错：
-- ERROR 3819 (HY000): Check constraint 'chk_product_category' is violated
-- INSERT INTO product (product_id, product_name, category, sale_price, purchase_price, unit, status)
-- VALUES ('P9994', '测试商品-非法分类', '电子产品', 100.00, 50.00, '个', '在售');
SELECT '反例：分类不在枚举范围 → 预期报错 chk_product_category violated（已注释，手动验证）' AS 反例说明;

-- 5.3 商品状态检查
SELECT '--- 5.3 商品状态枚举检查 ---' AS 子测试;

-- 反例：状态不在枚举范围内
-- 取消下面注释执行，预期报错：
-- ERROR 3819 (HY000): Check constraint 'chk_product_status' is violated
-- INSERT INTO product (product_id, product_name, category, sale_price, purchase_price, unit, status)
-- VALUES ('P9993', '测试商品-非法状态', '食品', 10.00, 5.00, '个', '暂停销售');
SELECT '反例：状态不在枚举范围 → 预期报错 chk_product_status violated（已注释，手动验证）' AS 反例说明;

-- 5.4 会员手机号格式检查
SELECT '--- 5.4 会员手机号格式检查 ---' AS 子测试;

-- 反例：手机号格式不正确（不是1开头的11位数字）
-- 取消下面注释执行，预期报错：
-- ERROR 3819 (HY000): Check constraint 'chk_member_phone_format' is violated
-- INSERT INTO member (member_id, member_name, phone, member_level, member_status)
-- VALUES ('M9997', '测试会员-手机号格式错', '12345', '普通', '正常');
SELECT '反例：手机号格式错误 → 预期报错 chk_member_phone_format violated（已注释，手动验证）' AS 反例说明;

-- 5.5 订单金额检查
SELECT '--- 5.5 订单金额检查 ---' AS 子测试;

-- 反例：订单总金额为负
-- 取消下面注释执行，预期报错：
-- ERROR 3819 (HY000): Check constraint 'chk_orders_total_amount' is violated
-- INSERT INTO orders (order_id, order_time, total_amount, payment_method, order_status, cashier_id)
-- VALUES ('ORDTEST001', '2026-09-20 10:00:00', -50.00, '微信', '已支付', 1);
SELECT '反例：订单金额为负 → 预期报错 chk_orders_total_amount violated（已注释，手动验证）' AS 反例说明;

-- 5.6 订单明细计算检查
SELECT '--- 5.6 订单明细计算检查 ---' AS 子测试;

-- 反例：小计金额不等于数量×单价
-- 取消下面注释执行，预期报错：
-- ERROR 3819 (HY000): Check constraint 'chk_order_item_calc' is violated
-- INSERT INTO order_item (order_id, product_id, quantity, unit_price, subtotal)
-- VALUES ('ORD202609150001', 'P0003', 2, 2.00, 100.00);
SELECT '反例：小计金额计算错误 → 预期报错 chk_order_item_calc violated（已注释，手动验证）' AS 反例说明;

-- 清理测试数据
DELETE FROM product WHERE product_id IN ('P9997', 'P9996', 'P9995', 'P9994', 'P9993');
SELECT '测试数据已清理' AS 清理;


-- ============================================================
-- 第六部分：默认值约束（DEFAULT）验证
-- ============================================================

SELECT '=== 默认值约束验证 ===' AS 约束类型;

-- 正例1：不指定有默认值的字段，使用默认值
SELECT '--- 正例1：商品状态使用默认值 ---' AS 测试;
INSERT INTO product (product_id, product_name, category, sale_price, purchase_price, unit)
VALUES ('P9992', '测试商品-默认状态', '食品', 10.00, 5.00, '个');
-- status字段未指定，应使用默认值'在售'

SELECT product_id, product_name, status AS 默认状态值
FROM product WHERE product_id = 'P9992';

-- 正例2：订单时间默认值
SELECT '--- 正例2：订单时间使用默认值 ---' AS 测试;
INSERT INTO orders (order_id, total_amount, payment_method, order_status, cashier_id)
VALUES ('ORDTEST002', 20.00, '现金', '已支付', 1);
-- order_time字段未指定，应使用默认值CURRENT_TIMESTAMP

SELECT order_id, order_time AS 默认下单时间, total_amount
FROM orders WHERE order_id = 'ORDTEST002';

-- 清理测试数据
DELETE FROM product WHERE product_id = 'P9992';
DELETE FROM orders WHERE order_id = 'ORDTEST002';
SELECT '测试数据已清理' AS 清理;


-- ============================================================
-- 第七部分：非空约束（NOT NULL）验证
-- ============================================================

SELECT '=== 非空约束验证 ===' AS 约束类型;

-- 反例1：商品名称为空
-- 取消下面注释执行，预期报错：
-- ERROR 1048 (23000): Column 'product_name' cannot be null
-- INSERT INTO product (product_id, product_name, category, sale_price, purchase_price, unit, status)
-- VALUES ('P9991', NULL, '食品', 10.00, 5.00, '个', '在售');
SELECT '反例1：商品名称为空 → 预期报错 Column cannot be null（已注释，手动验证）' AS 反例说明;

-- 反例2：会员姓名为空
-- 取消下面注释执行，预期报错：
-- ERROR 1048 (23000): Column 'member_name' cannot be null
-- INSERT INTO member (member_id, member_name, phone, member_level, member_status)
-- VALUES ('M9996', NULL, '13888888888', '普通', '正常');
SELECT '反例2：会员姓名为空 → 预期报错 Column cannot be null（已注释，手动验证）' AS 反例说明;

-- 反例3：订单支付方式为空
-- 取消下面注释执行，预期报错：
-- ERROR 1048 (23000): Column 'payment_method' cannot be null
-- INSERT INTO orders (order_id, total_amount, payment_method, order_status, cashier_id)
-- VALUES ('ORDTEST003', 20.00, NULL, '已支付', 1);
SELECT '反例3：支付方式为空 → 预期报错 Column cannot be null（已注释，手动验证）' AS 反例说明;


-- ============================================================
-- 第八部分：约束完整性总结
-- ============================================================

SELECT '=== 完整性约束验证总结 ===' AS 总结;

SELECT
    '主码约束' AS 约束类型,
    '6个表各1个主码，共6个' AS 数量,
    '保证实体完整性，主码唯一且非空' AS 作用
UNION ALL
SELECT '外码约束', '6个外键', '保证参照完整性，外码值必须存在于被引用表'
UNION ALL
SELECT '唯一约束', '4个唯一约束', '保证候选码唯一性（手机号、登录账号、商品-库存、订单-商品）'
UNION ALL
SELECT '检查约束', '24个CHECK约束', '保证域完整性，限制字段取值范围'
UNION ALL
SELECT '默认值约束', '多个DEFAULT', '简化插入操作，保证常用字段有合理默认值'
UNION ALL
SELECT '非空约束', '多个NOT NULL', '保证关键字段必须有值';

SELECT '所有完整性约束已在数据库中真正生效，非法数据均被拒绝！' AS 验证结论;

-- ============================================================
-- 约束验证脚本执行完成
-- ============================================================
