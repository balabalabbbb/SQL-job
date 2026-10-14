from datetime import datetime
from dal.db import transaction_scope
from dal.product_dal import get_product
from dal.inventory_dal import get_inventory, deduct_stock
from dal.order_dal import create_order_with_conn, add_order_item_with_conn, get_next_order_id
from dal.member_dal import add_points
from services.exceptions import ValidationError, NotFoundError, BusinessRuleError, TransactionError


def create_order(member_id, cashier_id, items, payment_method='现金', remark=''):
    if not items or not isinstance(items, list):
        raise ValidationError('订单商品不能为空')

    total_amount = 0
    product_info = {}

    for item in items:
        product_id = item.get('product_id')
        quantity = item.get('quantity', 0)
        if not product_id or quantity <= 0:
            raise ValidationError('商品ID和数量必须有效')
        product = get_product(product_id)
        if not product:
            raise NotFoundError(f'商品 {product_id} 不存在')
        inventory = get_inventory(product_id)
        if not inventory or inventory['quantity'] < quantity:
            raise BusinessRuleError(f'商品 {product_id} 库存不足')
        unit_price = product['sale_price']
        subtotal = round(unit_price * quantity, 2)
        total_amount += subtotal
        product_info[product_id] = {
            'product': product,
            'quantity': quantity,
            'unit_price': unit_price,
            'subtotal': subtotal
        }

    total_amount = round(total_amount, 2)
    date_str = datetime.now().strftime('%Y%m%d')
    order_id = get_next_order_id(date_str)

    try:
        with transaction_scope() as conn:
            create_order_with_conn(conn, order_id, total_amount, payment_method, member_id, cashier_id, remark)
            for product_id, info in product_info.items():
                add_order_item_with_conn(conn, order_id, product_id, info['quantity'], info['unit_price'], info['subtotal'])
                deduct_stock(conn, product_id, info['quantity'])
            if member_id:
                points = int(total_amount)
                add_points(conn, member_id, points)
    except Exception as e:
        raise TransactionError(f'订单创建事务失败: {str(e)}')

    return {
        'order_id': order_id,
        'total_amount': total_amount,
        'items_count': len(items),
        'message': '订单创建成功'
    }
