# ============================================================
# exp5_regression.ps1
# 第13周 实验5：业务回归（单订单正常/重复完成/并发竞争）
# 复用第12周事务过程与触发器，验证并发控制不破坏业务正确性。
# ============================================================
. "$PSScriptRoot\conc_lib.ps1"
$init = "$PSScriptRoot\00_init.sql"

# 1) 单订单正常完成 + 重复完成报错
function Run-SingleOrder {
    Write-Output ("="*70)
    Write-Output "回归1：单订单正常完成 + 重复完成报错（52002）"
    Write-Output ("="*70)
    Reset-Baseline -InitPath $init
    Write-Output ("初始 P={0}" -f (Get-Qty 'P'))
    $S = Start-SqlSession -Name 'S1'

    Send-Sql -Rec $S -Sql "EXEC dbo.usp_complete_order_transaction @order_id='ORD_CONC_A';`nGO`n"
    Start-Sleep -Milliseconds 1000
    Write-Output "--- 首次执行（应成功，P 10 -> 4）---"
    (Get-SqlOut -Rec $S) -split "`n" | Where-Object { $_ -match '完成|成功|52002|Msg' } | Select-Object -First 5
    Write-Output ("当前 P = {0}" -f (Get-Qty 'P'))

    Clear-SqlOut -Rec $S
    Send-Sql -Rec $S -Sql "EXEC dbo.usp_complete_order_transaction @order_id='ORD_CONC_A';`nGO`n"
    Start-Sleep -Milliseconds 1000
    Write-Output "--- 重复执行（应报 52002 订单已完成）---"
    (Get-SqlOut -Rec $S) -split "`n" | Where-Object { $_ -match '52002|Msg|级别|状态' } | Select-Object -First 5

    Stop-SqlSession -Rec $S
    Write-Output ""
}

# 2) 两个会话并发竞争同一库存
function Run-ConcurrentOrders {
    Write-Output ("="*70)
    Write-Output "回归2：A、B 同时购买 P×6（库存仅10）-> 一个成功，一个报 52005 回滚"
    Write-Output ("="*70)
    Reset-Baseline -InitPath $init
    Write-Output ("初始 P={0}" -f (Get-Qty 'P'))
    $A = Start-SqlSession -Name 'A8'
    $B = Start-SqlSession -Name 'B8'

    # 两个会话几乎同时发起订单完成事务
    Send-Sql -Rec $A -Sql "EXEC dbo.usp_complete_order_transaction @order_id='ORD_CONC_A';`nGO`n"
    Start-Sleep -Milliseconds 200
    Send-Sql -Rec $B -Sql "EXEC dbo.usp_complete_order_transaction @order_id='ORD_CONC_B';`nGO`n"
    Start-Sleep -Milliseconds 3000

    Write-Output "--- A 会话结果 ---"
    (Get-SqlOut -Rec $A) -split "`n" | Where-Object { $_ -match '完成|成功|5200|Msg' } | Select-Object -First 5
    Write-Output "--- B 会话结果（库存不足应报 52005 并回滚）---"
    (Get-SqlOut -Rec $B) -split "`n" | Where-Object { $_ -match '52005|Msg|级别|状态|库存' } | Select-Object -First 5

    Stop-SqlSession -Rec $A; Stop-SqlSession -Rec $B

    # 最终状态核对
    Write-Output "--- 最终状态 ---"
    $checkSql = "SET NOCOUNT ON; SELECT order_id + '|' + order_status FROM dbo.orders WHERE order_id IN ('ORD_CONC_A','ORD_CONC_B') ORDER BY order_id; SELECT 'P_QTY|' + CAST(quantity AS varchar(10)) FROM dbo.inventory WHERE product_id='P';"
    Invoke-Monitor -Sql $checkSql
    Write-Output ""
}

Run-SingleOrder
Run-ConcurrentOrders
