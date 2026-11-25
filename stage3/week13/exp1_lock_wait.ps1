# ============================================================
# exp1_lock_wait.ps1
# 第13周 实验1：同一库存上的写入等待（阻塞）
# 场景A：A 提交 -> P 最终 13；场景B：A 回滚 -> P 最终 15
# ============================================================
. "$PSScriptRoot\conc_lib.ps1"
$init = "$PSScriptRoot\00_init.sql"

$blockSql = @"
SET NOCOUNT ON;
SELECT r.session_id AS sid, r.blocking_session_id AS blocked_by, r.status, r.wait_type AS wait, r.wait_resource AS resource
FROM sys.dm_exec_requests r WHERE r.blocking_session_id <> 0;
"@

$lockSql = @"
SET NOCOUNT ON;
SELECT l.request_session_id AS sid, l.resource_type AS rtype, l.request_mode AS mode, l.request_status AS status,
       OBJECT_NAME(p.object_id) AS obj, l.resource_description AS rdesc
FROM sys.dm_tran_locks l
LEFT JOIN sys.partitions p ON p.hobt_id = l.resource_associated_entity_id
WHERE l.resource_database_id = DB_ID('retail_store')
ORDER BY l.request_session_id, l.resource_type;
"@

function Run-Scenario {
    param([string]$Mode)
    Write-Output ("="*70)
    Write-Output "场景：A 扣 P 2 件不提交，B 给 P 加 5 件 -> A 执行 $Mode"
    Write-Output ("="*70)
    Reset-Baseline -InitPath $init
    Write-Output ("初始 P 库存 = {0}" -f (Get-Qty 'P'))

    $A = Start-SqlSession -Name 'A'
    $B = Start-SqlSession -Name 'B'

    Send-Sql -Rec $A -Sql "BEGIN TRANSACTION;`nUPDATE dbo.inventory SET quantity = quantity - 2, last_updated=SYSDATETIME() WHERE product_id='P';`nGO`n"
    Start-Sleep -Milliseconds 700
    Write-Output "A1 已执行：A 持有 P 的排他锁，未提交"

    Send-Sql -Rec $B -Sql "BEGIN TRANSACTION;`nUPDATE dbo.inventory SET quantity = quantity + 5, last_updated=SYSDATETIME() WHERE product_id='P';`nGO`n"
    Start-Sleep -Milliseconds 1500
    Write-Output "B1 已发出：B 等待 A 释放 P 的锁"

    Write-Output "--- 监控 dm_exec_requests（阻塞者/等待者）---"
    Invoke-Monitor -Sql $blockSql
    Write-Output "--- 监控 dm_tran_locks（锁模式与授予/等待状态）---"
    Invoke-Monitor -Sql $lockSql

    if ($Mode -eq 'Commit') {
        Send-Sql -Rec $A -Sql "COMMIT TRANSACTION;`nGO`n"
        Write-Output "A2：A 提交，释放 P 的锁"
    } else {
        Send-Sql -Rec $A -Sql "ROLLBACK TRANSACTION;`nGO`n"
        Write-Output "A2：A 回滚，扣减撤销，释放 P 的锁"
    }
    Start-Sleep -Milliseconds 1200

    Send-Sql -Rec $B -Sql "COMMIT TRANSACTION;`nGO`n"
    Start-Sleep -Milliseconds 800

    $final = Get-Qty 'P'
    Write-Output ("最终 P 库存 = {0}（预期 {1}）" -f $final, $(if($Mode -eq 'Commit'){13}else{15}))

    Write-Output "--- B 会话输出（确认其等待后继续执行）---"
    (Get-SqlOut -Rec $B) -split "`n" | Where-Object { $_ -and $_ -notmatch '^\s*\d+>' } | Select-Object -First 15

    Stop-SqlSession -Rec $A
    Stop-SqlSession -Rec $B
    Write-Output ""
}

Run-Scenario -Mode 'Commit'
Run-Scenario -Mode 'Rollback'
