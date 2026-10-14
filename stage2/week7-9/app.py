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


@app.before_request
def log_request():
    request.id = datetime.now().strftime('%Y%m%d%H%M%S%f')[:18]
    user = session.get('user_name', '未登录')
    role = session.get('user_role', '匿名')
    logger.info(f"[{request.id}] {request.method} {request.path} 用户={user} 角色={role}")


@app.errorhandler(AppError)
def handle_app_error(error):
    request_id = getattr(request, 'id', 'unknown')
    logger.error(f"[{request_id}] 错误码={error.error_code} HTTP={error.http_status} 详情={error.detail}")
    if request.path.startswith('/api/') or request.is_json:
        return jsonify({'success': False, 'message': error.user_message, 'error_code': error.error_code}), error.http_status
    return render_template('error.html', message=error.user_message), error.http_status


@app.errorhandler(Exception)
def handle_unexpected_error(error):
    request_id = getattr(request, 'id', 'unknown')
    logger.error(f"[{request_id}] 未预期异常: {str(error)}", exc_info=True)
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
    app.run(debug=True, host='127.0.0.1', port=5000)
