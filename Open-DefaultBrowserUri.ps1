param([string]$Url)
if ($Url) {
    # Strip microsoft-edge: prefix and unescape URL
    $cleanUrl = $Url -replace "^microsoft-edge:(\/\/)?", ""
    if ($cleanUrl -match "url=(.+)") {
        $cleanUrl = [System.Uri]::UnescapeDataString($Matches[1])
    }
    if ($cleanUrl -and $cleanUrl -notmatch "^https?://") {
        $cleanUrl = "https://$cleanUrl"
    }
    if ($cleanUrl) {
        Start-Process $cleanUrl
    }
}
