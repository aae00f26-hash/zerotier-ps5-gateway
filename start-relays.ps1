# Launch the compiled UDP relay (udp-relay.exe) for PS5 Remote Play ports.
# udp-relay.exe must sit in the same directory as this file.
# Usage: powershell -File start-relays.ps1 [-PS5_IP 192.168.31.92] [-Ports 8572,9296,9297,9302,9303,9304,987]
param(
    [string]$PS5_IP = '192.168.31.92',
    [int[]]$Ports = @(8572, 9296, 9297, 9302, 9303, 9304, 987)
)
$dir = $PSScriptRoot
$args = @($PS5_IP) + ($Ports | ForEach-Object { "$_" })
Start-Process -FilePath "$dir\udp-relay.exe" -ArgumentList $args -WindowStyle Hidden
