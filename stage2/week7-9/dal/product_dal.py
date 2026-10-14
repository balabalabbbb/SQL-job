from dal.db import execute_query, execute_update, execute_query_with_conn, execute_update_with_conn

SQL_LIST = """
SELECT p.product_id, p.product_name, p.category_id, c.category_name,
       p.sale_price, p.purchase_price, p.unit, p.status
FROM product p
LEFT JOIN category c ON p.category_id = c.category_id
ORDER BY p.product_id
"""

SQL_GET_BY_ID = """
SELECT p.product_id, p.product_name, p.category_id, c.category_name,
       p.sale_price, p.purchase_price, p.unit, p.status
FROM product p
LEFT JOIN category c ON p.category_id = c.category_id
WHERE p.product_id = ?
"""

SQL_INSERT = """
INSERT INTO product (product_id, product_name, category_id, sale_price, purchase_price, unit, status)
VALUES (?, ?, ?, ?, ?, ?, '在售')
"""

SQL_UPDATE = """
UPDATE product SET product_name=?, category_id=?, sale_price=?, purchase_price=?, unit=? WHERE product_id=?
"""

SQL_DELETE = "DELETE FROM product WHERE product_id=?"


def list_products():
    return execute_query(SQL_LIST)


def get_product(product_id):
    rows = execute_query(SQL_GET_BY_ID, (product_id,))
    return rows[0] if rows else None


def add_product(product_id, product_name, category_id, sale_price, purchase_price, unit):
    return execute_update(SQL_INSERT, (product_id, product_name, category_id, sale_price, purchase_price, unit))


def update_product(product_id, product_name, category_id, sale_price, purchase_price, unit):
    return execute_update(SQL_UPDATE, (product_name, category_id, sale_price, purchase_price, unit, product_id))


def delete_product(product_id):
    return execute_update(SQL_DELETE, (product_id,))
