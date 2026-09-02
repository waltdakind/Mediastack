$iniPath = "$env:APPDATA\MusicBrainz\Picard.ini"
if (Test-Path $iniPath) {
    Get-Content $iniPath | Select-Object -First 100
}
