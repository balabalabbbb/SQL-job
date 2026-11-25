# ============================================================
# conc_lib.ps1
# 第13周 并发控制实验：双会话运行库
# 用两个独立 sqlcmd 进程模拟 SSMS 的 A、B 查询窗口；
# stdin 重定向实现“分步执行 + 暂停”，结果通过 sqlcmd -o 写入文件，
# 避免 PowerShell 在线程池线程上采集 .NET 事件的 runspace 问题。
# 用法：在各实验脚本开头  . "$PSScriptRoot\conc_lib.ps1"
# ============================================================

$script:SqlCmd = "C:\Program Files\Microsoft SQL Server\Client SDK\ODBC\170\Tools\Binn\SQLCMD.EXE"
$script:Server = "localhost\SQLEXPRESS"
$script:Sessions = @{}

function Start-SqlSession {
    param([string]$Name)
    $outFile = [System.IO.Path]::Combine([System.IO.Path]::GetTempPath(), ("sqlconc_{0}_{1}.txt" -f $Name, [System.Guid]::NewGuid().ToString('N').Substring(0,8)))
    if (Test-Path $outFile) { Remove-Item $outFile -Force }

    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = $script:SqlCmd
    # -o 输出文件；-r 1 把错误消息也并入输出文件；-W 去尾空格；-s 列分隔符
    # -u 让 -o 输出文件为 Unicode(UTF-16)，避免中文按 GBK 写入导致读取乱码
    $psi.Arguments = '-S "{0}" -E -d retail_store -W -s "|" -r 1 -u -o "{1}"' -f $script:Server, $outFile
    $psi.RedirectStandardInput = $true
    $psi.RedirectStandardOutput = $false
    $psi.RedirectStandardError = $false
    $psi.UseShellExecute = $false
    $psi.CreateNoWindow = $true

    $proc = New-Object System.Diagnostics.Process
    $proc.StartInfo = $psi
    [void]$proc.Start()
    $rec = @{ Name = $Name; Proc = $proc; OutFile = $outFile; Spid = 0 }
    $script:Sessions[$proc.Id] = $rec

    # 显式确认会话独立性：调用 @@SPID 取本会话 ID。
    # 结果带“SPID=”前缀，不是纯数字行，避免被后续实验的纯数字提取误读。
    Send-Sql -Rec $rec -Sql "SELECT 'SPID=' + CAST(@@SPID AS varchar(10)) AS session_info;`nGO`n"
    $ok = Wait-Until -TimeoutMs 10000 -Label ("会话 {0} 读取 @@SPID" -f $Name) -Condition {
        if (-not (Test-Path $rec.OutFile)) { return $false }
        return [bool]((Get-Content -Raw $rec.OutFile) -match 'SPID=(\d+)')
    }
    if ($ok) {
        $mm = [regex]::Match((Get-Content -Raw $rec.OutFile), 'SPID=(\d+)')
        $rec.Spid = [int]$mm.Groups[1].Value
        # 用 Write-Host（信息流）输出确认，避免被“$A = Start-SqlSession”当作返回值捕获
        Write-Host ("会话 {0} 已建立，@@SPID = {1}" -f $Name, $rec.Spid)
    } else {
        Write-Warning ("会话 {0} 读取 @@SPID 超时" -f $Name)
    }
    return $rec
}

# 向会话写入一批 T-SQL（需自行包含 GO）
function Send-Sql {
    param($Rec, [string]$Sql)
    $Rec.Proc.StandardInput.Write($Sql)
    $Rec.Proc.StandardInput.Flush()
}

function Get-SqlOut {
    param($Rec)
    if (Test-Path $Rec.OutFile) { return Get-Content -Raw $Rec.OutFile }
    return ''
}

function Clear-SqlOut {
    param($Rec)
    if (Test-Path $Rec.OutFile) { Remove-Item $Rec.OutFile -Force }
}

# 关闭会话（先尝试正常退出，超时则终止），并清理临时文件
function Stop-SqlSession {
    param($Rec)
    try { Send-Sql -Rec $Rec -Sql "QUIT`n" } catch {}
    Start-Sleep -Milliseconds 300
    if (-not $Rec.Proc.HasExited) {
        try { $Rec.Proc.StandardInput.Close() } catch {}
        if (-not $Rec.Proc.WaitForExit(2000)) { try { $Rec.Proc.Kill() } catch {} }
    }
    Start-Sleep -Milliseconds 200
    if (Test-Path $Rec.OutFile) { Remove-Item $Rec.OutFile -Force }
}

# 第三个连接：监控锁 / 阻塞（独立短进程，执行完即返回）
function Invoke-Monitor {
    param([string]$Sql)
    & $script:SqlCmd -S $script:Server -E -d retail_store -h -1 -W -s "|" -Q $Sql 2>&1
}

# 重置基线
function Reset-Baseline {
    param([string]$InitPath)
    & $script:SqlCmd -S $script:Server -E -d retail_store -i $InitPath 2>&1 | Out-Null
}

# 查询某商品当前库存（监控连接，默认已提交读）
function Get-Qty {
    param([string]$ProductId)
    $row = & $script:SqlCmd -S $script:Server -E -d retail_store -h -1 -W -Q "SET NOCOUNT ON; SELECT quantity FROM dbo.inventory WHERE product_id='$ProductId';" 2>&1
    return [int]($row | Where-Object { $_ -match '^\s*\d+\s*$' } | Select-Object -First 1)
}

# ============================================================
# 条件轮询：用“等待条件成立”替代固定 Start-Sleep，消除双会话竞态
# 所有探测只查 DMV 或加 NOLOCK，监控连接自身不会被业务锁阻塞。
# ============================================================

# 监控连接执行返回单个标量（无表头）
function Invoke-Scalar {
    param([string]$Sql)
    $r = & $script:SqlCmd -S $script:Server -E -d retail_store -h -1 -W -Q $Sql 2>&1
    return ($r | Where-Object { $_ -match '^\s*.+\s*$' } | Select-Object -First 1)
}

# 通用：轮询直到条件脚本块返回 true，超时则警告并返回 false
function Wait-Until {
    param([scriptblock]$Condition, [int]$TimeoutMs = 15000, [int]$IntervalMs = 200, [string]$Label = '条件')
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    while ($sw.ElapsedMilliseconds -lt $TimeoutMs) {
        if (& $Condition) { return $true }
        Start-Sleep -Milliseconds $IntervalMs
    }
    Write-Warning ("等待超时：{0}" -f $Label)
    return $false
}

# 等待直到出现至少一个阻塞请求
function Wait-Blocked {
    param([int]$TimeoutMs = 15000)
    Wait-Until -TimeoutMs $TimeoutMs -Label '出现阻塞' -Condition {
        [int](Invoke-Scalar "SET NOCOUNT ON; SELECT COUNT(*) FROM sys.dm_exec_requests WHERE blocking_session_id<>0;") -gt 0
    }
}

# 等待直到所有阻塞请求清零
function Wait-NoBlock {
    param([int]$TimeoutMs = 15000)
    Wait-Until -TimeoutMs $TimeoutMs -Label '阻塞清零' -Condition {
        [int](Invoke-Scalar "SET NOCOUNT ON; SELECT COUNT(*) FROM sys.dm_exec_requests WHERE blocking_session_id<>0;") -eq 0
    }
}

# 等待打开的用户事务数等于预期
function Wait-TranCount {
    param([int]$Expected, [int]$TimeoutMs = 15000)
    Wait-Until -TimeoutMs $TimeoutMs -Label ("用户事务数={0}" -f $Expected) -Condition {
        [int](Invoke-Scalar "SET NOCOUNT ON; SELECT COUNT(*) FROM sys.dm_tran_session_transactions;") -eq $Expected
    }
}

# 等待某商品库存（NOLOCK，可读未提交值）等于预期
function Wait-Qty {
    param([string]$ProductId, [int]$Expected, [int]$TimeoutMs = 15000)
    Wait-Until -TimeoutMs $TimeoutMs -Label ("{0} 库存={1}" -f $ProductId, $Expected) -Condition {
        [int](Invoke-Scalar "SET NOCOUNT ON; SELECT quantity FROM dbo.inventory WITH(NOLOCK) WHERE product_id='$ProductId';") -eq $Expected
    }
}
