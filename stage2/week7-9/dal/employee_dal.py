from dal.db import execute_query

SQL_GET_BY_ACCOUNT = "SELECT * FROM employee WHERE login_account = ? AND employee_status = '在职'"


def get_employee_by_account(account):
    rows = execute_query(SQL_GET_BY_ACCOUNT, (account,))
    return rows[0] if rows else None
