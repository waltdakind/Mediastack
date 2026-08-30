$ErrorActionPreference = "Stop"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
[System.Console]::InputEncoding  = [System.Text.Encoding]::UTF8
$PSDefaultParameterValues['Out-File:Encoding']   = 'utf8'
$PSDefaultParameterValues['Set-Content:Encoding'] = 'utf8'

$global:FailureCounts = @{}
$global:GracePeriods = @{}

function Invoke-Autoheal {
    param([string]$Container, [string]$Reason)

    $HandoffsDir = "$PSScriptRoot\handoffs"
    if (-not (Test-Path $HandoffsDir)) { New-Item -ItemType Directory -Force -Path $HandoffsDir | Out-Null }

    $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
    $filename  = "$HandoffsDir\AI_Handoff_${Container}_${timestamp}.md"

    Write-Host "  [AUTOHEAL TRIGGERED] Restoring $Container..." -ForegroundColor Red

    # ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ 1. Docker Inspect (raw JSON) ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬
    $inspectJson  = cmd.exe /c "docker inspect $Container 2>&1"
    $inspectObj   = $inspectJson | ConvertFrom-Json -ErrorAction SilentlyContinue

    # ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ 2. Process tree at moment of failure ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬
    $processTree  = cmd.exe /c "docker top $Container 2>&1"

    # ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ 3. Recent logs (last 150 lines, stderr merged) ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬
    $recentLogs   = cmd.exe /c "docker logs --tail 150 --timestamps $Container 2>&1"

    # ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ 4. Environment variables ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬
    $envVars   = @()
    $warnings  = @()
    $hasPUID   = $false
    $hasPGID   = $false
    $hasTZ     = $false

    if ($inspectObj) {
        $rawEnv = $inspectObj[0].Config.Env
        foreach ($e in $rawEnv) {
            $kv = $e -split "=", 2
            $envVars += [PSCustomObject]@{ Key = $kv[0]; Value = if ($kv.Count -gt 1) { $kv[1] } else { "" } }
            if ($kv[0] -eq "PUID") { $hasPUID = $true }
            if ($kv[0] -eq "PGID") { $hasPGID = $true }
            if ($kv[0] -eq "TZ")   { $hasTZ   = $true }
        }
    }

    $envTable = "| Variable | Value |`n|----------|-------|`n"
    foreach ($e in $envVars) { $envTable += "| ``$($e.Key)`` | ``$($e.Value)`` |`n" }

    if (-not $hasPUID) { $warnings += "[WARN] **PUID not set** - container may run as root, causing permission issues on host volumes." }
    if (-not $hasPGID) { $warnings += "[WARN] **PGID not set** - container may run as root, causing permission issues on host volumes." }
    if (-not $hasTZ)   { $warnings += "[WARN] **TZ (Timezone) not set** - scheduled tasks and EPG timestamps may be incorrect." }

    # ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ 5. Volume / config path discovery ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬
    $configHostPath = $null
    if ($inspectObj) {
        $mounts = $inspectObj[0].Mounts
        foreach ($m in $mounts) {
            if ($m.Destination -match "^(/config|/app/config|/data)") { $configHostPath = $m.Source; break }
        }
    }

    $volumeTree    = "(no /config mount found)"
    $corruptFiles  = @()
    $configDumps   = ""

    if ($configHostPath -and (Test-Path $configHostPath)) {
        $volumeTree = (Get-ChildItem -Path $configHostPath -Recurse -Depth 3 -ErrorAction SilentlyContinue |
            Select-Object @{N='Path';E={$_.FullName.Replace($configHostPath,'').TrimStart('\/')}},
                          @{N='Size';E={if($_.PSIsContainer){"<DIR>"}else{"$($_.Length) bytes"}}} |
            Format-Table -AutoSize | Out-String).Trim()

        # Zero-byte critical file scan
        $criticalExts = @("*.db","*.sqlite","*.xml","*.json","*.ini","*.conf")
        foreach ($ext in $criticalExts) {
            Get-ChildItem -Path $configHostPath -Recurse -Filter $ext -ErrorAction SilentlyContinue |
                Where-Object { $_.Length -eq 0 } |
                ForEach-Object { $corruptFiles += $_.FullName }
        }

        # Config file dump ÃƒÂ¢Ã¢â€šÂ¬Ã¢â‚¬Â known filenames across all apps
        $knownConfigs = @(
            "settings.json",    # Jellyseerr
            "config.xml",       # Radarr, Sonarr, Jackett, Transmission
            "system.xml",       # Jellyfin
            "database.xml",     # Jellyfin
            "network.xml",      # Jellyfin
            "encoding.xml",     # Jellyfin
            "logging.default.json", # Jellyfin
            "prowlarr.db",      # Prowlarr (existence only)
            "bazarr.db"         # Bazarr (existence only)
        )

        foreach ($cfgName in $knownConfigs) {
            $found = Get-ChildItem -Path $configHostPath -Recurse -Filter $cfgName -ErrorAction SilentlyContinue | Select-Object -First 1
            if ($found -and $found.Length -gt 0) {
                $ext = $found.Extension.ToLower()
                $lang = switch ($ext) { ".json" { "json" } ".xml" { "xml" } default { "text" } }
                $preview = (Get-Content $found.FullName -TotalCount 120 -ErrorAction SilentlyContinue) -join "`n"
                $configDumps += @"

### ``$($found.Name)``
> Path: ``$($found.FullName)``
> Size: $($found.Length) bytes | Last Modified: $($found.LastWriteTime)

``````$lang
$preview
``````

"@
            }
        }

        if (-not $configDumps) { $configDumps = "*No recognizable configuration files found at this path.*" }
    }

    # ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ 6. Corruption warnings block ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬
    $corruptBlock = ""
    if ($corruptFiles.Count -gt 0) {
        $corruptBlock = @"
## ÃƒÂ°Ã…Â¸Ã…Â¡Ã‚Â¨ DATA CORRUPTION DETECTED

> [!CAUTION]
> The following files are **0 bytes** and are likely corrupt. This is the most common cause of startup failures (e.g., SQLite migration errors). **DO NOT restart without addressing these first.**

"@
        foreach ($f in $corruptFiles) { $corruptBlock += "- ``$f```n" }
        $corruptBlock += @"

### Recommended Fix
```powershell
# Stop the container, delete the corrupt file(s), then restart.
# The app will regenerate a fresh database on next boot.
docker stop $Container
Remove-Item "<path_to_corrupt_file>" -Force
docker start $Container
```
"@
    }

    # ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ 7. Best-practice warnings block ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬
    $warningsBlock = ""
    if ($warnings.Count -gt 0) {
        $warningsBlock = "## [WARN] Best Practice Violations`n`n"
        foreach ($w in $warnings) { $warningsBlock += "- $w`n" }
    }

    # ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ 8. Assemble the full handoff document ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬
    Set-Content -Path $filename -Encoding UTF8 -Value @"
# ÃƒÂ°Ã…Â¸Ã‚Â¤Ã¢â‚¬â€œ AI Autoheal Handoff: ``$Container``

| Field            | Value |
|------------------|-------|
| **Container**    | ``$Container`` |
| **Timestamp**    | $(Get-Date -Format "yyyy-MM-dd HH:mm:ss (zzz)") |
| **Trigger**      | $Reason |
| **Handoff File** | ``$filename`` |
| **Config Path**  | ``$(if ($configHostPath) { $configHostPath } else { "N/A" })`` |

---

$corruptBlock
$warningsBlock

---

## ÃƒÂ°Ã…Â¸Ã¢â‚¬Å“Ã¢â‚¬Â¹ Environment Variables

$envTable

---

## ÃƒÂ°Ã…Â¸Ã¢â‚¬ÂÃ‚Â Process Tree at Time of Failure

```text
$processTree
```

---

## ÃƒÂ°Ã…Â¸Ã¢â‚¬Å“Ã‚Â Volume / Config Directory Tree

> Host path mapped to ``/config`` inside the container (max 3 levels deep).

```text
$volumeTree
```

---

## ÃƒÂ¢Ã…Â¡Ã¢â€žÂ¢ÃƒÂ¯Ã‚Â¸Ã‚Â Configuration Files

$configDumps

---

## ÃƒÂ°Ã…Â¸Ã¢â‚¬Å“Ã…â€œ Recent Logs (last 150 lines with timestamps)

```text
$recentLogs
```

---

## ÃƒÂ°Ã…Â¸Ã‚ÂÃ‚Â³ Full Docker Inspect

```json
$inspectJson
```

---

*This handoff was automatically generated by the MediaStack Autohealer.*
*To assist with this failure, paste this entire file into an AI assistant chat.*
"@

    # ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ 9. Restart & grace period ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬
    docker restart $Container 2>&1 | Out-Null
    $global:GracePeriods[$Container] = (Get-Date).AddSeconds(60)
    $global:FailureCounts[$Container] = 0

    Write-Host "  [HANDOFF CREATED] $filename" -ForegroundColor Magenta
}


function Test-Routes {
    param([switch]$Silent)
    
    if (-not $Silent) {
        Write-Host "`n--- Route Verification ---" -ForegroundColor Cyan
    }
    
    $routes = @(
        @{ Route="ordinateur.local"; Container="caddy"; Path="" },
        @{ Route="jellyfin.ordinateur.local"; Container="jellyfin"; Path="" },
        @{ Route="radarr.ordinateur.local"; Container="radarr"; Path="/ping" },
        @{ Route="sonarr.ordinateur.local"; Container="sonarr"; Path="/ping" },
        @{ Route="jellyseerr.ordinateur.local"; Container="jellyseerr"; Path="" },
        @{ Route="prowlarr.ordinateur.local"; Container="prowlarr"; Path="/ping" },
        @{ Route="bazarr.ordinateur.local"; Container="bazarr"; Path="" },
        @{ Route="transmission.ordinateur.local"; Container="transmission"; Path="" },
        @{ Route="tvheadend.ordinateur.local"; Container="tvheadend"; Path="" },
        @{ Route="hdhomerun.ordinateur.local"; Container="tvheadend"; Path="" },
        @{ Route="db.ordinateur.local"; Container="mediastack-db"; Path="" },
        @{ Route="node.ordinateur.local"; Container="node"; Path="" }
    )
    
    foreach ($r in $routes) {
        $route = $r.Route
        $container = $r.Container
        $failed = $false
        $reason = ""
        $statusCode = ""
        
        try {
            $path = if ($r.Path) { $r.Path } else { "/" }
            $curlOutput = curl.exe -s -o NUL -w "%{http_code}" --max-time 3 -H "Host: $route" "http://localhost:80$path"
            $statusCode = [int]$curlOutput
            
            if ($statusCode -eq 000 -or $statusCode -eq 0) {
                # Connection refused
                if (-not $Silent) { Write-Host "  [FAIL] http://$route failed to connect" -ForegroundColor Red }
                $failed = $true
                $reason = "Connection refused or timed out"
                $statusCode = "FAIL"
            } elseif ($statusCode -ge 500) {
                if (-not $Silent) { Write-Host "  [WARN] http://$route backend not ready ($statusCode)" -ForegroundColor Yellow }
                $failed = $true
                $reason = "Proxy returned $statusCode"
            } else {
                if (-not $Silent) { Write-Host "  [OK] http://$route is responding ($statusCode)" -ForegroundColor Green }
            }
        } catch {
            if (-not $Silent) { Write-Host "  [FAIL] http://$route failed to execute test" -ForegroundColor Red }
            $failed = $true
            $reason = "Test execution failed"
            $statusCode = "ERROR"
        }
        
        # Only process autoheal logic if we are in silent (monitor) mode
        if ($Silent) {
            # Display inline status
            if ($failed) {
                Write-Host "  [WARN] http://$route ($statusCode)" -ForegroundColor Yellow
            } else {
                Write-Host "  [OK] http://$route ($statusCode)" -ForegroundColor Green
            }
            
            # Autoheal logic
            if ($global:GracePeriods.ContainsKey($container) -and $global:GracePeriods[$container] -gt (Get-Date)) {
                # In grace period, ignore failures
            } elseif ($failed) {
                if (-not $global:FailureCounts.ContainsKey($container)) { $global:FailureCounts[$container] = 0 }
                $global:FailureCounts[$container]++
                
                # Increased from 6 to 15 to give watchtower more time to resolve/pull images
                if ($global:FailureCounts[$container] -ge 15) {
                    Invoke-Autoheal -Container $container -Reason $reason
                }
            } else {
                $global:FailureCounts[$container] = 0
            }
        }
    }
}

function Test-Startup {
    Write-Host "`nWaiting for containers to start..." -ForegroundColor Yellow
    Start-Sleep -Seconds 10
    $containers = docker ps --format '{{.Names}}'
    
    if (-not $containers) {
        Write-Host "No containers appear to be running." -ForegroundColor Red
        return
    }

    Write-Host "`n--- Container Startup Verification ---" -ForegroundColor Cyan
    foreach ($c in $containers) {
        $status = docker inspect -f '{{.State.Status}}' $c
        $health = docker inspect -f '{{if .State.Health}}{{.State.Health.Status}}{{else}}NoHealthCheck{{end}}' $c 2>$null
        
        if ($health -eq "healthy" -or $status -eq "running") {
            Write-Host "  [OK] $c is running ($status, $health)" -ForegroundColor Green
        } else {
            Write-Host "  [WARN] $c may have issues ($status, $health)" -ForegroundColor Yellow
        }
    }

    Test-Routes -Silent:$false
}

function Show-HealthMonitor {
    $monitoring = $true
    
    $global:FailureCounts.Clear()
    $global:GracePeriods.Clear()
    
    while ($monitoring) {
        Clear-Host
        Write-Host "=========================================" -ForegroundColor DarkCyan
        Write-Host "       L I V E   H E A L T H   M O N I T O R" -ForegroundColor Cyan
        Write-Host "       Press 'Q' to quit and return to Menu" -ForegroundColor DarkGray
        Write-Host "=========================================" -ForegroundColor DarkCyan
        
        docker ps --format 'table {{.Names}}`t{{.Status}}`t{{.Ports}}' | Write-Host
        Write-Host "`n--- CPU / MEMORY USAGE ---" -ForegroundColor Cyan
        docker stats --no-stream --format 'table {{.Name}}`t{{.CPUPerc}}`t{{.MemUsage}}`t{{.MemPerc}}' | Write-Host
        
        Write-Host "`n--- ACTIVE ROUTE AUTOHEALER ---" -ForegroundColor Cyan
        Test-Routes -Silent:$true
        
        if ($Host.UI.RawUI.KeyAvailable) {
            $key = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
            if ($key.Character -match 'q|Q') {
                $monitoring = $false
            }
        }
        Start-Sleep -Seconds 60
    }
}

function New-SystemsReport {
    Write-Host "Gathering systems report for AI handoff..." -ForegroundColor Cyan
    $HandoffsDir = "$PSScriptRoot\handoffs"
    if (-not (Test-Path $HandoffsDir)) { New-Item -ItemType Directory -Force -Path $HandoffsDir | Out-Null }
    
    $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
    $filename = "$HandoffsDir\AI_SystemsReport_$timestamp.md"
    
    $dockerPs = cmd.exe /c "docker ps -a 2>&1"
    $dockerStats = cmd.exe /c "docker stats --no-stream 2>&1"
    $diskSpace = Get-Volume | Select-Object DriveLetter, FileSystemLabel, @{N='SizeGB';E={[math]::Round($_.Size / 1GB, 2)}}, @{N='FreeGB';E={[math]::Round($_.SizeRemaining / 1GB, 2)}} | Format-Table -AutoSize | Out-String
    
    $routesTest = ""
    # Capture route tests silently
    $routesTest = $(Test-Routes -Silent) | Out-String
    
    Set-Content -Path $filename -Encoding UTF8 -Value @"
# Ã°Å¸Â¤â€“ AI Systems Report Handoff

| Field | Value |
|-------|-------|
| **Timestamp** | $(Get-Date -Format "yyyy-MM-dd HH:mm:ss (zzz)") |
| **System** | Windows MediaStack HA |

---

## Ã°Å¸ Â³ Docker Containers
```text
$dockerPs
```

---

## Ã°Å¸â€œÅ  Resource Usage (Docker Stats)
```text
$dockerStats
```

---

## Ã°Å¸â€™Â¾ Disk Space
```text
$diskSpace
```

---

## Ã°Å¸Å’  Routes Test
```text
$routesTest
```
"@
    Write-Host "  [REPORT CREATED] $filename" -ForegroundColor Magenta
}

function New-Directories {
    Write-Host "Creating local volume directories..." -ForegroundColor Yellow;
    $ScriptDir = "$PSScriptRoot";
    $dirs = @(
        "config\jellyfin", "config\caddy_data", "config\caddy_config",
        "config\sonarr", "config\radarr", "config\bazarr", "config\jackett",
        "config\transmission", "config\jellyseerr", "config\tvheadend",
        "certs", "dashboard",
        "downloads", "data\buffer", "handoffs", "db-backup"
    );

    foreach ($dir in $dirs) {
        $path = Join-Path -Path $ScriptDir -ChildPath $dir;
        if (-not (Test-Path -Path $path)) {
            New-Item -ItemType Directory -Force -Path $path | Out-Null;
            Write-Host "  -> Created: $dir";
        }
    }
}

function Initialize-Environment {
    Write-Host "Ensuring base directory exists at $PSScriptRoot" -ForegroundColor Cyan;
    $ScriptDir = "$PSScriptRoot";
    
    if (-not (Test-Path $ScriptDir)) { New-Item -ItemType Directory -Force -Path $ScriptDir | Out-Null }
    
    $EnvFile = Join-Path $ScriptDir ".env"
    if (-not (Test-Path $EnvFile)) {
        Write-Host "Creating default .env file..." -ForegroundColor Cyan
        $envContent = @"
PUID=1000
PGID=1000
TZ=America/New_York
MOVIES_DIR=$(Split-Path -Parent $PSScriptRoot)\Videos
MUSIC_DIR=$(Split-Path -Parent $PSScriptRoot)\Music
TV_DIR=$PSScriptRoot\downloads\watch
"@
        Set-Content -Path $EnvFile -Value $envContent
    }
    
    Write-Host "Checking for Docker Compose..." -ForegroundColor Yellow;
    if (-not (Get-Command "docker" -ErrorAction SilentlyContinue)) {
        Write-Host "Docker is not installed or not in PATH!" -ForegroundColor Red
        return
    }
    $dcVersion = docker compose version
    Write-Host "Found Docker Compose: $dcVersion" -ForegroundColor Green

    Write-Host "Generating Caddyfile for Failover/Proxy..." -ForegroundColor Cyan;
    
    $CaddyFile = Join-Path $ScriptDir "Caddyfile"
    $caddyContent = @'
http://ordinateur.local {
    reverse_proxy homepage:3000
}

http://jellyfin.ordinateur.local {
    reverse_proxy jellyfin:8096
}

http://radarr.ordinateur.local {
    reverse_proxy radarr:7878
}

http://sonarr.ordinateur.local {
    reverse_proxy sonarr:8989
}

http://jellyseerr.ordinateur.local {
    reverse_proxy jellyseerr:5055
}

http://prowlarr.ordinateur.local {
    reverse_proxy prowlarr:9696
}

http://bazarr.ordinateur.local {
    reverse_proxy bazarr:6767
}

http://transmission.ordinateur.local {
    reverse_proxy transmission:9091 {
        header_up X-Transmission-Session-Id {http.request.header.X-Transmission-Session-Id}
    }
}

http://tvheadend.ordinateur.local {
    reverse_proxy tvheadend:9981
}

http://hdhomerun.ordinateur.local {
    reverse_proxy 192.168.4.45:80
}

http://db.ordinateur.local {
    reverse_proxy mediastack-db:8080
}

'@;
    Set-Content -Path $CaddyFile -Value $caddyContent -Encoding UTF8;

    Write-Host "Generating HA docker-compose.yml..." -ForegroundColor Cyan;
    
    $ComposeFile = Join-Path $ScriptDir "docker-compose.yml"
    $composeContent = @'
services:

  api-gateway:
    build: ./api-gateway
    container_name: api-gateway
    ports:
      - "3000:3000"
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
    restart: unless-stopped
    labels:
      - "autoheal=true"

  caddy:
    image: caddy:latest
    container_name: caddy
    ports:
      - "80:80"
      - "443:443"
      - "8096:8096"
      - "8080:8080"
    volumes:
      - ./Caddyfile:/etc/caddy/Caddyfile
      - ./config/caddy_data:/data
      - ./config/caddy_config:/config
      - ./dashboard:/var/www/dashboard
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:80"]
      interval: 30s
      timeout: 10s
      retries: 3
    labels:
      - "autoheal=true"

  jellyfin:
    image: lscr.io/linuxserver/jellyfin:latest
    container_name: jellyfin
    environment:
      - PUID=${PUID:-1000}
      - PGID=${PGID:-1000}
      - TZ=${TZ:-America/New_York}
    volumes:
      - ./config/jellyfin:/config
      - $(Split-Path -Parent $PSScriptRoot):/data
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8096/health"]
      interval: 30s
      timeout: 10s
      retries: 3
    labels:
      - "autoheal=true"

  jellyseerr:
    image: ghcr.io/seerr-team/seerr:v3.4.1
    container_name: jellyseerr
    environment:
      - TZ=${TZ:-America/New_York}
    volumes:
      - ./config/jellyseerr:/app/config
    restart: unless-stopped
    labels:
      - "autoheal=true"

  sonarr:
    image: lscr.io/linuxserver/sonarr:latest
    container_name: sonarr
    environment:
      - PUID=${PUID:-1000}
      - PGID=${PGID:-1000}
      - TZ=${TZ:-America/New_York}
    volumes:
      - ./config/sonarr:/config
      - $(Split-Path -Parent $PSScriptRoot):/data
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8989/ping"]
      interval: 30s
      timeout: 10s
      retries: 3
    labels:
      - "autoheal=true"

  radarr:
    image: lscr.io/linuxserver/radarr:latest
    container_name: radarr
    environment:
      - PUID=${PUID:-1000}
      - PGID=${PGID:-1000}
      - TZ=${TZ:-America/New_York}
    volumes:
      - ./config/radarr:/config
      - $(Split-Path -Parent $PSScriptRoot):/data
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:7878/ping"]
      interval: 30s
      timeout: 10s
      retries: 3
    labels:
      - "autoheal=true"

  prowlarr:
    image: lscr.io/linuxserver/prowlarr:latest
    container_name: prowlarr
    environment:
      - PUID=${PUID:-1000}
      - PGID=${PGID:-1000}
      - TZ=${TZ:-America/New_York}
    volumes:
      - ./config/prowlarr:/config
    restart: unless-stopped
    labels:
      - "autoheal=true"

  bazarr:
    image: lscr.io/linuxserver/bazarr:latest
    container_name: bazarr
    environment:
      - PUID=${PUID:-1000}
      - PGID=${PGID:-1000}
      - TZ=${TZ:-America/New_York}
    volumes:
      - ./config/bazarr:/config
      - $(Split-Path -Parent $PSScriptRoot):/data
    restart: unless-stopped
    labels:
      - "autoheal=true"

  transmission:
    image: lscr.io/linuxserver/transmission:latest
    container_name: transmission
    environment:
      - PUID=${PUID:-1000}
      - PGID=${PGID:-1000}
      - TZ=${TZ:-America/New_York}
    volumes:
      - ./transmission/config:/config
      - $(Split-Path -Parent $PSScriptRoot):/data
    ports:
      - 51413:51413
      - 51413:51413/udp
    restart: unless-stopped
    labels:
      - "autoheal=true"

  mediastack-db:
    image: coleifer/sqlite-web
    container_name: mediastack-db
    environment:
      - PUID=${PUID:-1000}
      - PGID=${PGID:-1000}
      - TZ=${TZ:-America/New_York}
      - SQLITE_DATABASE=/config/mediastack_backup.db
    volumes:
      - ./db-backup:/config
      - ./config:/mediastack/config:ro
    restart: unless-stopped

  tvheadend:
    image: lscr.io/linuxserver/tvheadend:latest
    container_name: tvheadend
    environment:
      - PUID=${PUID:-1000}
      - PGID=${PGID:-1000}
      - TZ=${TZ:-America/New_York}
    volumes:
      - ./config/tvheadend:/config
      - $(Split-Path -Parent $PSScriptRoot):/data
    restart: unless-stopped
    labels:
      - "autoheal=true"

  diun:
    image: crazymax/diun:latest
    container_name: diun
    command: serve
    volumes:
      - ./config/diun:/data
      - /var/run/docker.sock:/var/run/docker.sock
    environment:
      - TZ=${TZ:-America/New_York}
      - LOG_LEVEL=info
      - LOG_JSON=false
      - DIUN_WATCH_WORKERS=20
      - DIUN_WATCH_SCHEDULE=0 0 * * *
      - DIUN_PROVIDERS_DOCKER=true
      - DIUN_PROVIDERS_DOCKER_WATCHBYDEFAULT=true
    restart: unless-stopped

  homepage:
    image: ghcr.io/gethomepage/homepage:latest
    container_name: homepage
    environment:
      - PUID=${PUID:-1000}
      - PGID=${PGID:-1000}
      - TZ=${TZ:-America/New_York}
    volumes:
      - ./config/homepage:/app/config
      - /var/run/docker.sock:/var/run/docker.sock:ro
    restart: unless-stopped
    labels:
      - "autoheal=true"

'@;
    Set-Content -Path $ComposeFile -Value $composeContent -Encoding UTF8;
}

$ScriptDir = "$PSScriptRoot"
Set-Location -Path $ScriptDir

# Always initialize on run to ensure files exist
Initialize-Environment

while ($true) {
    Write-Host ""
    Write-Host "=== High-Availability Media Stack =" -ForegroundColor Cyan
    Write-Host "Working Directory: $ScriptDir"
    Write-Host "1. Install / Start Stack"
    Write-Host "2. Start Stack (No re-init)"
    Write-Host "3. Stop Stack"
    Write-Host "4. Clean Up Orphan Containers"
    Write-Host "5. Create Backup to Public Folders"
    Write-Host "6. Full DB Backup to Private DB"
    Write-Host "7. Restore Backup"
    Write-Host "8. Check Caddy Routing Logs"
    Write-Host "9. Live Health Monitor (w/ Autoheal)"
    Write-Host "10. Generate AI Systems Report Handoff"
    Write-Host "11. Exit"
    Write-Host "==================================="
    
    $choice = Read-Host "Select an option"
    
    switch ($choice) {
        '1' {
            New-Directories;
            try {
                Set-Location -Path $ScriptDir;
                docker compose up -d;
                Write-Host "Stack booted successfully!" -ForegroundColor Green;
                Test-Startup;
            } catch {
                Write-Host "Failed to start. $_" -ForegroundColor Red
            }
        }
        '2' {
            try {
                Set-Location -Path $ScriptDir;
                docker compose up -d;
                Write-Host "Stack booted successfully (No re-init)!" -ForegroundColor Green;
                Test-Startup;
            } catch {
                Write-Host "Failed to start. $_" -ForegroundColor Red
            }
        }
        '3' { Set-Location -Path $ScriptDir; docker compose down; Write-Host "Stack Stopped!" -ForegroundColor Yellow }
        '4' {
            Write-Host "Cleaning up orphan containers..." -ForegroundColor Yellow
            Set-Location -Path $ScriptDir
            docker compose down --remove-orphans
            Write-Host "Restarting stack..." -ForegroundColor Yellow
            docker compose up -d
            Write-Host "Stack restarted without orphans!" -ForegroundColor Green
        }
        '5' { 
            Write-Host "Stopping apps to release DB locks..." -ForegroundColor Yellow
            docker compose stop jellyfin sonarr radarr jellyseerr bazarr transmission
            Write-Host "--- Creating DB Backups ---" -ForegroundColor Cyan
            docker exec mediastack-db sh /config/backup.sh
            Write-Host "--- Zipping Config Folders ---" -ForegroundColor Cyan
            Write-Host "Stopping remaining stack..." -ForegroundColor Yellow
            docker compose down
            $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
            $backupFile = Join-Path $ScriptDir "handoffs\ConfigBackup_$timestamp.zip"
            Compress-Archive -Path "config", "transmission", "db-backup", "Caddyfile", "docker-compose.yml" -DestinationPath $backupFile -Force
            Write-Host "Backup created: $backupFile" -ForegroundColor Green
            Write-Host "Restarting stack..." -ForegroundColor Yellow
            docker compose up -d
        }
        '6' {
            Write-Host "--- Creating Full DB Backup to Private DB ---" -ForegroundColor Cyan
            Write-Host "Stopping apps to release DB locks..." -ForegroundColor Yellow
            docker compose stop jellyfin sonarr radarr jellyseerr bazarr transmission
            # Backup Jellyfin DB
            docker exec mediastack-db sqlite3 /mediastack/config/jellyfin/data/data/jellyfin.db ".backup '/config/jellyfin_backup.db'"
            # Backup Radarr DB
            docker exec mediastack-db sqlite3 /mediastack/config/radarr/radarr.db ".backup '/config/radarr_backup.db'"
            # Backup Sonarr DB
            docker exec mediastack-db sqlite3 /mediastack/config/sonarr/sonarr.db ".backup '/config/sonarr_backup.db'"
            Write-Host "Private DB backups created in mediastack-db." -ForegroundColor Green
            Write-Host "Restarting apps..." -ForegroundColor Yellow
            docker compose start jellyfin sonarr radarr jellyseerr bazarr transmission
        }
        '7' { 
            Write-Host "--- Restore Options ---" -ForegroundColor Cyan
            Write-Host "1. Restore Database from SQL/SQLite Dump"
            Write-Host "2. Restore Full Config Zip"
            $restChoice = Read-Host "Select a restore option"
            if ($restChoice -eq '1') {
                $dbs = Get-ChildItem "$ScriptDir\db-backup\*.sqlite3" -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending
                if ($dbs.Count -eq 0) { Write-Host "No DB backups found." -ForegroundColor Red; continue }
                for ($i=0; $i -lt $dbs.Count; $i++) { Write-Host "$($i+1). $($dbs[$i].Name)" }
                $dbChoice = Read-Host "Select DB to restore (Number)"
                $dbIdx = [int]$dbChoice - 1
                if ($dbIdx -ge 0 -and $dbIdx -lt $dbs.Count) {
                    $selected = $dbs[$dbIdx]
                    $svc = $selected.Name.Split('_')[0]
                    $targetPath = ""
                    if ($svc -eq "jellyfin") { $targetPath = "config\jellyfin\data\data\jellyfin.db" }
                    elseif ($svc -eq "radarr") { $targetPath = "config\radarr\radarr.db" }
                    elseif ($svc -eq "sonarr") { $targetPath = "config\sonarr\sonarr.db" }
                    elseif ($svc -eq "bazarr") { $targetPath = "config\bazarr\db\bazarr.db" }
                    elseif ($svc -eq "jellyseerr") { $targetPath = "config\jellyseerr\db\db.sqlite3" }
                    if ($targetPath -ne "") {
                        Write-Host "Stopping stack for restore..." -ForegroundColor Yellow
                        docker compose down
                        Copy-Item $selected.FullName (Join-Path $ScriptDir $targetPath) -Force
                        Write-Host "Restored $svc DB. Restarting stack..." -ForegroundColor Green
                        docker compose up -d
                    } else { Write-Host "Unknown service mapping for $($selected.Name)." -ForegroundColor Red }
                }
            } elseif ($restChoice -eq '2') {
                $zips = Get-ChildItem "$ScriptDir\handoffs\*.zip" -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending
                if ($zips.Count -eq 0) { Write-Host "No Config Zips found." -ForegroundColor Red; continue }
                for ($i=0; $i -lt $zips.Count; $i++) { Write-Host "$($i+1). $($zips[$i].Name)" }
                $zipChoice = Read-Host "Select Config Zip to restore (Number)"
                $zipIdx = [int]$zipChoice - 1
                if ($zipIdx -ge 0 -and $zipIdx -lt $zips.Count) {
                    $selected = $zips[$zipIdx]
                    Write-Host "Stopping stack for restore..." -ForegroundColor Yellow
                    docker compose down
                    Expand-Archive -Path $selected.FullName -DestinationPath $ScriptDir -Force
                    Write-Host "Restored configs. Restarting stack..." -ForegroundColor Green
                    docker compose up -d
                }
            }
        }
        '8' { docker compose logs -f caddy }
        '9' { Show-HealthMonitor }
        '10' { New-SystemsReport }
        '11' { Write-Host "Exiting..."; break }
        default { Write-Host "Invalid option." -ForegroundColor Red }
    }
}







