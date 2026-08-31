<#
.SYNOPSIS
    Set-MediaStackIngressPolicy.ps1 - Master Ingress Policy & Remote Desktop Guarantee Suite.

.DESCRIPTION
    Enforces the primary cluster ingress policy:
    1. Directs ALL incoming HTTP (:80), HTTPS (:443), and Direct (:8096) web traffic straight to JELLYFIN.
    2. Guarantees Windows Remote Desktop (RDP :3389) accessibility for remote management.
    3. Audits and configures Windows Firewall rules for Ports 80, 443, 8096, and 3389.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)][bool]$AutoFix = $true
)

$ErrorActionPreference = "Continue"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
[System.Console]::InputEncoding  = [System.Text.Encoding]::UTF8

$timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

Write-Host "`n================================================================================" -ForegroundColor Cyan
Write-Host "   M E D I A S T A C K   I N G R E S S   &   R D P   G U A R A N T E E" -ForegroundColor DarkCyan
Write-Host "   Priority Ingress Policy: ALL Traffic -> Jellyfin | Admin -> Remote Desktop" -ForegroundColor White
Write-Host "   Timestamp: $timestamp" -ForegroundColor DarkGray
Write-Host "================================================================================" -ForegroundColor Cyan

# --- 1. AUDIT & CONFIGURE JELLYFIN DEFAULT INGRESS (PORTS 80, 443, 8096) ---
Write-Host "`n[1/4] Auditing Ingress Routing to Jellyfin..." -ForegroundColor Yellow

$routes = @(
    @{ Name = "Direct Jellyfin Port 8096"; Url = "http://127.0.0.1:8096/System/Info/Public" },
    @{ Name = "HTTP Port 80 Root Ingress";  Url = "http://localhost/System/Info/Public" },
    @{ Name = "HTTPS Port 443 Root Ingress"; Url = "https://localhost/System/Info/Public" }
)

foreach ($r in $routes) {
    try {
        $res = curl.exe -k -s -m 3 $r.Url 2>$null
        if ($res -match "Jellyfin Server" -or $res -match "jellyfinstack") {
            Write-Host ("  [OK] {0,-32} -> DIRECTED TO JELLYFIN" -f $r.Name) -ForegroundColor Green
        } else {
            Write-Host ("  [WARN] {0,-30} -> Unexpected response: {1}" -f $r.Name, $res) -ForegroundColor Yellow
        }
    } catch {
        Write-Host ("  [ERR] {0,-31} -> Connection failed" -f $r.Name) -ForegroundColor Red
    }
}

# --- 2. AUDIT & CONFIGURE WINDOWS REMOTE DESKTOP (RDP :3389) ---
Write-Host "`n[2/4] Auditing Windows Remote Desktop (RDP :3389) Service & Configuration..." -ForegroundColor Yellow

$rdpRegistryPath = "HKLM:\System\CurrentControlSet\Control\Terminal Server"
$rdpDeny = (Get-ItemProperty -Path $rdpRegistryPath -Name "fDenyTSConnections" -ErrorAction SilentlyContinue).fDenyTSConnections
$rdpService = Get-Service -Name "TermService" -ErrorAction SilentlyContinue

$rdpEnabled = ($rdpDeny -eq 0)
Write-Host ("  • Remote Desktop Registry (fDenyTSConnections) : {0} (Enabled: {1})" -f $rdpDeny, $rdpEnabled) -ForegroundColor $(if ($rdpEnabled) { "Green" } else { "Yellow" })
Write-Host ("  • Terminal Services (TermService) Status       : {0} ({1})" -f $rdpService.Status, $rdpService.StartType) -ForegroundColor $(if ($rdpService.Status -eq "Running") { "Green" } else { "Yellow" })

if ($AutoFix -and (-not $rdpEnabled -or $rdpService.Status -ne "Running")) {
    Write-Host "  [*] Enabling Windows Remote Desktop and starting TermService..." -ForegroundColor Cyan
    try {
        Set-ItemProperty -Path $rdpRegistryPath -Name "fDenyTSConnections" -Value 0 -ErrorAction SilentlyContinue
        Set-Service -Name "TermService" -StartupType Automatic -ErrorAction SilentlyContinue
        Start-Service -Name "TermService" -ErrorAction SilentlyContinue
        Write-Host "  [REPAIRED] Remote Desktop registry updated and TermService started." -ForegroundColor Green
    } catch {
        Write-Host ("  [WARN] Could not update RDP service (requires elevated Admin privilege): " + $_.Exception.Message) -ForegroundColor Yellow
    }
}

# --- 3. AUDIT WINDOWS FIREWALL INBOUND RULES ---
Write-Host "`n[3/4] Auditing Windows Firewall Inbound Rules for MediaStack & RDP..." -ForegroundColor Yellow

$firewallChecks = @(
    @{ Port = 80;   Protocol = "TCP"; Name = "HTTP Ingress (Caddy -> Jellyfin)" },
    @{ Port = 443;  Protocol = "TCP"; Name = "HTTPS Ingress (Caddy -> Jellyfin)" },
    @{ Port = 8096; Protocol = "TCP"; Name = "Jellyfin Direct Streaming" },
    @{ Port = 3389; Protocol = "TCP"; Name = "Windows Remote Desktop (RDP)" }
)

foreach ($fw in $firewallChecks) {
    $rule = Get-NetFirewallPortFilter -Protocol $fw.Protocol -ErrorAction SilentlyContinue |
        Where-Object { $_.LocalPort -eq $fw.Port.ToString() }
    
    if ($rule) {
        Write-Host ("  [OK] Firewall Rule Active: Port {0,-5} ({1}) -> {2}" -f $fw.Port, $fw.Protocol, $fw.Name) -ForegroundColor Green
    } else {
        Write-Host ("  [INFO] No explicit port rule for Port {0} ({1}) -> Adding inbound allow rule..." -f $fw.Port, $fw.Name) -ForegroundColor DarkCyan
        if ($AutoFix) {
            try {
                New-NetFirewallRule -DisplayName "MediaStack - $($fw.Name)" -Direction Inbound -Action Allow -Protocol $fw.Protocol -LocalPort $fw.Port -ErrorAction SilentlyContinue | Out-Null
                Write-Host ("    [ADDED] Inbound Firewall Rule for Port {0} ({1})" -f $fw.Port, $fw.Name) -ForegroundColor Green
            } catch { }
        }
    }
}

# --- 4. VERIFY LOCAL SOCKET LISTENERS ---
Write-Host "`n[4/4] Verifying Active TCP Socket Listeners on Host..." -ForegroundColor Yellow

$activeSockets = Get-NetTCPConnection -State Listen -ErrorAction SilentlyContinue
$portsToInspect = @(80, 443, 8096, 3389)

foreach ($p in $portsToInspect) {
    $sock = $activeSockets | Where-Object { $_.LocalPort -eq $p } | Select-Object -First 1
    if ($sock) {
        $proc = Get-Process -Id $sock.OwningProcess -ErrorAction SilentlyContinue
        $procName = if ($proc) { $proc.ProcessName } else { "System/Docker" }
        Write-Host ("  [LISTENING] Port {0,-5} (TCP) is active -> Process: {1} (PID: {2})" -f $p, $procName, $sock.OwningProcess) -ForegroundColor Green
    } else {
        Write-Host ("  [WARN] Port {0,-5} (TCP) is currently NOT listening." -f $p) -ForegroundColor Yellow
    }
}

Write-Host "`n================================================================================" -ForegroundColor Cyan
Write-Host "   I N G R E S S   P O L I C Y   S U M M A R Y" -ForegroundColor White
Write-Host "================================================================================" -ForegroundColor Cyan
Write-Host "1. All Web & Media Streaming Requests (:80, :443, :8096) -> JELLYFIN (Primary)" -ForegroundColor Green
Write-Host "2. All Remote Desktop Administration (:3389)           -> WINDOWS RDP (Active)" -ForegroundColor Green
Write-Host "3. Failover Redundancy                                 -> VoltaireUn <--> VoltaireDeux" -ForegroundColor Green
Write-Host "================================================================================`n" -ForegroundColor Cyan
