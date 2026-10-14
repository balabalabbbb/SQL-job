from dal.product_dal import list_products, get_product, add_product, update_product, delete_product
from services.exceptions import ValidationError, NotFoundError


def get_all_products():
    return list_products()


def get_product_detail(product_id):
    product = get_product(product_id)
    if not product:
        raise NotFoundError('商品不存在')
    return product


def create_product(product_id, product_name, category_id, sale_price, purchase_price, unit):
    if not product_id or not product_name:
        raise ValidationError('商品ID和名称不能为空')
    if sale_price < 0 or purchase_price < 0:
        raise ValidationError('价格不能为负数')
    if get_product(product_id):
        raise ValidationError('商品ID已存在')
    add_product(product_id, product_name, category_id, sale_price, purchase_price, unit)
    return {'message': '商品创建成功'}


def modify_product(product_id, product_name, category_id, sale_price, purchase_price, unit):
    if not get_product(product_id):
        raise NotFoundError('商品不存在')
    update_product(product_id, product_name, category_id, sale_price, purchase_price, unit)
    return {'message': '商品更新成功'}


def remove_product(product_id):
    if not get_product(product_id):
        raise NotFoundError('商品不存在')
    delete_product(product_id)
    return {'message': '商品删除成功'}
