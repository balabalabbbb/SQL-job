from flask import Blueprint, render_template, request, jsonify, session
from services.inventory_service import get_all_inventory, adjust_inventory, get_low_stock
from services.auth_service import can_manage_inventory, require_login
from services.exceptions import AppError

inventory_bp = Blueprint('inventory', __name__, url_prefix='/inventory')


@inventory_bp.route('/', methods=['GET'])
def inventory_page():
    require_login(session)
    return render_template('inventory.html', user=session)


@inventory_bp.route('/api/list', methods=['GET'])
def api_list():
    require_login(session)
    inventory = get_all_inventory()
    return jsonify({'success': True, 'data': inventory})


@inventory_bp.route('/api/low', methods=['GET'])
def api_low_stock():
    require_login(session)
    low = get_low_stock()
    return jsonify({'success': True, 'data': low})


@inventory_bp.route('/api/update', methods=['POST'])
def api_update():
    can_manage_inventory(session)
    data = request.get_json()
    result = adjust_inventory(
        data.get('product_id', ''),
        int(data.get('quantity', 0)),
        int(data.get('min_threshold', 10))
    )
    return jsonify({'success': True, 'data': result})
