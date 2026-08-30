<#
.SYNOPSIS
    Install-VoltaireUnDailySchedule.ps1 - Windows Scheduled Task Provisioner for VoltaireUn Daily Poller.

.DESCRIPTION
    Registers a persistent, resilient Windows Scheduled Task on VoltaireUn to run
    Invoke-VoltaireUnDailyPoller.ps1 once per day at a configured time (default: 04:00 AM).

.PARAMETER DailyTime
    Time of day to execute the daily sync task (format: "HH:mm", 24-hour clock). Defaults to "04:00".

.PARAMETER Remove
    Removes the existing scheduled task if present.

.PARAMETER WhatIf
    Previews the scheduled task configuration without making modifications.

.EXAMPLE
    .\Install-VoltaireUnDailySchedule.ps1
    .\Install-VoltaireUnDailySchedule.ps1 -DailyTime "03:30"
    .\Install-VoltaireUnDailySchedule.ps1 -Remove
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$false)][string]$DailyTime = "04:00",
    [Parameter(Mandatory=$false)][switch]$Remove,
    [Parameter(Mandatory=$false)][switch]$WhatIf
)

$ErrorActionPreference = "Continue"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$taskName = "MediaStack-VoltaireUn-DailySync"
$scriptPath = Join-Path $PSScriptRoot "Invoke-VoltaireUnDailyPoller.ps1"
$logDir = Join-Path $PSScriptRoot "logs"
if (-not (Test-Path $logDir)) { New-Item -ItemType Directory -Force -Path $logDir | Out-Null }

Write-Host "`n================================================================================" -ForegroundColor DarkCyan
Write-Host "   V O L T A I R E U N   D A I L Y   T A S K   S C H E D U L E R" -ForegroundColor Cyan
Write-Host ("   Task Name: {0} | Scheduled Time: {1}" -f $taskName, $DailyTime) -ForegroundColor DarkGray
Write-Host "================================================================================" -ForegroundColor DarkCyan

if ($Remove) {
    Write-Host "`n[REMOVING SCHEDULED TASK]..." -ForegroundColor Yellow
    if ($WhatIf) {
        Write-Host "  [WHATIF] Would unregister task '$taskName'" -ForegroundColor DarkGray
    } else {
        Unregister-ScheduledTask -TaskName $taskName -Confirm:$false -ErrorAction SilentlyContinue
        Write-Host ("  [OK] Scheduled Task '{0}' removed successfully." -f $taskName) -ForegroundColor Green
    }
    exit 0
}

# Validate Target Script
if (-not (Test-Path $scriptPath)) {
    Write-Host ("  [ERROR] Target script not found: {0}" -f $scriptPath) -ForegroundColor Red
    exit 1
}

# Parse Trigger Time
try {
    $parsedTime = [DateTime]::ParseExact($DailyTime, "HH:mm", [System.Globalization.CultureInfo]::InvariantCulture)
} catch {
    Write-Host "  [WARN] Invalid time format '$DailyTime'. Defaulting to 04:00 AM." -ForegroundColor Yellow
    $parsedTime = (Get-Date).Date.AddHours(4)
}

$action = New-ScheduledTaskAction `
    -Execute "powershell.exe" `
    -Argument "-NoProfile -ExecutionPolicy Bypass -File `"$scriptPath`" -Once" `
    -WorkingDirectory $PSScriptRoot

$trigger = New-ScheduledTaskTrigger -Daily -At $parsedTime

$settings = New-ScheduledTaskSettingsSet `
    -AllowStartIfOnBatteries `
    -DontStopIfGoingOnBatteries `
    -StartWhenAvailable `
    -WakeToRun `
    -RestartCount 3 `
    -RestartInterval (New-TimeSpan -Minutes 15) `
    -ExecutionTimeLimit (New-TimeSpan -Hours 2)

if ($WhatIf) {
    Write-Host "`n[WHAT-IF PREVIEW]" -ForegroundColor Cyan
    Write-Host ("  Action: powershell.exe -NoProfile -ExecutionPolicy Bypass -File `"{0}`" -Once" -f $scriptPath) -ForegroundColor DarkGray
    Write-Host ("  Trigger: Daily at {0}" -f $parsedTime.ToString("HH:mm")) -ForegroundColor DarkGray
    Write-Host "  Settings: Wake to run, retry 3 times on failure, start when available." -ForegroundColor DarkGray
    exit 0
}

Write-Host "`n[REGISTERING SCHEDULED TASK]..." -ForegroundColor Yellow
try {
    # Unregister existing task if present
    Unregister-ScheduledTask -TaskName $taskName -Confirm:$false -ErrorAction SilentlyContinue

    Register-ScheduledTask `
        -TaskName $taskName `
        -Action $action `
        -Trigger $trigger `
        -Settings $settings `
        -Description "Autonomous daily update poller, database backup, and sync sentinel for MediaStack cluster on VoltaireUn." `
        -ErrorAction Stop | Out-Null

    Write-Host ("  [OK] Scheduled Task '{0}' successfully registered to run daily at {1}." -f $taskName, $parsedTime.ToString("HH:mm")) -ForegroundColor Green
} catch {
    Write-Host ("  [FAIL] Failed to register task: {0}" -f $_.Exception.Message) -ForegroundColor Red
    Write-Host "  Note: Run PowerShell as Administrator if permission was denied." -ForegroundColor Yellow
}

Write-Host "`n================================================================================" -ForegroundColor DarkCyan
Write-Host "     S C H E D U L E D   T A S K   I N S T A L L A T I O N   C O M P L E T E" -ForegroundColor Cyan
Write-Host "================================================================================`n" -ForegroundColor DarkCyan
