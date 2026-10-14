import urllib.request, json, http.cookiejar

def api(opener, url, data=None):
    if data:
        req = urllib.request.Request(url, data=json.dumps(data).encode(), headers={'Content-Type':'application/json'})
    else:
        req = urllib.request.Request(url)
    try:
        r = opener.open(req)
        return r.status, json.loads(r.read().decode())
    except urllib.error.HTTPError as e:
        return e.code, json.loads(e.read().decode())

cj = http.cookiejar.CookieJar()
opener = urllib.request.build_opener(urllib.request.HTTPCookieProcessor(cj))

results = []

# 1. 登录
s, r = api(opener, 'http://127.0.0.1:5000/login', {'login_type':'employee','account':'manager01','password':'Manager@123'})
results.append(('员工登录', s==200, s))

# 2. 商品列表
s, r = api(opener, 'http://127.0.0.1:5000/products/api/list')
results.append(('商品列表', s==200 and len(r.get('data',[]))>0, s))

# 3. 库存列表
s, r = api(opener, 'http://127.0.0.1:5000/inventory/api/list')
results.append(('库存列表', s==200 and len(r.get('data',[]))>0, s))

# 4. 订单列表
s, r = api(opener, 'http://127.0.0.1:5000/orders/api/list')
results.append(('订单列表', s==200, s))

# 5. 创建订单
s, r = api(opener, 'http://127.0.0.1:5000/orders/api/create', {'items':[{'product_id':'P0007','quantity':1}],'payment_method':'微信'})
results.append(('创建订单', s==200, s))

# 6. 库存不足
s, r = api(opener, 'http://127.0.0.1:5000/orders/api/create', {'items':[{'product_id':'P0001','quantity':99999}]})
results.append(('库存不足拒绝', s!=200, s))

# 7. 非法商品
s, r = api(opener, 'http://127.0.0.1:5000/orders/api/create', {'items':[{'product_id':'P9999','quantity':1}]})
results.append(('非法商品拒绝', s!=200, s))

# 8. 未登录
cj2 = http.cookiejar.CookieJar()
opener2 = urllib.request.build_opener(urllib.request.HTTPCookieProcessor(cj2))
s, r = api(opener2, 'http://127.0.0.1:5000/products/api/add', {'product_id':'PT','product_name':'t','category_id':1,'sale_price':1,'cost_price':0.5,'unit':'个'})
results.append(('未登录拒绝', s!=200, s))

# 9. 会员登录
cj3 = http.cookiejar.CookieJar()
opener3 = urllib.request.build_opener(urllib.request.HTTPCookieProcessor(cj3))
s, r = api(opener3, 'http://127.0.0.1:5000/login', {'login_type':'member','phone':'13800138001'})
results.append(('会员登录', s==200, s))

# 10. 顾客越权
s, r = api(opener3, 'http://127.0.0.1:5000/products/api/add', {'product_id':'PT2','product_name':'t2','category_id':1,'sale_price':1,'cost_price':0.5,'unit':'个'})
results.append(('顾客越权拒绝', s!=200, s))

print("="*50)
print("集成测试结果")
print("="*50)
passed = 0
for name, ok, code in results:
    status = "PASS" if ok else "FAIL"
    if ok: passed += 1
    print(f"  {name}: {status} (HTTP {code})")
print(f"\n总计: {passed}/{len(results)} 通过")
