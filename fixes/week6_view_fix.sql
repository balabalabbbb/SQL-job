USE retail_store;
GO
GO
ALTER VIEW dbo.v_product_sales AS
SELECT
    p.product_id        AS product_id,
    p.product_name      AS product_name,
    c.category_name     AS category,
    p.sale_price        AS sale_price,
    p.purchase_price    AS purchase_price,
    p.status            AS product_status,
    COALESCE(sales.order_count, 0)   AS order_count,
    COALESCE(sales.total_quantity, 0) AS total_quantity,
    COALESCE(sales.total_amount, 0)   AS total_amount,
    COALESCE(sales.total_quantity, 0) * (p.sale_price - p.purchase_price) AS gross_profit
FROM dbo.product p
JOIN dbo.category c ON p.category_id = c.category_id
LEFT JOIN (
    SELECT product_id, COUNT(DISTINCT order_id) AS order_count,
           SUM(quantity) AS total_quantity, SUM(subtotal) AS total_amount
    FROM dbo.order_item GROUP BY product_id
) sales ON p.product_id = sales.product_id;
GO
GO
ALTER VIEW dbo.v_category_sales AS
SELECT
    c.category_name              AS category,
    COUNT(DISTINCT p.product_id) AS product_count,
    COUNT(DISTINCT oi.order_id) AS order_count,
    COALESCE(SUM(oi.quantity), 0) AS total_quantity,
    COALESCE(SUM(oi.subtotal), 0) AS total_sales,
    COALESCE(AVG(oi.unit_price), 0) AS avg_unit_price,
    ROUND(COALESCE(SUM(oi.subtotal), 0) / NULLIF((SELECT SUM(subtotal) FROM dbo.order_item), 0) * 100, 2) AS sales_percentage
FROM dbo.product p
JOIN dbo.category c ON p.category_id = c.category_id
LEFT JOIN dbo.order_item oi ON p.product_id = oi.product_id
GROUP BY c.category_name;
GO
GO
ALTER VIEW dbo.v_order_detail AS
SELECT
    o.order_id          AS order_id,
    o.order_time        AS order_time,
    o.total_amount      AS order_total,
    o.payment_method    AS payment_method,
    o.order_status      AS order_status,
    o.remark            AS order_remark,
    m.member_id         AS member_id,
    m.member_name       AS member_name,
    m.member_level      AS member_level,
    e.employee_id       AS cashier_id,
    e.employee_name     AS cashier_name,
    oi.item_id          AS item_id,
    p.product_id        AS product_id,
    p.product_name      AS product_name,
    c.category_name     AS product_category,
    oi.quantity         AS quantity,
    oi.unit_price       AS unit_price,
    oi.subtotal         AS subtotal
FROM dbo.orders o
INNER JOIN dbo.order_item oi ON o.order_id = oi.order_id
INNER JOIN dbo.product p ON oi.product_id = p.product_id
INNER JOIN dbo.category c ON p.category_id = c.category_id
LEFT JOIN dbo.member m ON o.member_id = m.member_id
INNER JOIN dbo.employee e ON o.cashier_id = e.employee_id;
GO
GO
ALTER VIEW dbo.v_inventory_status AS
SELECT
    p.product_id            AS product_id,
    p.product_name          AS product_name,
    c.category_name         AS category,
    p.sale_price            AS sale_price,
    i.inventory_id          AS inventory_id,
    i.quantity              AS quantity,
    i.min_threshold         AS min_threshold,
    i.shelf_location        AS shelf_location,
    i.last_updated          AS last_updated,
    e.employee_name         AS last_updated_by,
    CASE WHEN i.quantity = 0 THEN '缺货' WHEN i.quantity < i.min_threshold THEN '需补货' ELSE '正常' END AS inventory_status,
    CASE WHEN i.quantity < i.min_threshold THEN i.min_threshold - i.quantity ELSE 0 END AS shortage_qty,
    i.quantity * p.purchase_price AS inventory_cost_value,
    i.quantity * p.sale_price     AS inventory_retail_value
FROM dbo.product p
INNER JOIN dbo.inventory i ON p.product_id = i.product_id
INNER JOIN dbo.category c ON p.category_id = c.category_id
LEFT JOIN dbo.employee e ON i.last_updated_by = e.employee_id;
GO
