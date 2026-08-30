param(
    [switch]$DryRun,
    [string]$Path = "C:\"
)

Add-Type -AssemblyName Microsoft.VisualBasic

Write-Host "=============================================" -ForegroundColor Cyan
Write-Host "   Safe Deduplicator (Recycle Bin)"
Write-Host "=============================================" -ForegroundColor Cyan
Write-Host ""

$sourceDrive = $Path
$excludeRegex = "^C:\\(Windows|Program Files|Program Files \(x86\)|ProgramData|\$Recycle\.Bin|System Volume Information)"

Write-Host "[+] Scanning $sourceDrive (Skipping System Folders)... This will take a while!"

$allFiles = Get-ChildItem -Path $sourceDrive -Recurse -File -ErrorAction SilentlyContinue | Where-Object {
    $_.FullName -notmatch $excludeRegex -and $_.FullName -notmatch "\\AppData\\"
}

Write-Host "[+] Found $($allFiles.Count) files to analyze."

$sizeGroups = $allFiles | Group-Object Length | Where-Object { $_.Count -gt 1 }

$totalDupes = 0
$freedSpace = 0

Write-Host "[+] Hashing files with identical sizes..."

foreach ($group in $sizeGroups) {
    $hashGroups = @{}
    foreach ($file in $group.Group) {
        try {
            $stream = [System.IO.File]::OpenRead($file.FullName)
            $sha256 = [System.Security.Cryptography.SHA256]::Create()
            $hashBytes = $sha256.ComputeHash($stream)
            $stream.Close()
            $hashStr = [BitConverter]::ToString($hashBytes).Replace("-","")
            if (-not $hashGroups.ContainsKey($hashStr)) {
                $hashGroups[$hashStr] = @()
            }
            $hashGroups[$hashStr] += $file
        } catch {}
    }
    
    foreach ($hash in $hashGroups.Keys) {
        $files = $hashGroups[$hash]
        if ($files.Count -gt 1) {
            $files = $files | Sort-Object { $_.FullName.Length }
            $master = $files[0]
            $masterUser = "System"
            if ($master.FullName -match "^C:\\Users\\([^\\]+)") { $masterUser = $matches[1] }
            
            for ($i = 1; $i -lt $files.Count; $i++) {
                $dupe = $files[$i]
                $dupeUser = "System"
                if ($dupe.FullName -match "^C:\\Users\\([^\\]+)") { $dupeUser = $matches[1] }
                
                if ($masterUser -ne "System" -and $dupeUser -ne "System" -and $masterUser -ne $dupeUser) {
                    continue
                }
                
                $totalDupes++
                $freedSpace += $dupe.Length
                Write-Host "[-] Duplicate: $($dupe.FullName) -> Moving to Recycle Bin" -ForegroundColor DarkGray
                if (-not $DryRun) {
                    try {
                        [Microsoft.VisualBasic.FileIO.FileSystem]::DeleteFile($dupe.FullName, 'OnlyErrorDialogs', 'SendToRecycleBin')
                    } catch {}
                }
            }
        }
    }
}

$mbFreed = [math]::Round($freedSpace / 1MB, 2)
Write-Host "`n[+] Deduplication Complete!" -ForegroundColor Green
Write-Host "    Found $totalDupes duplicates."
if (-not $DryRun) {
    Write-Host "    Sent to Recycle Bin: $mbFreed MB"
} else {
    Write-Host "    (Dry Run) Potential space savings: $mbFreed MB"
}
