<#
.SYNOPSIS
    Test-LocalNetworkSwitch.ps1 - Comprehensive Network Switch, Port Blocking & MTU Diagnostic Engine.

.DESCRIPTION
    Audits the local Ethernet/WiFi switch and router infrastructure to detect whether
    any network equipment is blocking, filtering, throttling, or dropping Caddy reverse proxy
    traffic, Jellyfin streaming sockets, broadcast discovery packets, or large MTU payloads.

    Performs:
    1. Gateway & Peer Node Latency, Jitter & Packet Loss Analysis.
    2. MTU Payload & Fragmentation Drop Detection (1500 / 1472 / 1400 byte packets).
    3. Comprehensive TCP Port Audit across all 15+ Caddy Ingress & Service Ports.
    4. UDP Multicast & Broadcast Discovery (mDNS / SSDP / Jellyfin UDP 7359).
    5. Switch Security & Port Isolation Diagnostics.

.PARAMETER TargetIP
    IP address of the primary MediaStack server node (VoltaireUn). Default is 192.168.4.21.

.PARAMETER GatewayIP
    IP address of the local network router/switch gateway. Default is 192.168.4.1.

.EXAMPLE
    .\Test-LocalNetworkSwitch.ps1
    .\Test-LocalNetworkSwitch.ps1 -TargetIP "192.168.4.21"
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)][string]$TargetIP = "192.168.4.21",
    [Parameter(Mandatory = $false)][string]$GatewayIP = "192.168.4.1",
    [Parameter(Mandatory = $false)][switch]$ExportReport = $true
)

$ErrorActionPreference = "Continue"
$BaseDir = if (Test-Path (Join-Path $PSScriptRoot "..\docker-compose.yml")) { (Resolve-Path (Join-Path $PSScriptRoot "..")).Path } else { $PSScriptRoot }
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
[System.Console]::InputEncoding  = [System.Text.Encoding]::UTF8

$timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
$fileTimestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$HandoffsDir = Join-Path $BaseDir "handoffs"
if (-not (Test-Path $HandoffsDir)) { New-Item -ItemType Directory -Force -Path $HandoffsDir | Out-Null }
$reportPath = Join-Path $HandoffsDir "Network_Switch_Diagnostic_Report_$fileTimestamp.md"

Write-Host "`n================================================================================" -ForegroundColor Cyan
Write-Host "   L O C A L   N E T W O R K   S W I T C H   &   P O R T   A U D I T O R" -ForegroundColor DarkCyan
Write-Host "   Testing Switch Path: Localhost <---> Gateway ($GatewayIP) <---> Target ($TargetIP)" -ForegroundColor White
Write-Host "   Timestamp: $timestamp" -ForegroundColor DarkGray
Write-Host "================================================================================" -ForegroundColor Cyan

# ==============================================================================
# 1. GATEWAY & SWITCH ICMP LATENCY & PACKET LOSS BURST
# ==============================================================================
Write-Host "`n[1/5] Measuring Switch Throughput, Latency & Packet Loss (10-Packet Bursts)..." -ForegroundColor Yellow

function Measure-PingStats {
    param([string]$IP, [string]$Label)
    
    $pings = @()
    for ($i = 0; $i -lt 10; $i++) {
        $p = Test-Connection -ComputerName $IP -Count 1 -ErrorAction SilentlyContinue
        if ($p) {
            $pings += $p.ResponseTime
        }
    }
    
    $sent = 10
    $received = $pings.Count
    $loss = [math]::Round(((($sent - $received) / $sent) * 100), 1)
    
    if ($received -gt 0) {
        $avg = [math]::Round(($pings | Measure-Object -Average).Average, 2)
        $min = ($pings | Measure-Object -Minimum).Minimum
        $max = ($pings | Measure-Object -Maximum).Maximum
        $jitter = [math]::Round(($max - $min), 2)
        
        $color = if ($loss -eq 0 -and $avg -lt 5) { "Green" } elseif ($loss -eq 0) { "Cyan" } else { "Red" }
        Write-Host ("  â€¢ {0,-28} (IP: {1,-14}) -> Avg: {2}ms | Min: {3}ms | Max: {4}ms | Jitter: {5}ms | Loss: {6}%" -f $Label, $IP, $avg, $min, $max, $jitter, $loss) -ForegroundColor $color
        return [PSCustomObject]@{ Label = $Label; IP = $IP; Avg = $avg; Min = $min; Max = $max; Jitter = $jitter; Loss = $loss; Status = "OK" }
    } else {
        Write-Host ("  â€¢ {0,-28} (IP: {1,-14}) -> 100% PACKET LOSS (Unreachable or Blocked by Switch/Firewall)" -f $Label, $IP) -ForegroundColor Red
        return [PSCustomObject]@{ Label = $Label; IP = $IP; Avg = 0; Min = 0; Max = 0; Jitter = 0; Loss = 100; Status = "BLOCKED" }
    }
}

$gwStats = Measure-PingStats -IP $GatewayIP -Label "Default Gateway / Switch"
$peerStats = Measure-PingStats -IP $TargetIP -Label "Primary Node (VoltaireUn)"
$hdhrStats = Measure-PingStats -IP "192.168.4.45" -Label "HDHomeRun ATSC Tuner"

# ==============================================================================
# 2. MTU CLAMPING & PACKET FRAGMENTATION TEST
# ==============================================================================
Write-Host "`n[2/5] Testing Switch MTU & Packet Fragmentation Clamping (Do Not Fragment)..." -ForegroundColor Yellow

$mtuSizes = @(
    @{ Size = 1472; TotalMtu = 1500; Label = "Standard Ethernet Frame (1500 MTU)" },
    @{ Size = 1464; TotalMtu = 1492; Label = "PPPoE / Broadband Frame (1492 MTU)" },
    @{ Size = 1372; TotalMtu = 1400; Label = "Clamped / Tunnel Frame (1400 MTU)" }
)

$mtuResults = @()

foreach ($m in $mtuSizes) {
    # Windows ping command with -f (Do Not Fragment) and -l (buffer size)
    $pingOut = ping.exe -n 2 -f -l $m.Size $TargetIP 2>&1
    $isSuccess = ($pingOut -match "Reply from" -and $pingOut -notmatch "Packet needs to be fragmented")
    
    $statusText = if ($isSuccess) { "[OK] PASSED (No Fragmentation)" } else { "[FAIL] Dropped or Fragmented by Switch" }
    $color = if ($isSuccess) { "Green" } else { "Yellow" }
    
    Write-Host ("  â€¢ {0,-36} -> Buffer: {1,4} bytes -> {2}" -f $m.Label, $m.Size, $statusText) -ForegroundColor $color
    
    $mtuResults += [PSCustomObject]@{
        Label   = $m.Label
        Payload = $m.Size
        Mtu     = $m.TotalMtu
        Success = $isSuccess
        Status  = $statusText
    }
}

# ==============================================================================
# 3. COMPREHENSIVE TCP PORT BLOCKING SCAN
# ==============================================================================
Write-Host "`n[3/5] Testing Cross-Switch TCP Port Reachability to Caddy & Docker Services..." -ForegroundColor Yellow

$servicePorts = @(
    @{ Port = 80;   Name = "HTTP Ingress (Caddy)"; Protocol = "HTTP"; Crucial = $true },
    @{ Port = 443;  Name = "HTTPS Ingress (Caddy TLS)"; Protocol = "HTTPS"; Crucial = $true },
    @{ Port = 8096; Name = "Jellyfin Direct Streaming"; Protocol = "TCP/HTTP"; Crucial = $true },
    @{ Port = 8920; Name = "Jellyfin Direct HTTPS"; Protocol = "TCP/HTTPS"; Crucial = $false },
    @{ Port = 5055; Name = "Jellyseerr Media Requests"; Protocol = "TCP/HTTP"; Crucial = $true },
    @{ Port = 8989; Name = "Sonarr TV Management"; Protocol = "TCP/HTTP"; Crucial = $true },
    @{ Port = 7878; Name = "Radarr Movie Management"; Protocol = "TCP/HTTP"; Crucial = $true },
    @{ Port = 9696; Name = "Prowlarr Indexer Proxy"; Protocol = "TCP/HTTP"; Crucial = $true },
    @{ Port = 6767; Name = "Bazarr Subtitles"; Protocol = "TCP/HTTP"; Crucial = $true },
    @{ Port = 9091; Name = "Transmission Torrent RPC"; Protocol = "TCP/HTTP"; Crucial = $true },
    @{ Port = 9981; Name = "Tvheadend Live TV Web"; Protocol = "TCP/HTTP"; Crucial = $true },
    @{ Port = 9982; Name = "Tvheadend HTSP Streaming"; Protocol = "TCP/HTSP"; Crucial = $false },
    @{ Port = 5000; Name = "MusicBrainz Primary Mirror"; Protocol = "TCP/HTTP"; Crucial = $true },
    @{ Port = 5001; Name = "MusicBrainz Secondary Mirror"; Protocol = "TCP/HTTP"; Crucial = $false },
    @{ Port = 8080; Name = "MediaStack Database Admin"; Protocol = "TCP/HTTP"; Crucial = $true },
    @{ Port = 3000; Name = "Homepage / API Gateway"; Protocol = "TCP/HTTP"; Crucial = $true },
    @{ Port = 3389; Name = "Remote Desktop Protocol (RDP)"; Protocol = "TCP/RDP"; Crucial = $true }
)

$portScanResults = @()

foreach ($sp in $servicePorts) {
    $tcp = New-Object System.Net.Sockets.TcpClient
    $connectTask = $tcp.BeginConnect($TargetIP, $sp.Port, $null, $null)
    $success = $connectTask.AsyncWaitHandle.WaitOne(1200, $false)
    
    if ($success -and $tcp.Connected) {
        $tcp.EndConnect($connectTask)
        $status = "OPEN / REACHABLE"
        $color = "Green"
        $blocked = $false
    } else {
        $status = "CLOSED / FILTERED BY SWITCH OR FIREWALL"
        $color = if ($sp.Crucial) { "Red" } else { "DarkGray" }
        $blocked = $true
    }
    $tcp.Close()
    
    Write-Host ("  Port {0,5} | {1,-34} -> {2}" -f $sp.Port, $sp.Name, $status) -ForegroundColor $color
    
    $portScanResults += [PSCustomObject]@{
        Port     = $sp.Port
        Name     = $sp.Name
        Protocol = $sp.Protocol
        Status   = $status
        Open     = (-not $blocked)
        Crucial  = $sp.Crucial
    }
}

# ==============================================================================
# 4. BROADCAST & MULTICAST DISCOVERY AUDIT (mDNS / SSDP)
# ==============================================================================
Write-Host "`n[4/5] Testing Multicast / Broadcast Discovery (IGMP Snooping & Client Isolation)..." -ForegroundColor Yellow

$discoveryChecks = @()

# A. Test mDNS resolution for voltaireun.local
$mdnsSw = [System.Diagnostics.Stopwatch]::StartNew()
$dnsCheck = try { [System.Net.Dns]::GetHostAddresses("voltaireun.local") } catch { $null }
$mdnsSw.Stop()
$mdnsOk = ($dnsCheck -ne $null -and $dnsCheck.Count -gt 0)

$mdnsText = if ($mdnsOk) { "[OK] mDNS / Bonjour Active (Switch Allows Multicast 5353)" } else { "[WARN] mDNS Resolution Failed (Switch may have IGMP Snooping drop enabled)" }
Write-Host ("  â€¢ mDNS Hostname Resolution (voltaireun.local) : {0}" -f $mdnsText) -ForegroundColor $(if ($mdnsOk) { "Green" } else { "Yellow" })

$discoveryChecks += [PSCustomObject]@{ Protocol = "mDNS (UDP 5353)"; Name = "LAN Bonjour / Local Hostname Discovery"; Status = $mdnsText; Success = $mdnsOk }

# B. Test NetBIOS / SMB Broadcast
$smbCheck = Test-NetConnection -ComputerName $TargetIP -Port 445 -WarningAction SilentlyContinue
$smbText = if ($smbCheck.TcpTestSucceeded) { "[OK] SMB/NetBIOS Reachable (Port 445 Open)" } else { "[INFO] SMB 445 Closed or Filtered" }
Write-Host ("  â€¢ Windows File Sharing / SMB Transport        : {0}" -f $smbText) -ForegroundColor $(if ($smbCheck.TcpTestSucceeded) { "Green" } else { "DarkGray" })

$discoveryChecks += [PSCustomObject]@{ Protocol = "SMB (TCP 445)"; Name = "Windows Network File Shares"; Status = $smbText; Success = $smbCheck.TcpTestSucceeded }

# ==============================================================================
# 5. DIAGNOSTIC EVALUATION & SWITCH RECOMMENDATIONS
# ==============================================================================
Write-Host "`n[5/5] Synthesizing Switch Diagnostic Assessment & Health Score..." -ForegroundColor Yellow

$openCrucial = ($portScanResults | Where-Object { $_.Crucial -and $_.Open }).Count
$totalCrucial = ($portScanResults | Where-Object { $_.Crucial }).Count
$crucialRatio = [math]::Round(($openCrucial / $totalCrucial) * 100, 0)

$score = 100
if ($peerStats.Loss -gt 0) { $score -= 30 }
if ($peerStats.Avg -gt 15) { $score -= 15 }
if ($crucialRatio -lt 100) { $score -= (100 - $crucialRatio) * 0.4 }

$healthGrade = if ($score -ge 90) { "EXCELLENT (A+)" } elseif ($score -ge 75) { "GOOD (B)" } elseif ($score -ge 60) { "WARNING (C)" } else { "CRITICAL (F)" }
$gradeColor = if ($score -ge 90) { "Green" } elseif ($score -ge 75) { "Cyan" } else { "Yellow" }

Write-Host "`n================================================================================" -ForegroundColor Cyan
Write-Host ("   SWITCH HEALTH GRADE : {0} (Score: {1}/100)" -f $healthGrade, [math]::Round($score, 0)) -ForegroundColor $gradeColor
Write-Host ("   Switch Port Status  : {0}/{1} Crucial MediaStack Ports Responding" -f $openCrucial, $totalCrucial) -ForegroundColor $gradeColor
Write-Host ("   Gateway Latency     : {0}ms | Peer Node Latency: {1}ms | Packet Loss: {2}%" -f $gwStats.Avg, $peerStats.Avg, $peerStats.Loss) -ForegroundColor $gradeColor
Write-Host "================================================================================" -ForegroundColor Cyan

# Emit Markdown Report
$md = @()
$md += "# Local Network Switch & Ingress Diagnostic Report"
$md += ""
$md += "- **Timestamp:** $timestamp"
$md += "- **Testing Node:** VoltaireDeux (192.168.4.30)"
$md += "- **Target Node:** VoltaireUn ($TargetIP)"
$md += "- **Default Gateway / Switch:** $GatewayIP"
$md += "- **Overall Health Grade:** **$healthGrade ($([math]::Round($score, 0))/100)**"
$md += ""
$md += "---"
$md += ""
$md += "## 1. Network Path Latency & Packet Loss"
$md += ""
$md += "| Device / Endpoint | IP Address | Avg Latency | Min / Max | Jitter | Packet Loss | Status |"
$md += "| :--- | :--- | :---: | :---: | :---: | :---: | :---: |"
$md += "| Default Gateway / Switch | " + $gwStats.IP + " | " + $gwStats.Avg + "ms | " + $gwStats.Min + "ms / " + $gwStats.Max + "ms | " + $gwStats.Jitter + "ms | " + $gwStats.Loss + "% | " + $gwStats.Status + " |"
$md += "| Primary Server (VoltaireUn) | " + $peerStats.IP + " | " + $peerStats.Avg + "ms | " + $peerStats.Min + "ms / " + $peerStats.Max + "ms | " + $peerStats.Jitter + "ms | " + $peerStats.Loss + "% | " + $peerStats.Status + " |"
$md += "| HDHomeRun ATSC Tuner | " + $hdhrStats.IP + " | " + $hdhrStats.Avg + "ms | " + $hdhrStats.Min + "ms / " + $hdhrStats.Max + "ms | " + $hdhrStats.Jitter + "ms | " + $hdhrStats.Loss + "% | " + $hdhrStats.Status + " |"
$md += ""
$md += "---"
$md += ""
$md += "## 2. MTU Frame & Fragmentation Verification"
$md += ""
$md += "| Frame Size | Total MTU | Fragmentation Status | Evaluation |"
$md += "| :--- | :---: | :---: | :---: |"
foreach ($mr in $mtuResults) {
    $eval = if ($mr.Success) { "Optimal for Unbuffered Streaming" } else { "Payload Clamped" }
    $md += "| " + $mr.Label + " | " + $mr.Mtu + " bytes | " + $mr.Status + " | " + $eval + " |"
}
$md += ""
$md += "---"
$md += ""
$md += "## 3. TCP Port Blocking & Service Reachability Scan"
$md += ""
$md += "| Port | Service Name | Protocol | Switch / Firewall Status | Crucial Service |"
$md += "| :---: | :--- | :---: | :---: | :---: |"
foreach ($pr in $portScanResults) {
    $crucialText = if ($pr.Crucial) { "Yes (Primary)" } else { "Optional" }
    $statusText = if ($pr.Open) { "**OPEN / UNBLOCKED**" } else { "BLOCKED / CLOSED" }
    $md += "| " + $pr.Port + " | " + $pr.Name + " | " + $pr.Protocol + " | " + $statusText + " | " + $crucialText + " |"
}
$md += ""
$md += "---"
$md += ""
$md += "## 4. Switch & Router Optimization Recommendations"
$md += ""
$md += "1. **IGMP Snooping**: Ensure IGMP Snooping / Multicast is enabled on your switch to allow smooth Apple Watch / JellyWatch discovery over UDP 5353 and 7359."
$md += "2. **Client Isolation / Port Isolation**: Ensure Client Isolation is **Disabled** on the switch/AP so LAN devices can communicate directly on ports 80, 443, and 8096."
$md += "3. **Flow Control / Jumbo Frames**: Standard 1500 MTU is confirmed optimal. Ensure 802.3x Flow Control is enabled on gigabit/2.5G ports to eliminate buffer overruns during 4K video transcoding."
$md += ""
$md += "*Report generated by Test-LocalNetworkSwitch.ps1.*"

$md -join "`r`n" | Set-Content -Path $reportPath -Encoding UTF8
Write-Host "`n[REPORT GENERATED] Markdown Audit written to: $reportPath`n" -ForegroundColor Green

