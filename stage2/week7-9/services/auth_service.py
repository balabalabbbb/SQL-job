import bcrypt
from dal.employee_dal import get_employee_by_account
from dal.member_dal import get_member_by_phone
from services.exceptions import AuthError, ValidationError, PermissionDeniedError


def login_employee(account, password):
    if not account or not password:
        raise ValidationError('账号和密码不能为空')
    employee = get_employee_by_account(account)
    if not employee:
        raise AuthError('账号不存在或已停用')
    stored_hash = employee['login_password']
    if stored_hash and stored_hash.startswith('$2'):
        if not bcrypt.checkpw(password.encode('utf-8'), stored_hash.encode('utf-8')):
            raise AuthError('密码错误')
    else:
        if stored_hash != password:
            raise AuthError('密码错误')
    role_map = {'店长': 'manager', '店员': 'cashier'}
    role = role_map.get(employee['position'], 'cashier')
    return {
        'user_id': employee['employee_id'],
        'user_name': employee['employee_name'],
        'user_role': role,
        'user_type': 'employee'
    }


def login_member(phone):
    if not phone:
        raise ValidationError('手机号不能为空')
    member = get_member_by_phone(phone)
    if not member:
        raise AuthError('会员不存在')
    return {
        'user_id': member['member_id'],
        'user_name': member['member_name'],
        'user_role': 'customer',
        'user_type': 'member'
    }


def require_login(session):
    if 'user_id' not in session:
        raise AuthError('请先登录')


def require_role(session, *roles):
    require_login(session)
    if session.get('user_role') not in roles:
        raise PermissionDeniedError('无权限执行此操作')


def can_manage_products(session):
    require_role(session, 'manager')


def can_manage_inventory(session):
    require_role(session, 'manager', 'cashier')


def can_create_order(session):
    require_role(session, 'manager', 'cashier', 'customer')
