from dal.db import execute_query, execute_update, execute_query_with_conn, execute_update_with_conn

SQL_LIST = """
SELECT i.inventory_id, i.product_id, p.product_name, i.quantity,
       i.min_threshold, i.last_updated
FROM inventory i
LEFT JOIN product p ON i.product_id = p.product_id
ORDER BY i.product_id
"""

SQL_GET_BY_PRODUCT = "SELECT * FROM inventory WHERE product_id = ?"

SQL_UPDATE_QTY = "UPDATE inventory SET quantity = quantity + ?, last_updated = GETDATE() WHERE product_id = ?"

SQL_DEDUCT = "UPDATE inventory SET quantity = quantity - ?, last_updated = GETDATE() WHERE product_id = ? AND quantity >= ?"

SQL_SET_QTY = "UPDATE inventory SET quantity = ?, min_threshold = ?, last_updated = GETDATE() WHERE product_id = ?"


def list_inventory():
    return execute_query(SQL_LIST)


def get_inventory(product_id):
    rows = execute_query(SQL_GET_BY_PRODUCT, (product_id,))
    return rows[0] if rows else None


def update_quantity(product_id, delta):
    return execute_update(SQL_UPDATE_QTY, (delta, product_id))


def deduct_stock(conn, product_id, quantity):
    return execute_update_with_conn(conn, SQL_DEDUCT, (quantity, product_id, quantity))


def set_inventory(product_id, quantity, min_threshold):
    return execute_update(SQL_SET_QTY, (quantity, min_threshold, product_id))
