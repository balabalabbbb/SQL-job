from dal.inventory_dal import list_inventory, get_inventory, set_inventory, update_quantity
from services.exceptions import ValidationError, NotFoundError


def get_all_inventory():
    return list_inventory()


def get_inventory_detail(product_id):
    inv = get_inventory(product_id)
    if not inv:
        raise NotFoundError('库存记录不存在')
    return inv


def adjust_inventory(product_id, quantity, min_threshold):
    if not get_inventory(product_id):
        raise NotFoundError('库存记录不存在')
    if quantity < 0:
        raise ValidationError('库存数量不能为负数')
    set_inventory(product_id, quantity, min_threshold)
    return {'message': '库存更新成功'}


def get_low_stock():
    all_inv = list_inventory()
    return [i for i in all_inv if i['quantity'] <= i['min_threshold']]
