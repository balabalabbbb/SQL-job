# ============================================================
# exp5_regression.ps1
# 第13周 业务回归：事务正常/重复调用校验 + 双会话竞争购买 P×6
# ============================================================
. "$PSScriptRoot\conc_lib.ps1"
$init = "$PSScriptRoot\00_init.sql"

# 单订单：正常提交 + 重复调用拒绝
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

# 双会话同时竞争购买 P×6，仅一单成功
function Run-Competition {
    Write-Output ("="*70)
    Write-Output "回归2：P=10，A、B 两个会话同时完成购买 P×6 的不同订单 —— 仅一单成功"
    Write-Output ("="*70)
    Reset-Baseline -InitPath $init
    Write-Output ("初始 P = {0}" -f (Get-Qty 'P'))
    $A = Start-SqlSession -Name 'A8'
    $B = Start-SqlSession -Name 'B8'

    # 几乎同时发出两个订单完成事务
    Send-Sql -Rec $A -Sql "EXEC dbo.usp_complete_order_transaction 'ORD_CONC_A';`nGO`n"
    Send-Sql -Rec $B -Sql "EXEC dbo.usp_complete_order_transaction 'ORD_CONC_B';`nGO`n"
    # 轮询等待竞争结束：成功单提交后 P=4、所有事务归零，再读取结果
    [void](Wait-Qty -ProductId 'P' -Expected 4 -TimeoutMs 20000)
    [void](Wait-TranCount -Expected 0 -TimeoutMs 15000)
    # 再轮询等待两个会话结果均已落盘：成功单含“已完成并提交”，失败单含“消息 5xxxx”错误号，
    # 避免在错误号行尚未 flush 时就读取。
    [void](Wait-Until -TimeoutMs 15000 -Label '两会话结果已落盘' -Condition {
        $a = Get-SqlOut -Rec $A; $b = Get-SqlOut -Rec $B
        ($a -match '已完成并提交|消息\s*5\d{4}') -and ($b -match '已完成并提交|消息\s*5\d{4}')
    })

    # 失败方可能被触发器 51008（库存充足性检查）或存储过程 52005（条件更新行数检查）拦截，
    # 过滤同时保留“消息 5xxxx”错误号行与业务文本行，两道防线都能阻止超卖。
    $pat = '消息\s*5\d{4}|已完成并提交|不足|回滚'
    Write-Output "--- A 会话输出 ---"
    (Get-SqlOut -Rec $A) -split "`n" | Where-Object { $_ -match $pat }
    Write-Output "--- B 会话输出 ---"
    (Get-SqlOut -Rec $B) -split "`n" | Where-Object { $_ -match $pat }

    Write-Output ("最终 P = {0}（预期 4）" -f (Get-Qty 'P'))
    Write-Output "--- 两个订单最终状态（应一个已完成、一个待支付）---"
    Invoke-Monitor -Sql "SET NOCOUNT ON; SELECT order_id, order_status FROM dbo.orders WHERE order_id IN ('ORD_CONC_A','ORD_CONC_B') ORDER BY order_id;" 2>&1

    Stop-SqlSession -Rec $A; Stop-SqlSession -Rec $B
    Write-Output ""
}

Run-SingleCheck
Run-Competition
