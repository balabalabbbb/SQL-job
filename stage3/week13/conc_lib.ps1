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
    $psi.Arguments = '-S "{0}" -E -d retail_store -W -s "|" -r 1 -o "{1}"' -f $script:Server, $outFile
    $psi.RedirectStandardInput = $true
    $psi.RedirectStandardOutput = $false
    $psi.RedirectStandardError = $false
    $psi.UseShellExecute = $false
    $psi.CreateNoWindow = $true

    $proc = New-Object System.Diagnostics.Process
    $proc.StartInfo = $psi
    [void]$proc.Start()
    $rec = @{ Name = $Name; Proc = $proc; OutFile = $outFile }
    $script:Sessions[$proc.Id] = $rec
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
    if (Test-Path $Rec.OutFile) { return Get-Content -Raw -Encoding UTF8 $Rec.OutFile }
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

# 查询某商品当前库存（监控连接）
function Get-Qty {
    param([string]$ProductId)
    $row = & $script:SqlCmd -S $script:Server -E -d retail_store -h -1 -W -Q "SET NOCOUNT ON; SELECT quantity FROM dbo.inventory WHERE product_id='$ProductId';" 2>&1
    return [int]($row | Where-Object { $_ -match '^\s*\d+\s*$' } | Select-Object -First 1)
}
