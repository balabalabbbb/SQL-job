import os
import logging
import traceback
from datetime import datetime
from flask import Flask, render_template, request, jsonify, session, redirect, url_for

from config import SECRET_KEY, LOG_DIR
from routes.auth_routes import auth_bp
from routes.product_routes import product_bp
from routes.inventory_routes import inventory_bp
from routes.order_routes import order_bp
from services.exceptions import AppError

app = Flask(__name__)
app.secret_key = SECRET_KEY

app.register_blueprint(auth_bp)
app.register_blueprint(product_bp)
app.register_blueprint(inventory_bp)
app.register_blueprint(order_bp)

logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s [%(levelname)s] %(message)s',
    handlers=[
        logging.FileHandler(os.path.join(LOG_DIR, 'app.log'), encoding='utf-8'),
        logging.StreamHandler()
    ]
)
logger = logging.getLogger(__name__)

# 操作名称映射：根据路径和方法推断业务操作名称
OPERATION_MAP = {
    ('POST', '/login'): '用户登录',
    ('POST', '/logout'): '用户登出',
    ('GET', '/products/api/list'): '查询商品列表',
    ('GET', '/products/api/'): '查询商品详情',
    ('POST', '/products/api/add'): '新增商品',
    ('POST', '/products/api/update'): '修改商品',
    ('POST', '/products/api/delete/'): '删除商品',
    ('GET', '/inventory/api/list'): '查询库存列表',
    ('GET', '/inventory/api/low'): '查询低库存预警',
    ('POST', '/inventory/api/update'): '调整库存',
    ('GET', '/orders/api/list'): '查询订单列表',
    ('GET', '/orders/api/'): '查询订单明细',
    ('POST', '/orders/api/create'): '创建订单',
}


def get_operation_name():
    """根据请求路径和方法推断业务操作名称"""
    key = (request.method, request.path)
    if key in OPERATION_MAP:
        return OPERATION_MAP[key]
    # 模糊匹配
    for (method, path_prefix), name in OPERATION_MAP.items():
        if method == request.method and request.path.startswith(path_prefix):
            return name
    return f"{request.method} {request.path}"


@app.before_request
def log_request():
    request.id = datetime.now().strftime('%Y%m%d%H%M%S%f')[:18]
    user = session.get('user_name', '未登录')
    role = session.get('user_role', '匿名')
    operation = get_operation_name()
    logger.info(f"[{request.id}] 操作={operation} 用户={user} 角色={role} 路径={request.method} {request.path}")


@app.after_request
def log_response(response):
    """记录请求处理结果"""
    if hasattr(request, 'id'):
        operation = get_operation_name()
        result = '成功' if response.status_code < 400 else '失败'
        logger.info(f"[{request.id}] 操作={operation} 处理结果={result} HTTP={response.status_code}")
    return response


@app.errorhandler(AppError)
def handle_app_error(error):
    request_id = getattr(request, 'id', 'unknown')
    operation = get_operation_name()
    logger.error(f"[{request_id}] 操作={operation} 错误码={error.error_code} HTTP={error.http_status} 详情={error.detail} 处理结果=失败")
    if request.path.startswith('/api/') or request.is_json:
        return jsonify({'success': False, 'message': error.user_message, 'error_code': error.error_code}), error.http_status
    return render_template('error.html', message=error.user_message), error.http_status


@app.errorhandler(Exception)
def handle_unexpected_error(error):
    request_id = getattr(request, 'id', 'unknown')
    operation = get_operation_name()
    logger.error(f"[{request_id}] 操作={operation} 未预期异常: {str(error)}", exc_info=True)
    logger.error(f"[{request_id}] 堆栈: {traceback.format_exc()}")
    if request.path.startswith('/api/') or request.is_json:
        return jsonify({'success': False, 'message': '系统暂时无法完成操作，请稍后重试', 'error_code': 'SYSTEM_ERROR'}), 500
    return render_template('error.html', message='系统暂时无法完成操作，请稍后重试'), 500


@app.route('/')
def index():
    if 'user_id' not in session:
        return redirect(url_for('auth.login_page'))
    return render_template('index.html', user=session)


if __name__ == '__main__':
    app.run(debug=False, host='127.0.0.1', port=5000)
