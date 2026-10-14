# 小卖部管理系统 - Spring Boot 集成测试脚本
# 用法: .\integration_test.ps1
# 前提: 应用已启动在 http://localhost:8080

$base = "http://localhost:8080"
$pass = 0
$fail = 0
$results = @()

function Test-Case($name, $scriptBlock) {
    try {
        & $scriptBlock
        $script:pass++
        $script:results += [PSCustomObject]@{序号=$script:results.Count+1; 测试项=$name; 结果="PASS"; 说明=""}
        Write-Host "  $($script:results.Count). $name : PASS" -ForegroundColor Green
    } catch {
        $script:fail++
        $script:results += [PSCustomObject]@{序号=$script:results.Count+1; 测试项=$name; 结果="FAIL"; 说明=$_.Exception.Message}
        Write-Host "  $($script:results.Count). $name : FAIL - $($_.Exception.Message)" -ForegroundColor Red
    }
}

Write-Host "`n===== 小卖部管理系统集成测试 =====" -ForegroundColor Cyan
Write-Host "目标: $base`n"

# 1. 店长登录
Test-Case "店长登录" {
    $s = New-Object Microsoft.PowerShell.Commands.WebRequestSession
    $r = Invoke-WebRequest -Uri "$base/login" -Method POST -Body '{"login_type":"employee","account":"manager01","password":"Manager@123"}' -ContentType "application/json; charset=utf-8" -WebSession $s -UseBasicParsing -TimeoutSec 30
    if ($r.StatusCode -ne 200) { throw "HTTP $($r.StatusCode)" }
    $json = $r.Content | ConvertFrom-Json
    if (-not $json.success) { throw $json.message }
    $script:managerSession = $s
}

# 2. 商品列表查询
Test-Case "商品列表查询" {
    $r = Invoke-WebRequest -Uri "$base/products/api/list" -WebSession $script:managerSession -UseBasicParsing -TimeoutSec 30
    if ($r.StatusCode -ne 200) { throw "HTTP $($r.StatusCode)" }
}

# 3. 库存列表查询
Test-Case "库存列表查询" {
    $r = Invoke-WebRequest -Uri "$base/inventory/api/list" -WebSession $script:managerSession -UseBasicParsing -TimeoutSec 30
    if ($r.StatusCode -ne 200) { throw "HTTP $($r.StatusCode)" }
}

# 4. 订单列表查询
Test-Case "订单列表查询" {
    $r = Invoke-WebRequest -Uri "$base/orders/api/list" -WebSession $script:managerSession -UseBasicParsing -TimeoutSec 30
    if ($r.StatusCode -ne 200) { throw "HTTP $($r.StatusCode)" }
}

# 5. 商品新增
Test-Case "商品新增" {
    $body = '{"productId":"PT_TEST","productName":"集成测试商品","salePrice":9.99,"purchasePrice":5.0,"unit":"瓶","status":"在售","categoryId":1}'
    $r = Invoke-WebRequest -Uri "$base/products/api/add" -Method POST -Body $body -ContentType "application/json; charset=utf-8" -WebSession $script:managerSession -UseBasicParsing -TimeoutSec 30
    if ($r.StatusCode -ne 200) { throw "HTTP $($r.StatusCode)" }
}

# 6. 重复主键约束拒绝
Test-Case "重复主键约束拒绝" {
    $body = '{"productId":"PT_TEST","productName":"重复","salePrice":1,"purchasePrice":0.5,"unit":"个","status":"在售","categoryId":1}'
    try {
        $r = Invoke-WebRequest -Uri "$base/products/api/add" -Method POST -Body $body -ContentType "application/json; charset=utf-8" -WebSession $script:managerSession -UseBasicParsing -TimeoutSec 30
        throw "应返回400但返回$($r.StatusCode)"
    } catch [System.Net.WebException] {
        $code = [int]$_.Exception.Response.StatusCode
        if ($code -ne 400) { throw "期望400实际$code" }
    }
}

# 7. 商品修改
Test-Case "商品修改" {
    $body = '{"productId":"PT_TEST","productName":"测试商品-改","salePrice":19.99,"purchasePrice":8.0,"unit":"瓶","status":"在售","categoryId":1}'
    $r = Invoke-WebRequest -Uri "$base/products/api/update" -Method POST -Body $body -ContentType "application/json; charset=utf-8" -WebSession $script:managerSession -UseBasicParsing -TimeoutSec 30
    if ($r.StatusCode -ne 200) { throw "HTTP $($r.StatusCode)" }
}

# 8. 商品删除
Test-Case "商品删除" {
    $r = Invoke-WebRequest -Uri "$base/products/api/delete/PT_TEST" -Method POST -WebSession $script:managerSession -UseBasicParsing -TimeoutSec 30
    if ($r.StatusCode -ne 200) { throw "HTTP $($r.StatusCode)" }
}

# 9. 创建订单（事务）
Test-Case "创建订单（事务）" {
    $body = '{"items":[{"productId":"P0001","quantity":1}],"paymentMethod":"现金","memberId":"M0001"}'
    $r = Invoke-WebRequest -Uri "$base/orders/api/create" -Method POST -Body $body -ContentType "application/json; charset=utf-8" -WebSession $script:managerSession -UseBasicParsing -TimeoutSec 30
    if ($r.StatusCode -ne 200) { throw "HTTP $($r.StatusCode)" }
    $json = $r.Content | ConvertFrom-Json
    $script:testOrderId = $json.data.orderId
}

# 10. 非法外码拒绝
Test-Case "非法外码拒绝" {
    $body = '{"items":[{"productId":"INVALID_PROD","quantity":1}]}'
    try {
        $r = Invoke-WebRequest -Uri "$base/orders/api/create" -Method POST -Body $body -ContentType "application/json; charset=utf-8" -WebSession $script:managerSession -UseBasicParsing -TimeoutSec 30
        throw "应返回404但返回$($r.StatusCode)"
    } catch [System.Net.WebException] {
        $code = [int]$_.Exception.Response.StatusCode
        if ($code -ne 404) { throw "期望404实际$code" }
    }
}

# 11. 取消订单
Test-Case "取消订单" {
    if (-not $script:testOrderId) { throw "无测试订单" }
    $r = Invoke-WebRequest -Uri "$base/orders/api/cancel/$($script:testOrderId)" -Method POST -WebSession $script:managerSession -UseBasicParsing -TimeoutSec 30
    if ($r.StatusCode -ne 200) { throw "HTTP $($r.StatusCode)" }
}

# 12. 未登录拒绝
Test-Case "未登录拒绝" {
    $s0 = New-Object Microsoft.PowerShell.Commands.WebRequestSession
    try {
        $r = Invoke-WebRequest -Uri "$base/products/api/list" -WebSession $s0 -UseBasicParsing -TimeoutSec 30
        throw "应返回401但返回$($r.StatusCode)"
    } catch [System.Net.WebException] {
        $code = [int]$_.Exception.Response.StatusCode
        if ($code -ne 401) { throw "期望401实际$code" }
    }
}

# 13. 店员登录
Test-Case "店员登录" {
    $s = New-Object Microsoft.PowerShell.Commands.WebRequestSession
    $r = Invoke-WebRequest -Uri "$base/login" -Method POST -Body '{"login_type":"employee","account":"cashier01","password":"Manager@123"}' -ContentType "application/json; charset=utf-8" -WebSession $s -UseBasicParsing -TimeoutSec 30
    if ($r.StatusCode -ne 200) { throw "HTTP $($r.StatusCode)" }
    $script:cashierSession = $s
}

# 14. 店员越权拒绝（商品管理）
Test-Case "店员越权拒绝（商品管理）" {
    $body = '{"productId":"X001","productName":"x","salePrice":1,"purchasePrice":0.5,"unit":"个","status":"在售","categoryId":1}'
    try {
        $r = Invoke-WebRequest -Uri "$base/products/api/add" -Method POST -Body $body -ContentType "application/json; charset=utf-8" -WebSession $script:cashierSession -UseBasicParsing -TimeoutSec 30
        throw "应返回403但返回$($r.StatusCode)"
    } catch [System.Net.WebException] {
        $code = [int]$_.Exception.Response.StatusCode
        if ($code -ne 403) { throw "期望403实际$code" }
    }
}

# 15. 会员登录+越权拒绝
Test-Case "会员登录+越权拒绝" {
    $s = New-Object Microsoft.PowerShell.Commands.WebRequestSession
    $r = Invoke-WebRequest -Uri "$base/login" -Method POST -Body '{"login_type":"member","phone":"13800138001"}' -ContentType "application/json; charset=utf-8" -WebSession $s -UseBasicParsing -TimeoutSec 30
    if ($r.StatusCode -ne 200) { throw "登录失败 HTTP $($r.StatusCode)" }
    try {
        $body = '{"productId":"X002","productName":"x","salePrice":1,"purchasePrice":0.5,"unit":"个","status":"在售","categoryId":1}'
        $r2 = Invoke-WebRequest -Uri "$base/products/api/add" -Method POST -Body $body -ContentType "application/json; charset=utf-8" -WebSession $s -UseBasicParsing -TimeoutSec 30
        throw "应返回403但返回$($r2.StatusCode)"
    } catch [System.Net.WebException] {
        $code = [int]$_.Exception.Response.StatusCode
        if ($code -ne 403) { throw "期望403实际$code" }
    }
}

# 汇总
Write-Host "`n===== 测试结果汇总 =====" -ForegroundColor Cyan
Write-Host "通过: $pass / $($pass+$fail)" -ForegroundColor $(if($fail -eq 0){'Green'}else{'Yellow'})
if ($fail -gt 0) {
    Write-Host "失败: $fail" -ForegroundColor Red
    $results | Where-Object { $_.结果 -eq "FAIL" } | Format-Table -AutoSize
}
Write-Host "`n详细结果:" -ForegroundColor Cyan
$results | Format-Table -AutoSize

# 保存结果到CSV
$results | Export-Csv -Path "test_results.csv" -NoTypeInformation -Encoding UTF8
Write-Host "结果已保存到 test_results.csv" -ForegroundColor Gray

exit $(if($fail -eq 0){0}else{1})
