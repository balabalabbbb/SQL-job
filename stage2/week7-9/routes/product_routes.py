from flask import Blueprint, render_template, request, jsonify, session
from services.product_service import get_all_products, get_product_detail, create_product, modify_product, remove_product
from services.auth_service import can_manage_products, require_login
from services.exceptions import AppError

product_bp = Blueprint('product', __name__, url_prefix='/products')


@product_bp.route('/', methods=['GET'])
def products_page():
    require_login(session)
    return render_template('products.html', user=session)


@product_bp.route('/api/list', methods=['GET'])
def api_list():
    require_login(session)
    products = get_all_products()
    return jsonify({'success': True, 'data': products})


@product_bp.route('/api/<product_id>', methods=['GET'])
def api_detail(product_id):
    require_login(session)
    product = get_product_detail(product_id)
    return jsonify({'success': True, 'data': product})


@product_bp.route('/api/add', methods=['POST'])
def api_add():
    can_manage_products(session)
    data = request.get_json()
    result = create_product(
        data.get('product_id', ''),
        data.get('product_name', ''),
        data.get('category_id', 1),
        float(data.get('sale_price', 0)),
        float(data.get('purchase_price', 0)),
        data.get('unit', '个')
    )
    return jsonify({'success': True, 'data': result})


@product_bp.route('/api/update', methods=['POST'])
def api_update():
    can_manage_products(session)
    data = request.get_json()
    result = modify_product(
        data.get('product_id', ''),
        data.get('product_name', ''),
        data.get('category_id', 1),
        float(data.get('sale_price', 0)),
        float(data.get('purchase_price', 0)),
        data.get('unit', '个')
    )
    return jsonify({'success': True, 'data': result})


@product_bp.route('/api/delete/<product_id>', methods=['POST'])
def api_delete(product_id):
    can_manage_products(session)
    result = remove_product(product_id)
    return jsonify({'success': True, 'data': result})
