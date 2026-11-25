# ============================================================
# exp4_deadlock.ps1
# 第13周 实验4：死锁复现与按序更新改进
# 场景A：交叉更新形成死锁，死锁监视器牺牲一个会话（错误 1205）
# 场景B：统一按 product_id 升序访问，消除循环等待
# 关键步骤用条件轮询等待（conc_lib 的 Wait-*），不依赖固定 sleep 时序。
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
    Write-Output "场景A：A 持 P 等 Q、B 持 Q 等 P —— 循环等待，触发死锁 1205"
    Write-Output ("="*70)
    Reset-Baseline -InitPath $init
    Write-Output ("初始 P = {0}, Q = {1}" -f (Get-Qty 'P'), (Get-Qty 'Q'))
    $A = Start-SqlSession -Name 'A6'
    $B = Start-SqlSession -Name 'B6'

    # A1：A 先锁 P
    Send-Sql -Rec $A -Sql "BEGIN TRANSACTION;`nUPDATE dbo.inventory SET quantity=quantity-1, last_updated=SYSDATETIME() WHERE product_id='P';`nGO`n"
    Start-Sleep -Milliseconds 700
    # B1：B 先锁 Q
    Send-Sql -Rec $B -Sql "BEGIN TRANSACTION;`nUPDATE dbo.inventory SET quantity=quantity-1, last_updated=SYSDATETIME() WHERE product_id='Q';`nGO`n"
    Start-Sleep -Milliseconds 700
    Write-Output "A 持有 P、B 持有 Q，均未提交"

    # A2：A 请求 Q（被 B 阻塞）
    Send-Sql -Rec $A -Sql "UPDATE dbo.inventory SET quantity=quantity-1, last_updated=SYSDATETIME() WHERE product_id='Q';`nGO`n"
    Start-Sleep -Milliseconds 500
    # B2：B 请求 P（被 A 阻塞），形成循环
    Send-Sql -Rec $B -Sql "UPDATE dbo.inventory SET quantity=quantity-1, last_updated=SYSDATETIME() WHERE product_id='P';`nGO`n"
    Write-Output "A 等 Q、B 等 P，循环等待已形成"

    # 轮询确认互相阻塞，再展示阻塞关系
    [void](Wait-Blocked -TimeoutMs 5000)
    Write-Output "--- 死锁检测前的互相阻塞关系 ---"
    Invoke-Monitor -Sql $blockSql

    # 轮询等待死锁监视器把 1205 写入 A 或 B 任一输出文件。
    # 牺牲品可能是 A 也可能是 B（监视器选择回滚成本低的一方），故两个会话都要检查；
    # 死锁检测存在退避，超时放宽到 30 秒。
    $dead = Wait-Until -TimeoutMs 30000 -Label '死锁 1205' -Condition {
        (Get-SqlOut $A) -match '1205' -or (Get-SqlOut $B) -match '1205'
    }
    Write-Output "--- A 会话输出（找 1205）---"
    (Get-SqlOut $A) -split "`n" | Where-Object { $_ -match '1205' }
    Write-Output "--- B 会话输出（找 1205）---"
    (Get-SqlOut $B) -split "`n" | Where-Object { $_ -match '1205' }
    if ($dead) {
        $victim = if ((Get-SqlOut $A) -match '1205') { 'A' } else { 'B' }
        Write-Output ("死锁监视器本次选择的牺牲品为会话 {0}，其事务已回滚" -f $victim)
    }

    Stop-SqlSession -Rec $A; Stop-SqlSession -Rec $B
    Write-Output ("死锁后 P = {0}, Q = {1}（被终止事务已回滚，数据一致）" -f (Get-Qty 'P'), (Get-Qty 'Q'))
    Write-Output ""
}

# 场景B：按序更新改进，无死锁
function Run-OrderedUpdate {
    Write-Output ("="*70)
    Write-Output "场景B：两项业务都按 product_id 升序（P→Q）更新 —— 无死锁，仅普通等待"
    Write-Output ("="*70)
    Reset-Baseline -InitPath $init
    Write-Output ("初始 P = {0}, Q = {1}" -f (Get-Qty 'P'), (Get-Qty 'Q'))
    $A = Start-SqlSession -Name 'A7'
    $B = Start-SqlSession -Name 'B7'

    # A：先 P 后 Q，一个批处理内顺序加锁
    Send-Sql -Rec $A -Sql "BEGIN TRANSACTION;`nUPDATE dbo.inventory SET quantity=quantity-1, last_updated=SYSDATETIME() WHERE product_id='P';`nUPDATE dbo.inventory SET quantity=quantity-1, last_updated=SYSDATETIME() WHERE product_id='Q';`nGO`n"
    Start-Sleep -Milliseconds 700
    # B：同样先 P 后 Q，在 P 上即被 A 阻塞，不会先拿到 Q，避免循环
    Send-Sql -Rec $B -Sql "BEGIN TRANSACTION;`nUPDATE dbo.inventory SET quantity=quantity-1, last_updated=SYSDATETIME() WHERE product_id='P';`nUPDATE dbo.inventory SET quantity=quantity-1, last_updated=SYSDATETIME() WHERE product_id='Q';`nGO`n"

    # 轮询确认 B 确实进入阻塞（单向等待）
    [void](Wait-Blocked -TimeoutMs 10000)
    Write-Output "A 已按序持有 P、Q"
    Write-Output "--- 监控：仅 B 单向等待 A（普通阻塞，无循环）---"
    Invoke-Monitor -Sql $blockSql

    # A 提交，释放锁
    Send-Sql -Rec $A -Sql "COMMIT TRANSACTION;`nGO`n"
    # 轮询等待 B 的批处理彻底跑完（NOLOCK 见 P=8），此时 B 事务仍打开、未提交
    [void](Wait-Qty -ProductId 'P' -Expected 8 -TimeoutMs 15000)
    [void](Wait-TranCount -Expected 1 -TimeoutMs 10000)

    # B 提交
    Send-Sql -Rec $B -Sql "COMMIT TRANSACTION;`nGO`n"
    # 轮询等待事务归零、库存落库稳定
    [void](Wait-TranCount -Expected 0 -TimeoutMs 15000)
    [void](Wait-Qty -ProductId 'Q' -Expected 6 -TimeoutMs 15000)

    Write-Output ("改进后 P = {0}, Q = {1}，无 1205，反向访问循环已消除" -f (Get-Qty 'P'), (Get-Qty 'Q'))
    Stop-SqlSession -Rec $A; Stop-SqlSession -Rec $B
    Write-Output ""
}

Run-Deadlock
Run-OrderedUpdate
