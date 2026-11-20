# ZeroTier -> PS5 远程串流网关 一键配置脚本（Windows 11，需管理员）
# 运行前修改下方「配置区」。需与本仓库的 udp-relay.cs / start-relays.ps1 同目录。
#Requires -RunAsAdministrator

$ErrorActionPreference = 'Stop'

# ===================== 配置区 =====================
$PS5_IP     = '192.168.31.92'                 # PS5 在家庭局域网的 IP
$ZT_SUBNET  = '10.219.2.0/24'                 # ZeroTier 网段（防火墙只放行该网段）
$TCP_PORTS  = @(9295, 9296, 9297, 9302, 9303, 9304, 987)
$UDP_PORTS  = @(8572, 9296, 9297, 9302, 9303, 9304, 987)
$InstallDir = 'C:\ProgramData\ZT-Gateway'
$TaskName   = 'ZT-Gateway-UDP-Relay'
# ==================================================

# 0) 前置检查
if (-not (Test-Path "$PSScriptRoot\udp-relay.cs"))     { throw "缺少 udp-relay.cs，请从仓库完整下载" }
if (-not (Test-Path "$PSScriptRoot\start-relays.ps1")) { throw "缺少 start-relays.ps1，请从仓库完整下载" }

# 1) 拷贝脚本 + 编译 C# 转发器
New-Item -ItemType Directory -Path $InstallDir -Force | Out-Null
Copy-Item "$PSScriptRoot\udp-relay.cs"     "$InstallDir\udp-relay.cs"     -Force
Copy-Item "$PSScriptRoot\start-relays.ps1" "$InstallDir\start-relays.ps1" -Force
$csc = "C:\Windows\Microsoft.NET\Framework64\v4.0.30319\csc.exe"
if (-not (Test-Path $csc)) { $csc = "C:\Windows\Microsoft.NET\Framework\v4.0.30319\csc.exe" }
& $csc /nologo /target:exe /out:"$InstallDir\udp-relay.exe" "$InstallDir\udp-relay.cs"
Write-Host "[1/5] C# 转发器已编译"

# 2) IP Helper 服务（portproxy 依赖）
Set-Service iphlpsvc -StartupType Automatic -ErrorAction SilentlyContinue
Start-Service iphlpsvc -ErrorAction SilentlyContinue
Write-Host "[2/5] IP Helper 服务已就绪"

# 3) TCP 端口转发
foreach ($p in $TCP_PORTS) {
    netsh interface portproxy delete v4tov4 listenaddress=0.0.0.0 listenport=$p 2>$null | Out-Null
    netsh interface portproxy add v4tov4 listenaddress=0.0.0.0 listenport=$p connectaddress=$PS5_IP connectport=$p | Out-Null
}
Write-Host "[3/5] TCP 端口转发完成"

# 4) 防火墙规则（仅放行 ZeroTier 网段）
New-NetFirewallRule -DisplayName "ZT PortForward TCP" -Direction Inbound -Action Allow -Profile Any -RemoteAddress $ZT_SUBNET -Protocol TCP -LocalPort ($TCP_PORTS -join ',') -Enabled True | Out-Null
New-NetFirewallRule -DisplayName "ZT PortForward UDP" -Direction Inbound -Action Allow -Profile Any -RemoteAddress $ZT_SUBNET -Protocol UDP -LocalPort ($UDP_PORTS -join ',') -Enabled True | Out-Null
Write-Host "[4/5] 防火墙规则完成"

# 5) 开机自启任务 + 立即启动
$arg = "-NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$InstallDir\start-relays.ps1`" -PS5_IP $PS5_IP"
$action    = New-ScheduledTaskAction  -Execute 'powershell.exe' -Argument $arg
$trigger   = New-ScheduledTaskTrigger -AtStartup
$principal = New-ScheduledTaskPrincipal -UserId 'SYSTEM' -LogonType ServiceAccount
Register-ScheduledTask -TaskName $TaskName -Action $action -Trigger $trigger -Principal $principal -Force | Out-Null
& "$InstallDir\start-relays.ps1" -PS5_IP $PS5_IP
Start-Sleep -Seconds 2
Write-Host "[5/5] 开机自启任务已注册，转发器已启动"

Write-Host ""
Write-Host "完成！" -ForegroundColor Green
Write-Host "  iPad/PXPlay 主机 IP 请填：本机 ZeroTier IP，端口默认 9295"
Write-Host "  撤销：见 README「卸载 / 回滚」"
