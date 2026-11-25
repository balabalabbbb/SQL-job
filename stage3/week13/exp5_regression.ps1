# ============================================================
# exp5_regression.ps1
# 第13周 业务回归：事务正常/重复调用校验 + 双会话竞争购买 P×6
# ============================================================
. "$PSScriptRoot\conc_lib.ps1"
$init = "$PSScriptRoot\00_init.sql"

function Run-SingleCheck {
    Write-Output ("="*70)
    Write-Output "回归1：单订单正常完成，重复完成应被拒绝（52002）"
    Write-Output ("="*70)
    Reset-Baseline -InitPath $init
    Write-Output ("初始 P = {0}" -f (Get-Qty 'P'))

    Write-Output "--- 第一次完成 ORD_CONC_A（应成功，P 10->4）---"
    Invoke-Monitor -Sql "EXEC dbo.usp_complete_order_transaction 'ORD_CONC_A';" 2>&1
    Write-Output ("完成后 P = {0}" -f (Get-Qty 'P'))
    Write-Output "--- 订单状态 ---"
    Invoke-Monitor -Sql "SET NOCOUNT ON; SELECT order_id, order_status FROM dbo.orders WHERE order_id='ORD_CONC_A';" 2>&1

    Write-Output "--- 重复完成同一订单（应报 52002）---"
    Invoke-Monitor -Sql "EXEC dbo.usp_complete_order_transaction 'ORD_CONC_A';" 2>&1
    Write-Output ""
}

function Run-Competition {
    Write-Output ("="*70)
    Write-Output "回归2：P=10，A、B 两个会话同时完成购买 P×6 的不同订单 —— 仅一单成功"
    Write-Output ("="*70)
    Reset-Baseline -InitPath $init
    Write-Output ("初始 P = {0}" -f (Get-Qty 'P'))
    $A = Start-SqlSession -Name 'A8'
    $B = Start-SqlSession -Name 'B8'

    Send-Sql -Rec $A -Sql "EXEC dbo.usp_complete_order_transaction 'ORD_CONC_A';`nGO`n"
    Send-Sql -Rec $B -Sql "EXEC dbo.usp_complete_order_transaction 'ORD_CONC_B';`nGO`n"
    [void](Wait-Qty -ProductId 'P' -Expected 4 -TimeoutMs 20000)
    [void](Wait-TranCount -Expected 0 -TimeoutMs 15000)
    [void](Wait-Until -TimeoutMs 10000 -Label '会话输出已写入' -Condition {
        (Get-SqlOut -Rec $A).Length -gt 0 -and (Get-SqlOut -Rec $B).Length -gt 0
    })

    Write-Output "--- A 会话输出 ---"
    (Get-SqlOut -Rec $A) -split "`n" | Where-Object { $_ -match '52005|52002|已完成|不足|提交' }
    Write-Output "--- B 会话输出 ---"
    (Get-SqlOut -Rec $B) -split "`n" | Where-Object { $_ -match '52005|52002|已完成|不足|提交' }

    Write-Output ("最终 P = {0}（预期 4）" -f (Get-Qty 'P'))
    Write-Output "--- 两个订单最终状态（应一个已完成、一个待支付）---"
    Invoke-Monitor -Sql "SET NOCOUNT ON; SELECT order_id, order_status FROM dbo.orders WHERE order_id IN ('ORD_CONC_A','ORD_CONC_B') ORDER BY order_id;" 2>&1

    Stop-SqlSession -Rec $A; Stop-SqlSession -Rec $B
    Write-Output ""
}

Run-SingleCheck
Run-Competition
