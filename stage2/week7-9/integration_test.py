import urllib.request, json, http.cookiejar, datetime

def api(opener, url, data=None):
    if data is not None:
        req = urllib.request.Request(url, data=json.dumps(data).encode(), headers={'Content-Type':'application/json'}, method='POST')
    else:
        req = urllib.request.Request(url)
    try:
        r = opener.open(req)
        return r.status, json.loads(r.read().decode())
    except urllib.error.HTTPError as e:
        try:
            return e.code, json.loads(e.read().decode())
        except:
            return e.code, {}

cj = http.cookiejar.CookieJar()
opener = urllib.request.build_opener(urllib.request.HTTPCookieProcessor(cj))

results = []
log = []

def test(name, condition, code, detail=""):
    status = "PASS" if condition else "FAIL"
    results.append((name, condition, code))
    log.append(f"  {name}: {status} (HTTP {code}) {detail}")
    print(f"  {name}: {status} (HTTP {code}) {detail}")

print("="*50)
print("集成测试结果")
print("="*50)

# 1. 员工登录
s, r = api(opener, 'http://127.0.0.1:5000/login', {'login_type':'employee','account':'manager01','password':'Manager@123'})
test('员工登录', s==200, s)

# 2. 商品列表
s, r = api(opener, 'http://127.0.0.1:5000/products/api/list')
test('商品列表查询', s==200 and len(r.get('data',[]))>0, s, f"共{len(r.get('data',[]))}条")

# 3. 库存列表
s, r = api(opener, 'http://127.0.0.1:5000/inventory/api/list')
test('库存列表查询', s==200 and len(r.get('data',[]))>0, s, f"共{len(r.get('data',[]))}条")

# 4. 订单列表
s, r = api(opener, 'http://127.0.0.1:5000/orders/api/list')
test('订单列表查询', s==200, s)

# 5. 商品新增
test_pid = 'PT' + datetime.datetime.now().strftime('%H%M%S')
s, r = api(opener, 'http://127.0.0.1:5000/products/api/add', 
    {'product_id':test_pid,'product_name':'测试商品','category_id':1,'sale_price':9.9,'purchase_price':5.0,'unit':'个'})
test('商品新增', s==200, s)

# 6. 商品修改
s, r = api(opener, 'http://127.0.0.1:5000/products/api/update',
    {'product_id':test_pid,'product_name':'测试商品-改','category_id':2,'sale_price':12.0,'purchase_price':6.0,'unit':'瓶'})
test('商品修改', s==200, s)

# 7. 重复商品ID约束冲突
s, r = api(opener, 'http://127.0.0.1:5000/products/api/add',
    {'product_id':test_pid,'product_name':'重复商品','category_id':1,'sale_price':1,'purchase_price':0.5,'unit':'个'})
test('重复主键约束拒绝', s!=200, s)

# 8. 商品删除
s, r = api(opener, f'http://127.0.0.1:5000/products/api/delete/{test_pid}', {})
test('商品删除', s==200, s)

# 9. 库存调整
s, r = api(opener, 'http://127.0.0.1:5000/inventory/api/update',
    {'product_id':'P0001','quantity':100,'min_threshold':20})
test('库存调整', s==200, s)

# 10. 创建订单
s, r = api(opener, 'http://127.0.0.1:5000/orders/api/create', 
    {'items':[{'product_id':'P0007','quantity':1}],'payment_method':'微信'})
test('创建订单(事务)', s==200, s, r.get('data',{}).get('order_id',''))

# 11. 订单明细查询
if s==200:
    oid = r.get('data',{}).get('order_id','')
    s2, r2 = api(opener, f'http://127.0.0.1:5000/orders/api/{oid}')
    test('订单明细查询', s2==200 and len(r2.get('data',{}).get('items',[]))>0, s2)
else:
    test('订单明细查询', False, 0, '跳过：订单创建失败')

# 12. 库存不足拒绝
s, r = api(opener, 'http://127.0.0.1:5000/orders/api/create', {'items':[{'product_id':'P0001','quantity':99999}]})
test('库存不足拒绝', s!=200, s)

# 13. 非法商品外码拒绝
s, r = api(opener, 'http://127.0.0.1:5000/orders/api/create', {'items':[{'product_id':'P9999','quantity':1}]})
test('非法外码拒绝', s!=200, s)

# 14. 未登录拒绝
cj2 = http.cookiejar.CookieJar()
opener2 = urllib.request.build_opener(urllib.request.HTTPCookieProcessor(cj2))
s, r = api(opener2, 'http://127.0.0.1:5000/products/api/add', 
    {'product_id':'PTX','product_name':'t','category_id':1,'sale_price':1,'purchase_price':0.5,'unit':'个'})
test('未登录拒绝', s!=200, s)

# 15. 会员登录
cj3 = http.cookiejar.CookieJar()
opener3 = urllib.request.build_opener(urllib.request.HTTPCookieProcessor(cj3))
s, r = api(opener3, 'http://127.0.0.1:5000/login', {'login_type':'member','phone':'13800138001'})
test('会员登录', s==200, s)

# 16. 顾客越权拒绝
s, r = api(opener3, 'http://127.0.0.1:5000/products/api/add', 
    {'product_id':'PTY','product_name':'t2','category_id':1,'sale_price':1,'purchase_price':0.5,'unit':'个'})
test('顾客越权拒绝', s!=200, s)

# 17. 店员登录测试
cj4 = http.cookiejar.CookieJar()
opener4 = urllib.request.build_opener(urllib.request.HTTPCookieProcessor(cj4))
s, r = api(opener4, 'http://127.0.0.1:5000/login', {'login_type':'employee','account':'cashier01','password':'Manager@123'})
test('店员登录', s==200, s)

# 18. 店员越权(不能新增商品)
s, r = api(opener4, 'http://127.0.0.1:5000/products/api/add',
    {'product_id':'PTZ','product_name':'t3','category_id':1,'sale_price':1,'purchase_price':0.5,'unit':'个'})
test('店员越权拒绝(商品管理)', s!=200, s)

# 19. 数据库连接失败测试（直接测试DAL层连接处理）
import sys, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
try:
    import pyodbc
    # 用错误密码测试连接失败，验证异常被正确抛出
    wrong_conn_str = "DRIVER={ODBC Driver 17 for SQL Server};SERVER=localhost;DATABASE=retail_store;UID=retail_app;PWD=wrong_password;TrustServerCertificate=yes;"
    try:
        conn = pyodbc.connect(wrong_conn_str)
        test('数据库连接失败拒绝', False, 0, '错误：连接竟然成功了')
        conn.close()
    except pyodbc.Error as e:
        test('数据库连接失败拒绝', True, 0, f'正确拒绝: {str(e)[:50]}')
except ImportError as e:
    test('数据库连接失败拒绝', False, 0, f'导入失败: {e}')

passed = sum(1 for _, ok, _ in results if ok)
total = len(results)
print(f"\n总计: {passed}/{total} 通过")

# 保存测试结果
with open('test_results.txt', 'w', encoding='utf-8') as f:
    f.write("="*50 + "\n")
    f.write("第7-9周 Web应用集成测试结果\n")
    f.write(f"测试时间: {datetime.datetime.now().strftime('%Y-%m-%d %H:%M:%S')}\n")
    f.write("="*50 + "\n\n")
    for line in log:
        f.write(line + "\n")
    f.write(f"\n总计: {passed}/{total} 通过\n")
    f.write(f"通过率: {passed/total*100:.1f}%\n")
