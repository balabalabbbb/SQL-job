import logging
from flask import Blueprint, render_template, request, jsonify, session
from dal.order_dal import list_orders, get_order, get_order_items
from services.order_service import create_order
from services.auth_service import can_create_order, require_login
from services.exceptions import AppError

order_bp = Blueprint('order', __name__, url_prefix='/orders')


@order_bp.route('/', methods=['GET'])
def orders_page():
    require_login(session)
    return render_template('orders.html', user=session)


@order_bp.route('/create', methods=['GET'])
def create_page():
    require_login(session)
    return render_template('order_create.html', user=session)


@order_bp.route('/api/list', methods=['GET'])
def api_list():
    require_login(session)
    orders = list_orders()
    return jsonify({'success': True, 'data': orders})


@order_bp.route('/api/<order_id>', methods=['GET'])
def api_detail(order_id):
    require_login(session)
    order = get_order(order_id)
    items = get_order_items(order_id)
    return jsonify({'success': True, 'data': {'order': order, 'items': items}})


@order_bp.route('/api/create', methods=['POST'])
def api_create():
    can_create_order(session)
    data = request.get_json()
    items = data.get('items', [])
    payment_method = data.get('payment_method', '现金')
    remark = data.get('remark', '')
    member_id = data.get('member_id') or 'M0001'
    cashier_id = None
    if session.get('user_type') == 'employee':
        cashier_id = session['user_id']
    try:
        result = create_order(member_id, cashier_id, items, payment_method, remark)
        return jsonify({'success': True, 'data': result})
    except AppError as e:
        logging.getLogger(__name__).error(f"订单创建失败: {e.error_code} - {e.detail}", exc_info=True)
        return jsonify({'success': False, 'message': e.user_message, 'detail': str(e.detail)}), e.http_status
