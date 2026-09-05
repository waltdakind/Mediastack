<#
.SYNOPSIS
    Invoke-MediaStackTestSuite.ps1 - Master Launcher & Orchestrator for MediaStack Testing & Verification Suite.

.DESCRIPTION
    Unified master launcher for all diagnostic, connectivity, security, and verification test engines located in test-files/:
    1. Fleet Verification & Multi-Node Certification (Test-MediaStackFleetVerification.ps1)
    2. Fleet Connectivity & Authenticated REST API Probes (Test-MediaStackFleetConnectivity.ps1, Test-MediaStackApis.ps1)
    3. Network Infrastructure & MTU Diagnostics (Test-NetworkDiagnostics.ps1, Test-LocalNetworkSwitch.ps1)
    4. Ingress, Caddy Routing & Port Probing (Test-MediaStackProxyAndPorts.ps1, Test-ExternalRoutesAndDashboard.ps1, test_routes.ps1)
    5. SSL/TLS Viability & 4096-bit Certificate Audits (Test-MediaStackSslViability.ps1, Test-MediaStackNetworkAndSslAudit.ps1)
    6. Media Services & MusicBrainz Mirror Health (Test-MusicBrainzMirror.ps1)

.PARAMETER All
    Executes core verification sweep (Fleet, APIs, Network, SSL, Ingress).

.PARAMETER Category
    Filters execution to a specific category: Fleet, Network, Ingress, Security, Media.

.PARAMETER Test
    Executes a single test engine by name.

.PARAMETER NonInteractive
    Runs unattended without interactive prompts.

.PARAMETER Fast
    Runs quick liveness probes only, skipping deep latency and stress audits.

.EXAMPLE
    .\Invoke-MediaStackTestSuite.ps1 -All
    .\Invoke-MediaStackTestSuite.ps1 -Category Fleet
    .\Invoke-MediaStackTestSuite.ps1 -Category Security -NonInteractive
    .\Invoke-MediaStackTestSuite.ps1 -Test MediaStackApis
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)][switch]$All,
    [Parameter(Mandatory = $false)][string]$Category = "",
    [Parameter(Mandatory = $false)][string]$Test = "",
    [Parameter(Mandatory = $false)][switch]$NonInteractive,
    [Parameter(Mandatory = $false)][switch]$Fast
)

$ErrorActionPreference = "Continue"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
[System.Console]::InputEncoding  = [System.Text.Encoding]::UTF8

$timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
$fileTag = Get-Date -Format "yyyyMMdd_HHmmss"
$BaseDir = $PSScriptRoot
$TestDir = Join-Path $BaseDir "test-files"
$HandoffsDir = Join-Path $BaseDir "handoffs"

if (-not (Test-Path $HandoffsDir)) { New-Item -ItemType Directory -Force -Path $HandoffsDir | Out-Null }

$TestCatalog = [ordered]@{
    "FleetVerification" = @{ Script="Test-MediaStackFleetVerification.ps1"; Category="Fleet";    Name="Fleet Health & Certification Index"; Fast=$true }
    "FleetConnectivity" = @{ Script="Test-MediaStackFleetConnectivity.ps1"; Category="Fleet";    Name="Multi-Node LAN/WAN Connectivity"; Fast=$true }
    "MediaStackApis"    = @{ Script="Test-MediaStackApis.ps1";              Category="Fleet";    Name="REST API Auth & Interoperability"; Fast=$true }
    "NetworkDiagnostics"= @{ Script="Test-NetworkDiagnostics.ps1";          Category="Network";  Name="Deep Switch, MTU & Gateway Diagnostics"; Fast=$false }
    "LocalSwitch"       = @{ Script="Test-LocalNetworkSwitch.ps1";          Category="Network";  Name="Local Switch & Port Liveness"; Fast=$true }
    "FallbackPorts"     = @{ Script="Test-MediaStackFallbackPorts.ps1";     Category="Network";  Name="VoltaireDeux Port+1 Fallback Audit"; Fast=$true }
    "ProxyAndPorts"     = @{ Script="Test-MediaStackProxyAndPorts.ps1";     Category="Ingress";  Name="Proxy & Socket Port Health Probe"; Fast=$true }
    "ExternalRoutes"    = @{ Script="Test-ExternalRoutesAndDashboard.ps1";  Category="Ingress";  Name="External Domain & Dashboard Routing"; Fast=$true }
    "CertHealth"        = @{ Script="Test-ExternalConnectivityAndCertHealth.ps1"; Category="Ingress"; Name="External Cert Health & Route Ingress"; Fast=$true }
    "Routes"            = @{ Script="test_routes.ps1";                      Category="Ingress";  Name="Caddy Reverse Proxy L7 Health"; Fast=$true }
    "SslViability"      = @{ Script="Test-MediaStackSslViability.ps1";      Category="Security"; Name="4096-bit SSL/TLS Viability Engine"; Fast=$true }
    "NetworkSslAudit"   = @{ Script="Test-MediaStackNetworkAndSslAudit.ps1";Category="Security"; Name="Deep Network Proxy & SSL Port Review"; Fast=$false }
    "ProcessPortAudit"  = @{ Script="Test-MediaStackProcessPortAudit.ps1";  Category="Security"; Name="Process Port Isolation & Leak Audit"; Fast=$true }
    "MusicBrainzMirror" = @{ Script="Test-MusicBrainzMirror.ps1";           Category="Media";    Name="MusicBrainz Local Mirror (5001) Probe"; Fast=$true }
    "MoreChannels"      = @{ Script="Test-MoreChannels.ps1";                Category="Media";    Name="TVHeadend Extended Channels Audit"; Fast=$false }
    "TrueCrimeChannels" = @{ Script="Test-TrueCrimeChannels.ps1";           Category="Media";    Name="TVHeadend True Crime Channels Audit"; Fast=$false }
}

# Interactive Menu
if (-not $All -and -not $Category -and -not $Test -and -not $NonInteractive) {
    Clear-Host
    Write-Host "`n================================================================================" -ForegroundColor DarkCyan
    Write-Host "   M E D I A S T A C K   T E S T   &   V E R I F I C A T I O N   S U I T E" -ForegroundColor Cyan
    Write-Host "   Master Launcher for Diagnostics, Connectivity, Routing & Security Engines" -ForegroundColor DarkGray
    Write-Host "================================================================================" -ForegroundColor DarkCyan
    Write-Host ("   Host: {0} | Timestamp: {1} | Subdirectory: test-files/" -f $env:COMPUTERNAME, $timestamp) -ForegroundColor White
    Write-Host "--------------------------------------------------------------------------------" -ForegroundColor DarkGray
    Write-Host "   [1] Run Full Primary Fleet Verification (Scorecard, APIs & Connectivity)" -ForegroundColor Green
    Write-Host "   [2] Run Network Diagnostics & Local Switch Suite" -ForegroundColor Yellow
    Write-Host "   [3] Run Ingress, Caddy Routing & Port Audit Suite" -ForegroundColor Yellow
    Write-Host "   [4] Run SSL/TLS Viability & Security Isolation Suite" -ForegroundColor Yellow
    Write-Host "   [5] Run MusicBrainz Mirror & Live TV Media Probes" -ForegroundColor Yellow
    Write-Host "   [A] Execute Complete Master Test Sweep (All Categories)" -ForegroundColor Magenta
    Write-Host "   [0] Exit" -ForegroundColor DarkGray
    Write-Host "--------------------------------------------------------------------------------" -ForegroundColor DarkGray
    $choice = Read-Host "   Enter selection [1-5, A, 0]"

    switch ($choice.ToString().ToUpper()) {
        "1" { $Category = "Fleet" }
        "2" { $Category = "Network" }
        "3" { $Category = "Ingress" }
        "4" { $Category = "Security" }
        "5" { $Category = "Media" }
        "A" { $All = $true }
        default {
            Write-Host "`nExiting Test Suite.`n" -ForegroundColor DarkGray
            return
        }
    }
}

# Determine Selected Tests
$testsToRun = [ordered]@{}

if ($Test) {
    if ($TestCatalog.Contains($Test)) {
        $testsToRun[$Test] = $TestCatalog[$Test]
    } else {
        $match = $TestCatalog.Keys | Where-Object { $_ -like "*$Test*" -or $TestCatalog[$_].Script -like "*$Test*" } | Select-Object -First 1
        if ($match) {
            $testsToRun[$match] = $TestCatalog[$match]
        } else {
            Write-Error "Test '$Test' not found in catalog."
            return
        }
    }
} elseif ($Category) {
    foreach ($k in $TestCatalog.Keys) {
        if ($TestCatalog[$k].Category -eq $Category) {
            if (-not $Fast -or $TestCatalog[$k].Fast) {
                $testsToRun[$k] = $TestCatalog[$k]
            }
        }
    }
} elseif ($All) {
    foreach ($k in $TestCatalog.Keys) {
        if (-not $Fast -or $TestCatalog[$k].Fast) {
            $testsToRun[$k] = $TestCatalog[$k]
        }
    }
} else {
    # Default non-interactive: Fleet verification
    $testsToRun["FleetVerification"] = $TestCatalog["FleetVerification"]
    $testsToRun["FleetConnectivity"] = $TestCatalog["FleetConnectivity"]
    $testsToRun["MediaStackApis"]    = $TestCatalog["MediaStackApis"]
}

$modeStr = if ($Fast) { "Fast" } else { "Comprehensive" }
Write-Host "`n================================================================================" -ForegroundColor Cyan
Write-Host "   E X E C U T I N G   T E S T   S U I T E" -ForegroundColor DarkCyan
Write-Host ("   Scope: {0} test(s) selected | Mode: {1}" -f $testsToRun.Count, $modeStr) -ForegroundColor White
Write-Host "================================================================================" -ForegroundColor Cyan

$results = @()

foreach ($tKey in $testsToRun.Keys) {
    $info = $testsToRun[$tKey]
    $scriptPath = Join-Path $TestDir $info.Script
    
    if (-not (Test-Path $scriptPath)) {
        Write-Host ("`n[-] Script not found: {0}" -f $info.Script) -ForegroundColor Red
        $results += [PSCustomObject]@{ Test=$tKey; Category=$info.Category; Status="MISSING"; Elapsed="0.0s"; Name=$info.Name }
        continue
    }

    Write-Host ("`n--------------------------------------------------------------------------------") -ForegroundColor DarkGray
    Write-Host ("[*] Launching: {0} ({1})" -f $info.Name, $info.Script) -ForegroundColor Yellow
    Write-Host ("--------------------------------------------------------------------------------") -ForegroundColor DarkGray

    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    $status = "PASS"
    try {
        & $scriptPath
        $sw.Stop()
    } catch {
        $sw.Stop()
        $status = "FAIL"
        Write-Host ("  [ERROR] Execution failed: $_") -ForegroundColor Red
    }

    $elapsedStr = "{0:N1}s" -f $sw.Elapsed.TotalSeconds
    $results += [PSCustomObject]@{
        Test     = $tKey
        Category = $info.Category
        Status   = $status
        Elapsed  = $elapsedStr
        Name     = $info.Name
    }
}

# Display Results Scorecard
Write-Host "`n================================================================================" -ForegroundColor DarkCyan
Write-Host "   T E S T   S U I T E   R E S U L T S" -ForegroundColor Cyan
Write-Host "================================================================================" -ForegroundColor DarkCyan
Write-Host "TEST               | CATEGORY   | STATUS     | ELAPSED  | NAME" -ForegroundColor White
Write-Host "--------------------------------------------------------------------------------" -ForegroundColor DarkGray

foreach ($r in $results) {
    $c = if ($r.Status -eq "PASS") { "Green" } else { "Red" }
    Write-Host ("{0,-18} | {1,-10} | " -f $r.Test, $r.Category) -NoNewline -ForegroundColor White
    Write-Host ("{0,-10}" -f $r.Status) -NoNewline -ForegroundColor $c
    Write-Host (" | {0,-8} | {1}" -f $r.Elapsed, $r.Name) -ForegroundColor White
}

# Export Markdown Report
$reportFile = Join-Path $HandoffsDir "MediaStack_Test_Suite_Report_$fileTag.md"
$rep = @"
# MediaStack Master Test & Verification Suite Execution Report

| Parameter | Value |
| :--- | :--- |
| **Execution Host** | $($env:COMPUTERNAME) |
| **Audit Timestamp** | $timestamp |
| **Subdirectory** | \test-files |
| **Tests Executed** | $($results.Count) |
| **Pass Count** | $(($results | Where-Object { $_.Status -eq 'PASS' }).Count) |
| **Fail Count** | $(($results | Where-Object { $_.Status -ne 'PASS' }).Count) |

## Test Results Breakdown

| Test Engine | Category | Status | Elapsed | Description |
| :--- | :--- | :--- | :--- | :--- |
$($results | ForEach-Object { "| **$($_.Test)** | $($_.Category) | **$($_.Status)** | $($_.Elapsed) | $($_.Name) |" } | Out-String)

---
*Generated by Invoke-MediaStackTestSuite.ps1.*
"@

Set-Content -Path $reportFile -Value $rep -Encoding UTF8
Write-Host "`n================================================================================" -ForegroundColor Cyan
Write-Host ("   [COMPLETE] Test Suite Finished. Full Report: {0}" -f $reportFile) -ForegroundColor Green
Write-Host "================================================================================`n" -ForegroundColor Cyan
