# ============================================================
# exp4_deadlock.ps1
# 第13周 实验4：死锁复现与按序更新改进
# 场景A：交叉更新形成死锁，死锁监视器牺牲一个会话（错误 1205）
# 场景B：统一按 product_id 升序访问，消除循环等待
# ============================================================
. "$PSScriptRoot\conc_lib.ps1"
$init = "$PSScriptRoot\00_init.sql"

$blockSql = @"
SET NOCOUNT ON;
SELECT r.session_id AS sid, r.blocking_session_id AS blocked_by, r.status, r.wait_type AS wait, r.wait_resource AS resource
FROM sys.dm_exec_requests r WHERE r.blocking_session_id <> 0;
"@

# 场景A：死锁复现
function Run-Deadlock {
    Write-Output ("="*70)
    Write-Output "场景A：A 持 P 等 Q、B 持 Q 等 P -> 死锁，监视器终止其中一个（1205）"
    Write-Output ("="*70)
    Reset-Baseline -InitPath $init
    Write-Output ("初始 P={0}, Q={1}" -f (Get-Qty 'P'), (Get-Qty 'Q'))
    $A = Start-SqlSession -Name 'A6'
    $B = Start-SqlSession -Name 'B6'

    # A1：A 先锁 P
    Send-Sql -Rec $A -Sql "BEGIN TRANSACTION;`nUPDATE dbo.inventory SET quantity=quantity-1, last_updated=SYSDATETIME() WHERE product_id='P';`nGO`n"
    Start-Sleep -Milliseconds 700
    # B1：B 先锁 Q
    Send-Sql -Rec $B -Sql "BEGIN TRANSACTION;`nUPDATE dbo.inventory SET quantity=quantity-1, last_updated=SYSDATETIME() WHERE product_id='Q';`nGO`n"
    Start-Sleep -Milliseconds 700
    Write-Output "A 已持 P，B 已持 Q"

    # A2：A 请求 Q（被 B 阻塞）
    Send-Sql -Rec $A -Sql "UPDATE dbo.inventory SET quantity=quantity-1, last_updated=SYSDATETIME() WHERE product_id='Q';`nGO`n"
    Start-Sleep -Milliseconds 500
    # B2：B 请求 P（被 A 阻塞），形成循环
    Send-Sql -Rec $B -Sql "UPDATE dbo.inventory SET quantity=quantity-1, last_updated=SYSDATETIME() WHERE product_id='P';`nGO`n"
    Write-Output "A 请求 Q、B 请求 P，循环等待形成，等待死锁监视器介入..."
    Start-Sleep -Milliseconds 6000

    Write-Output "--- 死锁发生瞬间的阻塞关系（监视器介入前）---"
    Invoke-Monitor -Sql $blockSql

    # 被牺牲会话的输出（错误 1205 已由 -r 1 并入输出文件）
    Write-Output "--- B 会话输出（预期错误 1205，被牺牲并回滚）---"
    $err4 = Get-SqlOut $B
    ($err4 -split "`n" | Where-Object { $_ -match '1205|Msg|级别|Level|状态|State' }) -join "`n"
    if ($err4 -match '1205') { Write-Output "确认：检测到死锁错误 1205" } else { Write-Output "（从输出文件提取错误信息）" }

    Stop-SqlSession -Rec $A; Stop-SqlSession -Rec $B
    Write-Output ("死锁后数据：P={0}, Q={1}（被牺牲者回滚，数据保持一致）" -f (Get-Qty 'P'), (Get-Qty 'Q'))
    Write-Output ""
}

# 场景B：按序更新改进，无死锁
function Run-OrderedUpdate {
    Write-Output ("="*70)
    Write-Output "场景B：两个事务都按 product_id 升序（P -> Q）更新 -> 无循环等待，无死锁"
    Write-Output ("="*70)
    Reset-Baseline -InitPath $init
    Write-Output ("初始 P={0}, Q={1}" -f (Get-Qty 'P'), (Get-Qty 'Q'))
    $A = Start-SqlSession -Name 'A7'
    $B = Start-SqlSession -Name 'B7'

    # A：先 P 后 Q
    Send-Sql -Rec $A -Sql "BEGIN TRANSACTION;`nUPDATE dbo.inventory SET quantity=quantity-1, last_updated=SYSDATETIME() WHERE product_id='P';`nUPDATE dbo.inventory SET quantity=quantity-1, last_updated=SYSDATETIME() WHERE product_id='Q';`nGO`n"
    Start-Sleep -Milliseconds 700
    # B：同样先 P 后 Q，在 P 上即被 A 阻塞，不会先拿到 Q，避免循环
    Send-Sql -Rec $B -Sql "BEGIN TRANSACTION;`nUPDATE dbo.inventory SET quantity=quantity-1, last_updated=SYSDATETIME() WHERE product_id='P';`nUPDATE dbo.inventory SET quantity=quantity-1, last_updated=SYSDATETIME() WHERE product_id='Q';`nGO`n"
    Start-Sleep -Milliseconds 1200
    Write-Output "B 在 P 上等待 A（单向等待，无循环）"
    Write-Output "--- 监控 dm_exec_requests（应只见 B 被 A 阻塞，无死锁）---"
    Invoke-Monitor -Sql $blockSql

    # A 提交，B 随后继续
    Send-Sql -Rec $A -Sql "COMMIT TRANSACTION;`nGO`n"
    Start-Sleep -Milliseconds 1000
    Send-Sql -Rec $B -Sql "COMMIT TRANSACTION;`nGO`n"
    Start-Sleep -Milliseconds 1000

    Write-Output ("A 提交后 B 正常完成：P={0}, Q={1}（预期 P=8, Q=6），全程无 1205" -f (Get-Qty 'P'), (Get-Qty 'Q'))
    Stop-SqlSession -Rec $A; Stop-SqlSession -Rec $B
    Write-Output ""
}

Run-Deadlock
Run-OrderedUpdate
