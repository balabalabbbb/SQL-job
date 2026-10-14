from dal.db import execute_query, execute_update, execute_query_with_conn, execute_update_with_conn

SQL_LIST = """
SELECT o.order_id, o.order_time, o.total_amount, o.payment_method,
       o.order_status, o.member_id, m.member_name,
       o.cashier_id, e.employee_name, o.remark
FROM orders o
LEFT JOIN member m ON o.member_id = m.member_id
LEFT JOIN employee e ON o.cashier_id = e.employee_id
ORDER BY o.order_time DESC
"""

SQL_GET_BY_ID = """
SELECT o.order_id, o.order_time, o.total_amount, o.payment_method,
       o.order_status, o.member_id, m.member_name,
       o.cashier_id, e.employee_name, o.remark
FROM orders o
LEFT JOIN member m ON o.member_id = m.member_id
LEFT JOIN employee e ON o.cashier_id = e.employee_id
WHERE o.order_id = ?
"""

SQL_GET_ITEMS = """
SELECT oi.order_id, oi.product_id, p.product_name, oi.quantity, oi.unit_price, oi.subtotal
FROM order_item oi
LEFT JOIN product p ON oi.product_id = p.product_id
WHERE oi.order_id = ?
"""

SQL_INSERT_ORDER = """
INSERT INTO orders (order_id, order_time, total_amount, payment_method,
                    order_status, member_id, cashier_id, remark)
VALUES (?, GETDATE(), ?, ?, '已支付', ?, ?, ?)
"""

SQL_INSERT_ITEM = """
INSERT INTO order_item (order_id, product_id, quantity, unit_price, subtotal)
VALUES (?, ?, ?, ?, ?)
"""

SQL_GET_MAX_ID = "SELECT ISNULL(MAX(CAST(SUBSTRING(order_id, 12, 4) AS INT)), 0) AS max_id FROM orders WHERE order_id LIKE ?"


def list_orders():
    return execute_query(SQL_LIST)


def get_order(order_id):
    rows = execute_query(SQL_GET_BY_ID, (order_id,))
    return rows[0] if rows else None


def get_order_items(order_id):
    return execute_query(SQL_GET_ITEMS, (order_id,))


def create_order_with_conn(conn, order_id, total_amount, payment_method, member_id, cashier_id, remark):
    return execute_update_with_conn(conn, SQL_INSERT_ORDER, (order_id, total_amount, payment_method, member_id, cashier_id, remark))


def add_order_item_with_conn(conn, order_id, product_id, quantity, unit_price, subtotal):
    return execute_update_with_conn(conn, SQL_INSERT_ITEM, (order_id, product_id, quantity, unit_price, subtotal))


def get_next_order_id(date_str):
    prefix = f"ORD{date_str}%"
    rows = execute_query(SQL_GET_MAX_ID, (prefix,))
    max_id = rows[0]['max_id'] if rows else 0
    return f"ORD{date_str}{max_id + 1:04d}"
