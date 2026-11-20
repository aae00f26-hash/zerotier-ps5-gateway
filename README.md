# ZeroTier → PS5 远程串流网关（Windows 11）

让**异地 iPad** 通过 ZeroTier 虚拟局域网，访问**家庭局域网里的 PS5**，用第三方客户端 [PXPlay](https://apps.apple.com/app/psplay-mirror-play-for-ps5/id1640360430)（原名 PSPlay / MirrorPlay）实现 Remote Play 串流。

- 无需给 PS5 安装 ZeroTier
- 无需在路由器开放公网端口
- 无需 ZeroTier 付费功能（用端口转发，不走受管路由）
- 不关闭 Windows 防火墙（只加最小放行规则）
- 使用**编译型 C# 转发器**（高性能，可稳定承载视频流）
- 重启后自动恢复

## 原理

```
iPad（ZeroTier，如 10.219.2.150）
   │  ① 连到网关 ZT IP 的端口 9295(TCP) / 9297·8572(UDP)…
   ▼
Windows 11（ZeroTier 如 10.219.2.251 + 家庭网如 192.168.31.126）
   │  ② TCP 端口转发(portproxy) + C# UDP 转发器，把流量转到 PS5
   ▼
PS5（家庭局域网，如 192.168.31.92）
```

iPad 把「PS5 地址」填成**网关的 ZeroTier IP**，Windows 把 Remote Play 端口转发到 PS5。

## 前置条件

- Windows 11（管理员权限），有线连接家庭路由器
- 已装 ZeroTier 并加入同一网络，记录本机 ZeroTier IP
- PS5 与电脑同一局域网，记录 PS5 的 IP
- PS5 开启：系统 → 远程游玩 → 启用远程游玩；省电 → 待机可用功能 →「与互联网保持连接」+「通过网络打开 PS5」
- iPad：ZeroTier + PXPlay（App Store）

## 快速开始

1. 下载本仓库全部文件。
2. 编辑 `setup-gateway.ps1` 顶部「配置区」（PS5 IP、ZeroTier 网段）。
3. 以管理员身份运行：

```powershell
Set-ExecutionPolicy -Scope Process Bypass
.\setup-gateway.ps1
```

脚本会自动：编译 C# 转发器、配置 TCP 端口转发、加防火墙规则、注册开机自启、立即启动。

4. iPad 端 PXPlay：
   - 首次用**与 PS5 相同的 PSN 账号**登录，并按 PS5 显示的 8 位码「关联设备」
   - 添加主机时，IP 填**网关的 ZeroTier IP**（如 `10.219.2.251`），端口默认 `9295`
   - 连接方式选**手动**（直连、低延迟）；「自动」走 PSN 中继，延迟更高

## 端口说明（Sony 官方 PS5 Remote Play 端口）

| 用途 | 端口 | 协议 |
|---|---|---|
| 会话 / 控制 | 9295（及 9296 / 9297 / 9302 / 9303 / 9304） | TCP |
| 串流 / 信令 | 8572、9296、9297、9302、9303、9304 | UDP |
| 唤醒 | 987 | TCP / UDP |

## 手动操作（不用 setup 脚本）

### 1. 编译 UDP 转发器

```powershell
C:\Windows\Microsoft.NET\Framework64\v4.0.30319\csc.exe /target:exe /out:udp-relay.exe udp-relay.cs
udp-relay.exe <PS5_IP> 8572 9296 9297 9302 9303 9304 987
```

### 2. TCP 端口转发

```powershell
foreach ($p in 9295,9296,9297,9302,9303,9304,987) {
  netsh interface portproxy add v4tov4 listenaddress=0.0.0.0 listenport=$p connectaddress=<PS5_IP> connectport=$p
}
```

### 3. 防火墙

```powershell
New-NetFirewallRule -DisplayName "ZT PortForward TCP" -Direction Inbound -Action Allow -Profile Any -RemoteAddress <ZT_SUBNET> -Protocol TCP -LocalPort 9295,9296,9297,9302,9303,9304,987
New-NetFirewallRule -DisplayName "ZT PortForward UDP" -Direction Inbound -Action Allow -Profile Any -RemoteAddress <ZT_SUBNET> -Protocol UDP -LocalPort 8572,9296,9297,9302,9303,9304,987
```

## 卸载 / 回滚

```powershell
netsh interface portproxy reset
Get-NetFirewallRule -DisplayName "ZT PortForward*" | Remove-NetFirewallRule
Unregister-ScheduledTask -TaskName 'ZT-Gateway-UDP-Relay' -Confirm:$false
Get-CimInstance Win32_Process -Filter "Name='udp-relay.exe'" | % { Stop-Process -Id $_.ProcessId -Force }
```

## 常见问题

- **能 ping 通网关但连不上**：PXPlay 未完成「关联设备」（PSN 登录 + 8 位码），或 IP 填错（要填网关 ZT IP）。
- **黑屏后瞬间断开 / 无法建立流式链接**：检查是否残留了 `WinNAT`（`Get-NetNat`）。若之前用过「受管路由 + NAT」方案，请删除：`Get-NetNat | Remove-NetNat`，并关闭 IP 转发（`Set-NetIPInterface ... -Forwarding Disabled`、`IPEnableRouter=0`）。残留的 WinNAT 会在 IP 层丢弃 UDP 包。
- **重启后失效**：确认计划任务存在，或重新运行 `setup-gateway.ps1`。

## 为什么不用「受管路由 + NAT」

1. ZeroTier 受管路由在部分账号/网络下可能提示付费。
2. 三层路由无法转发组播/广播，官方 App 自动发现仍不可用。
3. 端口转发不依赖受管路由，配合支持手动填 IP 的 PXPlay 更简单、可靠、低延迟。

## 注意

- 本方案不修改 PS5、不开放路由器公网端口、不关闭防火墙。
- 文中 IP 均为示例，请替换为实际值。
- 仅供家庭自用。
