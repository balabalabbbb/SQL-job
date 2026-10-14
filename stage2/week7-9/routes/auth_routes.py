from flask import Blueprint, render_template, request, jsonify, session, redirect, url_for
from services.auth_service import login_employee, login_member
from services.exceptions import AppError

auth_bp = Blueprint('auth', __name__)


@auth_bp.route('/login', methods=['GET'])
def login_page():
    return render_template('login.html')


@auth_bp.route('/login', methods=['POST'])
def login():
    data = request.get_json() if request.is_json else request.form
    login_type = data.get('login_type', 'employee')
    try:
        if login_type == 'employee':
            account = data.get('account', '')
            password = data.get('password', '')
            user = login_employee(account, password)
        else:
            phone = data.get('phone', '')
            user = login_member(phone)
        session['user_id'] = user['user_id']
        session['user_name'] = user['user_name']
        session['user_role'] = user['user_role']
        session['user_type'] = user['user_type']
        return jsonify({'success': True, 'message': '登录成功', 'redirect': url_for('index')})
    except AppError as e:
        return jsonify({'success': False, 'message': e.user_message, 'error_code': e.error_code}), e.http_status


@auth_bp.route('/logout', methods=['GET', 'POST'])
def logout():
    session.clear()
    return redirect(url_for('auth.login_page'))
