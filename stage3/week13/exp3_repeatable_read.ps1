# ============================================================
# exp3_repeatable_read.ps1
# 第13周 实验3：不可重复读（READ COMMITTED）与可重复读（REPEATABLE READ）对照
# ============================================================
. "$PSScriptRoot\conc_lib.ps1"
$init = "$PSScriptRoot\00_init.sql"

$blockSql = @"
SET NOCOUNT ON;
SELECT r.session_id AS sid, r.blocking_session_id AS blocked_by, r.status, r.wait_type AS wait, r.wait_resource AS resource
FROM sys.dm_exec_requests r WHERE r.blocking_session_id <> 0;
"@

# 场景A：READ COMMITTED 出现不可重复读（10 -> 15）
function Run-NonRepeatable {
    Write-Output ("="*70)
    Write-Output "场景A：READ COMMITTED —— A 两次读之间 B 补货，读到 10 再读 15（不可重复读）"
    Write-Output ("="*70)
    Reset-Baseline -InitPath $init
    Write-Output ("初始 P = {0}" -f (Get-Qty 'P'))
    $A = Start-SqlSession -Name 'A4'
    $B = Start-SqlSession -Name 'B4'

    # A1：READ COMMITTED 开事务，第一次读 P
    Send-Sql -Rec $A -Sql "SET TRANSACTION ISOLATION LEVEL READ COMMITTED;`nBEGIN TRANSACTION;`nSELECT quantity AS r1 FROM dbo.inventory WHERE product_id='P';`nGO`n"
    # 轮询等待第一次读取结果（r1=10）真正写入，替代固定 sleep
    [void](Wait-Until -TimeoutMs 15000 -Label 'A第一次读 r1=10' -Condition { (Get-SqlOut $A) -match 'r1\s+--\s+10' })
    Write-Output "--- A 第一次读（应 10）---"
    (Get-SqlOut -Rec $A) -split "`n" | Where-Object { $_ -match '^\s*\d+\s*$' } | Select-Object -Last 1

    # B1：补货事务，P +5 并提交
    Send-Sql -Rec $B -Sql "BEGIN TRANSACTION;`nUPDATE dbo.inventory SET quantity=quantity+5, last_updated=SYSDATETIME() WHERE product_id='P';`nCOMMIT TRANSACTION;`nGO`n"
    [void](Wait-Qty -ProductId 'P' -Expected 15 -TimeoutMs 15000)
    Write-Output ("B 已补货并提交，当前 P = {0}" -f (Get-Qty 'P'))

    # A2：同一事务第二次读，读到 15（不可重复读）
    Send-Sql -Rec $A -Sql "SELECT quantity AS r2 FROM dbo.inventory WHERE product_id='P';`nGO`n"
    # 轮询等待第二次读取（r2=15）完成，确认与第一次不同
    [void](Wait-Until -TimeoutMs 15000 -Label 'A第二次读 r2=15' -Condition { (Get-SqlOut $A) -match 'r2\s+--\s+15' })
    Write-Output "--- A 第二次读（应 15，与第一次不同）---"
    (Get-SqlOut -Rec $A) -split "`n" | Where-Object { $_ -match '^\s*\d+\s*$' } | Select-Object -Last 1
    Send-Sql -Rec $A -Sql "COMMIT TRANSACTION;`nGO`n"
    Start-Sleep -Milliseconds 500

    Stop-SqlSession -Rec $A; Stop-SqlSession -Rec $B
    Write-Output ""
}

# 场景B：REPEATABLE READ 可重复读，B 被阻塞，A 两次都读 10
function Run-Repeatable {
    Write-Output ("="*70)
    Write-Output "场景B：REPEATABLE READ —— A 持有共享锁，B 等待；A 两次都读 10，提交后 B 才继续"
    Write-Output ("="*70)
    Reset-Baseline -InitPath $init
    Write-Output ("初始 P = {0}" -f (Get-Qty 'P'))
    $A = Start-SqlSession -Name 'A5'
    $B = Start-SqlSession -Name 'B5'

    # A1：REPEATABLE READ 开事务，第一次读 P（共享锁保留到事务结束）
    Send-Sql -Rec $A -Sql "SET TRANSACTION ISOLATION LEVEL REPEATABLE READ;`nBEGIN TRANSACTION;`nSELECT quantity AS r1 FROM dbo.inventory WHERE product_id='P';`nGO`n"
    # 轮询等待第一次读取（r1=10）真正写入
    [void](Wait-Until -TimeoutMs 15000 -Label 'A第一次读 r1=10' -Condition { (Get-SqlOut $A) -match 'r1\s+--\s+10' })
    Write-Output "--- A 第一次读（应 10）---"
    (Get-SqlOut -Rec $A) -split "`n" | Where-Object { $_ -match '^\s*\d+\s*$' } | Select-Object -Last 1

    # B1：尝试补货 P +5，被 A 的共享锁阻塞（不提交）
    Send-Sql -Rec $B -Sql "BEGIN TRANSACTION;`nUPDATE dbo.inventory SET quantity=quantity+5, last_updated=SYSDATETIME() WHERE product_id='P';`nGO`n"
    [void](Wait-Blocked -TimeoutMs 10000)
    Write-Output "B1 已发出：B 等待 A 释放共享锁"
    Write-Output "--- 监控 dm_exec_requests（应见 B 等待 LCK_M_X/U）---"
    Invoke-Monitor -Sql $blockSql

    # A2：第二次读，仍为 10（可重复读）
    Send-Sql -Rec $A -Sql "SELECT quantity AS r2 FROM dbo.inventory WHERE product_id='P';`nGO`n"
    # 轮询等待第二次读取（r2=10）完成；用列名 r2 区分于第一次的 r1
    [void](Wait-Until -TimeoutMs 15000 -Label 'A第二次读 r2=10' -Condition { (Get-SqlOut $A) -match 'r2\s+--\s+10' })
    Write-Output "--- A 第二次读（应仍 10）---"
    (Get-SqlOut -Rec $A) -split "`n" | Where-Object { $_ -match '^\s*\d+\s*$' } | Select-Object -Last 1

    # A3：提交，释放共享锁，B 解除阻塞
    Send-Sql -Rec $A -Sql "COMMIT TRANSACTION;`nGO`n"
    # B 解除后执行积压 UPDATE，再处理排队的 COMMIT；轮询等待最终落库
    Send-Sql -Rec $B -Sql "COMMIT TRANSACTION;`nGO`n"
    [void](Wait-Qty -ProductId 'P' -Expected 15 -TimeoutMs 15000)
    [void](Wait-TranCount -Expected 0 -TimeoutMs 10000)
    Write-Output ("最终 P = {0}（预期 15）" -f (Get-Qty 'P'))

    Stop-SqlSession -Rec $A; Stop-SqlSession -Rec $B
    Write-Output ""
}

Run-NonRepeatable
Run-Repeatable
