$files = Get-ChildItem -Path "$PSScriptRoot\..\*.ps1"
$errCount = 0
foreach ($f in $files) {
    $tokens = $null
    $errors = $null
    $null = [System.Management.Automation.Language.Parser]::ParseFile($f.FullName, [ref]$tokens, [ref]$errors)
    if ($errors.Count -gt 0) {
        $errCount++
        Write-Host ("[ERROR] " + $f.Name + " (" + $errors[0].Extent.StartLineNumber + "): " + $errors[0].Message) -ForegroundColor Red
    }
}
if ($errCount -eq 0) {
    Write-Host "All PowerShell scripts in workspace passed syntax validation with 0 errors!" -ForegroundColor Green
}
