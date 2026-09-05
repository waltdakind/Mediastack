param(
    [int]$TargetCount = 20,
    [string]$OutputFile = "$PSScriptRoot\french_true_crime_channels.md"
)

$urls = @(
    "https://iptv-org.github.io/iptv/countries/fr.m3u",
    "https://iptv-org.github.io/iptv/languages/fra.m3u"
)

$keywords = @("crime", "investigation", "enquetes", "enquÃªtes", "police", "justice", "meurtre", "criminel", "mystere", "mystÃ¨re", "thriller", "polar", "detective", "dÃ©tÃ©ctive", "flic", "homicide", "sang", "action", "suspense")

$allLines = @()
foreach ($url in $urls) {
    Write-Host "Fetching $url..."
    try {
        $m3uContent = Invoke-RestMethod -Uri $url -ErrorAction Stop
        $allLines += $m3uContent -split "`n"
    } catch {
        Write-Host "Failed to fetch $url"
    }
}

$channels = @()
$candidateChannels = @()

$currentName = ""
foreach ($line in $allLines) {
    $line = $line.Trim()
    if ($line.StartsWith("#EXTINF")) {
        $parts = $line -split ","
        if ($parts.Length -ge 2) {
            $currentName = $parts[-1].Trim()
        }
    } elseif ($line.StartsWith("http")) {
        $streamUrl = $line
        if ($currentName) {
            $isMatch = $false
            foreach ($kw in $keywords) {
                if ($currentName -match "(?i)$kw") {
                    $isMatch = $true
                    break
                }
            }
            if ($isMatch) {
                # Ensure we don't add duplicates
                $exists = $candidateChannels | Where-Object { $_.Url -eq $streamUrl }
                if (-not $exists) {
                    $candidateChannels += [PSCustomObject]@{
                        Name = $currentName
                        Url = $streamUrl
                    }
                }
            }
            $currentName = ""
        }
    }
}

Write-Host "Found $($candidateChannels.Count) candidate true crime / investigation channels. Testing..."

[System.Net.ServicePointManager]::ServerCertificateValidationCallback = {$true}
[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12

foreach ($c in $candidateChannels) {
    Write-Host "Testing: $($c.Name)..." -NoNewline
    try {
        $request = [System.Net.WebRequest]::Create($c.Url)
        $request.Timeout = 4000
        $request.Method = "GET"
        
        $response = $request.GetResponse()
        if ($response.StatusCode -eq 200) {
            Write-Host " [ONLINE]" -ForegroundColor Green
            $channels += $c
            if ($channels.Count -ge $TargetCount) {
                $response.Close()
                break
            }
        } else {
            Write-Host " [HTTP $($response.StatusCode)]" -ForegroundColor Yellow
        }
        $response.Close()
    } catch {
        Write-Host " [FAILED]" -ForegroundColor Red
    }
}

Write-Host "`nFound $($channels.Count) working true crime channels!"

$mdContent = "# Curated French True Crime Channels`n`n"
$mdContent += "> [!NOTE]`n"
$mdContent += "> These channels were automatically verified as ONLINE and NOT geo-blocked at the time of generation.`n`n"
$mdContent += "| Channel Name | Stream URL (Copy & Paste in VLC) |`n"
$mdContent += "|---|---|`n"
foreach ($c in $channels) {
    $url = $c.Url
    $backtick = [char]96
    $mdContent += "| $($c.Name) | $backtick$url$backtick |`n"
}

Set-Content -Path $OutputFile -Value $mdContent -Force
Write-Host "Results saved successfully to $OutputFile!"
