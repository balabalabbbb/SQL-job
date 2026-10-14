from dal.db import execute_query, execute_update, execute_update_with_conn

SQL_GET_BY_PHONE = "SELECT * FROM member WHERE phone = ?"
SQL_GET_BY_ID = "SELECT * FROM member WHERE member_id = ?"
SQL_UPDATE_POINTS = "UPDATE member SET points_balance = points_balance + ? WHERE member_id = ?"


def get_member_by_phone(phone):
    rows = execute_query(SQL_GET_BY_PHONE, (phone,))
    return rows[0] if rows else None


def get_member(member_id):
    rows = execute_query(SQL_GET_BY_ID, (member_id,))
    return rows[0] if rows else None


def add_points(conn, member_id, points):
    return execute_update_with_conn(conn, SQL_UPDATE_POINTS, (points, member_id))
