# ============================================================
# exp2_dirty_read.ps1
# 第13周 实验2：脏读（READ UNCOMMITTED）与已提交读（READ COMMITTED）对照
# 本库 READ_COMMITTED_SNAPSHOT = 0（关闭），READ COMMITTED 采用传统锁。
# 列别名使用英文，避免输出文件解析歧义。
# ============================================================
. "$PSScriptRoot\conc_lib.ps1"
$init = "$PSScriptRoot\00_init.sql"

$blockSql = @"
SET NOCOUNT ON;
SELECT r.session_id AS sid, r.blocking_session_id AS blocked_by, r.status, r.wait_type AS wait, r.wait_resource AS resource
FROM sys.dm_exec_requests r WHERE r.blocking_session_id <> 0;
"@

function Run-DirtyRead {
    Write-Output ("="*70)
    Write-Output "场景A：READ UNCOMMITTED —— B 读到 A 未提交的 15（脏读）"
    Write-Output ("="*70)
    Reset-Baseline -InitPath $init
    Write-Output ("初始 P = {0}" -f (Get-Qty 'P'))
    $A = Start-SqlSession -Name 'A2'
    $B = Start-SqlSession -Name 'B2'

    Send-Sql -Rec $A -Sql "BEGIN TRANSACTION;`nUPDATE dbo.inventory SET quantity=15, last_updated=SYSDATETIME() WHERE product_id='P';`nGO`n"
    Start-Sleep -Milliseconds 700
    Write-Output "A1：A 已把 P 改为 15，未提交"

    Send-Sql -Rec $B -Sql "SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;`nSELECT quantity AS r1 FROM dbo.inventory WHERE product_id='P';`nGO`n"
    [void](Wait-Until -TimeoutMs 10000 -Label 'B1脏读15' -Condition { (Get-SqlOut $B) -match '(?m)^\s*15\s*$' })
    Write-Output "--- B1 结果（脏读，应读到 15）---"
    (Get-SqlOut -Rec $B) -split "`n" | Where-Object { $_ -match '^\s*\d+\s*$' } | Select-Object -First 1

    Send-Sql -Rec $A -Sql "ROLLBACK TRANSACTION;`nGO`n"
    Start-Sleep -Milliseconds 800
    Write-Output ("A2：A 回滚，真实 P 恢复为 {0}" -f (Get-Qty 'P'))

    Send-Sql -Rec $B -Sql "SELECT quantity AS r2 FROM dbo.inventory WHERE product_id='P';`nGO`n"
    [void](Wait-Until -TimeoutMs 10000 -Label 'B2读到10' -Condition { (Get-SqlOut $B) -match '(?m)^\s*10\s*$' })
    Write-Output "--- B2 结果（应读到 10，证明 15 是脏数据）---"
    (Get-SqlOut -Rec $B) -split "`n" | Where-Object { $_ -match '^\s*\d+\s*$' } | Select-Object -Last 1

    Stop-SqlSession -Rec $A; Stop-SqlSession -Rec $B
    Write-Output ""
}

function Run-CommittedRead {
    Write-Output ("="*70)
    Write-Output "场景B：READ COMMITTED（RCSI关闭）—— B 的读取等待 A，只读到已提交的 10"
    Write-Output ("="*70)
    Reset-Baseline -InitPath $init
    Write-Output ("初始 P = {0}" -f (Get-Qty 'P'))
    $A = Start-SqlSession -Name 'A3'
    $B = Start-SqlSession -Name 'B3'

    Send-Sql -Rec $A -Sql "BEGIN TRANSACTION;`nUPDATE dbo.inventory SET quantity=15, last_updated=SYSDATETIME() WHERE product_id='P';`nGO`n"
    Start-Sleep -Milliseconds 700
    Write-Output "A1：A 已把 P 改为 15，未提交"

    Send-Sql -Rec $B -Sql "SET TRANSACTION ISOLATION LEVEL READ COMMITTED;`nSELECT quantity AS r1 FROM dbo.inventory WHERE product_id='P';`nGO`n"
    [void](Wait-Blocked -TimeoutMs 10000)
    Write-Output "B1 已发出：B 的共享锁等待 A 释放"
    Write-Output "--- 监控 dm_exec_requests（应见 B 等待 LCK_M_S）---"
    Invoke-Monitor -Sql $blockSql

    Send-Sql -Rec $A -Sql "ROLLBACK TRANSACTION;`nGO`n"
    [void](Wait-Until -TimeoutMs 15000 -Label 'B读到已提交10' -Condition { (Get-SqlOut $B) -match '(?m)^\s*10\s*$' })
    Write-Output "A2：A 回滚并释放锁，B 的读取继续"

    Write-Output "--- B1 最终结果（应读到已提交的 10，读不到 15）---"
    (Get-SqlOut -Rec $B) -split "`n" | Where-Object { $_ -match '^\s*\d+\s*$' } | Select-Object -Last 1
    Write-Output ("监控连接确认真实 P = {0}" -f (Get-Qty 'P'))

    Stop-SqlSession -Rec $A; Stop-SqlSession -Rec $B
    Write-Output ""
}

Run-DirtyRead
Run-CommittedRead
