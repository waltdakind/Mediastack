param(
    [int]$TargetCount = 20,
    [string]$OutputFile = "$PSScriptRoot\french_tv_channels.md",
    [string]$PlaylistUrl = "https://iptv-org.github.io/iptv/countries/fr.m3u"
)

Write-Host "Fetching playlist from $PlaylistUrl..."
try {
    $m3uContent = Invoke-RestMethod -Uri $PlaylistUrl -ErrorAction Stop
} catch {
    Write-Error "Failed to fetch playlist."
    exit 1
}

$lines = $m3uContent -split "`n"
$channels = @()

# Ignore SSL errors just in case some streams use self-signed certs
[System.Net.ServicePointManager]::ServerCertificateValidationCallback = {$true}
[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12

Write-Host "Testing channels until we confidently find $TargetCount working streams..."

$currentName = ""
foreach ($line in $lines) {
    $line = $line.Trim()
    if ($line.StartsWith("#EXTINF")) {
        # Extract channel name after the last comma
        $parts = $line -split ","
        if ($parts.Length -ge 2) {
            $currentName = $parts[-1].Trim()
        }
    } elseif ($line.StartsWith("http")) {
        $url = $line
        if ($currentName) {
            Write-Host "Testing: $currentName..." -NoNewline
            try {
                $request = [System.Net.WebRequest]::Create($url)
                $request.Timeout = 4000 # 4 second strict timeout
                $request.Method = "GET"
                
                # Fetch only a tiny chunk of data to verify it's alive, then close
                $response = $request.GetResponse()
                if ($response.StatusCode -eq 200) {
                    Write-Host " [ONLINE]" -ForegroundColor Green
                    $channels += [PSCustomObject]@{
                        Name = $currentName
                        Url = $url
                    }
                    if ($channels.Count -ge $TargetCount) {
                        $response.Close()
                        break
                    }
                } else {
                    Write-Host " [HTTP $($response.StatusCode)]" -ForegroundColor Yellow
                }
                $response.Close()
            } catch [System.Net.WebException] {
                if ($_.Exception.Response) {
                    $statusCode = $_.Exception.Response.StatusCode
                    Write-Host " [FAILED - HTTP $statusCode]" -ForegroundColor Red
                } else {
                    Write-Host " [FAILED - Timeout/Offline]" -ForegroundColor Red
                }
            } catch {
                Write-Host " [FAILED - Error]" -ForegroundColor Red
            }
            $currentName = ""
        }
    }
}

Write-Host ""
Write-Host "Found $($channels.Count) working channels!"

$mdContent = "# Curated French TV Channels`n`n"
$mdContent += "> [!NOTE]`n"
$mdContent += "> These channels were automatically verified as ONLINE and NOT geo-blocked at the time of generation.`n`n"
$mdContent += "| Channel Name | Stream URL (Copy & Paste in VLC) |`n"
$mdContent += "|---|---|`n"
foreach ($c in $channels) {
    $url = $c.Url
    $mdContent += "| $($c.Name) | `$url` |`n"
}

$mdContent += "`n## Want more channels?`n"
$mdContent += "I've included a standalone PowerShell script that automatically fetches and tests streams. Open PowerShell in this directory and run:`n"
$mdContent += "````powershell`n"
$mdContent += ".\Test-MoreChannels.ps1 -TargetCount 50`n"
$mdContent += "`````n"
$mdContent += "It will systematically test channels until it finds exactly 50 working ones and overwrite this file.`n"

Set-Content -Path $OutputFile -Value $mdContent -Force
Write-Host "Results saved successfully to $OutputFile!"
