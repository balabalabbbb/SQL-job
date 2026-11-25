# ============================================================
# exp3_repeatable_read.ps1
# 第13周 实验3：不可重复读（READ COMMITTED）与可重复读（REPEATABLE READ）对照
# 列别名使用英文，避免输出文件解析歧义。
# ============================================================
. "$PSScriptRoot\conc_lib.ps1"
$init = "$PSScriptRoot\00_init.sql"

$blockSql = @"
SET NOCOUNT ON;
SELECT r.session_id AS sid, r.blocking_session_id AS blocked_by, r.status, r.wait_type AS wait, r.wait_resource AS resource
FROM sys.dm_exec_requests r WHERE r.blocking_session_id <> 0;
"@

# 场景A：READ COMMITTED 出现不可重复读
function Run-NonRepeatable {
    Write-Output ("="*70)
    Write-Output "场景A：READ COMMITTED —— A 两次读取之间 B 提交，出现不可重复读"
    Write-Output ("="*70)
    Reset-Baseline -InitPath $init
    Write-Output ("初始 P = {0}" -f (Get-Qty 'P'))
    $A = Start-SqlSession -Name 'A4'
    $B = Start-SqlSession -Name 'B4'

    # A1：事务内第一次读 P
    Send-Sql -Rec $A -Sql "SET TRANSACTION ISOLATION LEVEL READ COMMITTED;`nBEGIN TRANSACTION;`nSELECT quantity AS r1 FROM dbo.inventory WHERE product_id='P';`nGO`n"
    Start-Sleep -Milliseconds 800
    Write-Output "--- A 第一次读取（应 10）---"
    (Get-SqlOut -Rec $A) -split "`n" | Where-Object { $_ -match '^\s*\d+\s*$' } | Select-Object -First 1

    # B1：补货提交，P 10 -> 15
    Send-Sql -Rec $B -Sql "BEGIN TRANSACTION;`nUPDATE dbo.inventory SET quantity=quantity+5, last_updated=SYSDATETIME() WHERE product_id='P';`nCOMMIT TRANSACTION;`nGO`n"
    Start-Sleep -Milliseconds 1000
    Write-Output ("B 已提交补货，当前 P = {0}" -f (Get-Qty 'P'))

    # A2：同一事务内第二次读，读到 15
    Send-Sql -Rec $A -Sql "SELECT quantity AS r2 FROM dbo.inventory WHERE product_id='P';`nCOMMIT TRANSACTION;`nGO`n"
    Start-Sleep -Milliseconds 1000
    Write-Output "--- A 第二次读取（应 15，与第一次不同 -> 不可重复读）---"
    (Get-SqlOut -Rec $A) -split "`n" | Where-Object { $_ -match '^\s*\d+\s*$' } | Select-Object -Last 1

    Stop-SqlSession -Rec $A; Stop-SqlSession -Rec $B
    Write-Output ""
}

# 场景B：REPEATABLE READ 可重复读，B 被阻塞
function Run-Repeatable {
    Write-Output ("="*70)
    Write-Output "场景B：REPEATABLE READ —— A 持有共享锁，B 的修改被阻塞，A 两次都读 10"
    Write-Output ("="*70)
    Reset-Baseline -InitPath $init
    Write-Output ("初始 P = {0}" -f (Get-Qty 'P'))
    $A = Start-SqlSession -Name 'A5'
    $B = Start-SqlSession -Name 'B5'

    # A1：REPEATABLE READ 事务内第一次读，共享锁持有到事务结束
    Send-Sql -Rec $A -Sql "SET TRANSACTION ISOLATION LEVEL REPEATABLE READ;`nBEGIN TRANSACTION;`nSELECT quantity AS r1 FROM dbo.inventory WHERE product_id='P';`nGO`n"
    Start-Sleep -Milliseconds 800
    Write-Output "--- A 第一次读取（应 10）---"
    (Get-SqlOut -Rec $A) -split "`n" | Where-Object { $_ -match '^\s*\d+\s*$' } | Select-Object -First 1

    # B1：尝试修改 P，被 A 的共享锁阻塞
    Send-Sql -Rec $B -Sql "BEGIN TRANSACTION;`nUPDATE dbo.inventory SET quantity=quantity+5, last_updated=SYSDATETIME() WHERE product_id='P';`nGO`n"
    Start-Sleep -Milliseconds 1200
    Write-Output "B1 已发出：B 等待 A 的共享锁释放"
    Write-Output "--- 监控 dm_exec_requests（应见 B 等待 LCK_M_X）---"
    Invoke-Monitor -Sql $blockSql

    # A2：第二次读，仍为 10，然后提交释放锁
    Send-Sql -Rec $A -Sql "SELECT quantity AS r2 FROM dbo.inventory WHERE product_id='P';`nCOMMIT TRANSACTION;`nGO`n"
    Start-Sleep -Milliseconds 1200
    Write-Output "--- A 第二次读取（应仍为 10 -> 可重复读）---"
    (Get-SqlOut -Rec $A) -split "`n" | Where-Object { $_ -match '^\s*\d+\s*$' } | Select-Object -Last 1

    # B2：A 提交后 B 解除阻塞并提交
    Send-Sql -Rec $B -Sql "COMMIT TRANSACTION;`nGO`n"
    Start-Sleep -Milliseconds 1000
    Write-Output ("A 提交后 B 继续，最终 P = {0}（预期 15）" -f (Get-Qty 'P'))

    Stop-SqlSession -Rec $A; Stop-SqlSession -Rec $B
    Write-Output ""
}

Run-NonRepeatable
Run-Repeatable
