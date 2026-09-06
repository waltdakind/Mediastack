<#
.SYNOPSIS
    Resolves, configures, and validates the correct node-specific Python directory
    across the MediaStack cluster (VoltaireDeux ARM64 vs VoltaireUn x64/AMD64).

.DESCRIPTION
    VoltaireDeux runs on Windows ARM64 (Python installs under Python312-arm64),
    while VoltaireUn runs on Windows x64 (Python installs under Python312 / Python311).
    This script detects the target node and processor architecture, locates the
    appropriate Python installation, configures process and user environment variables,
    and ensures seamless cross-node execution.

.PARAMETER SetEnvironment
    If specified, prepends the resolved Python directory and its Scripts folder to $env:PATH
    and sets $env:PYTHONHOME and $env:MEDIASTACK_PYTHON_EXE for the current session.

.PARAMETER ExportSystem
    If specified, updates the User Environment PATH in the Windows Registry if missing.

.OUTPUTS
    PSCustomObject containing Node, Architecture, PythonDir, PythonExe, ScriptsDir, Version, and IsValid.
#>

[CmdletBinding()]
param(
    [bool]$SetEnvironment = $true,
    [switch]$ExportSystem,
    [switch]$Quiet
)

function Resolve-MediaStackPythonPath {
    [CmdletBinding()]
    param(
        [bool]$SetEnvironment = $true,
        [switch]$ExportSystem,
        [switch]$Quiet
    )

    $currentHost = $env:COMPUTERNAME
    $procArch = [System.Environment]::GetEnvironmentVariable("PROCESSOR_ARCHITECTURE")
    if (-not $procArch) { $procArch = "AMD64" }

    $isVoltaireDeux = ($currentHost -match "VoltaireDeux" -or $currentHost -match "Laptop" -or $env:NODE_ROLE -eq "VoltaireDeux" -or $procArch -eq "ARM64")
    $isVoltaireUn   = ($currentHost -match "VoltaireUn"   -or $currentHost -match "Ordinateur" -or $currentHost -match "Server" -or $env:NODE_ROLE -eq "VoltaireUn" -or $procArch -eq "AMD64")

    $nodeName = if ($isVoltaireDeux) { "VoltaireDeux" } elseif ($isVoltaireUn) { "VoltaireUn" } else { $currentHost }

    $candidateDirs = [System.Collections.Generic.List[string]]::new()

    if ($isVoltaireDeux -or $procArch -eq "ARM64") {
        # Priority search paths for ARM64 (VoltaireDeux)
        if ($env:LOCALAPPDATA) {
            $candidateDirs.Add("$env:LOCALAPPDATA\Programs\Python\Python312-arm64")
            $candidateDirs.Add("$env:LOCALAPPDATA\Programs\Python\Python313-arm64")
            $candidateDirs.Add("$env:LOCALAPPDATA\Programs\Python\Python311-arm64")
            
            # Wildcard search for any installed arm64 python
            $wildcardArm = Get-ChildItem -Path "$env:LOCALAPPDATA\Programs\Python" -Filter "Python*-arm64" -Directory -ErrorAction SilentlyContinue
            if ($wildcardArm) {
                foreach ($dir in $wildcardArm) {
                    if (-not $candidateDirs.Contains($dir.FullName)) { $candidateDirs.Add($dir.FullName) }
                }
            }
        }
        if ($env:ProgramFiles) {
            $candidateDirs.Add("$env:ProgramFiles\Python312-arm64")
            $candidateDirs.Add("$env:ProgramFiles\Python311-arm64")
        }
    } else {
        # Priority search paths for x64 / AMD64 (VoltaireUn)
        if ($env:LOCALAPPDATA) {
            $candidateDirs.Add("$env:LOCALAPPDATA\Programs\Python\Python312")
            $candidateDirs.Add("$env:LOCALAPPDATA\Programs\Python\Python311")
            $candidateDirs.Add("$env:LOCALAPPDATA\Programs\Python\Python310")
            $candidateDirs.Add("$env:LOCALAPPDATA\Programs\Python\Python313")

            # Wildcard search for x64 python (excluding arm64)
            $wildcardX64 = Get-ChildItem -Path "$env:LOCALAPPDATA\Programs\Python" -Filter "Python*" -Directory -ErrorAction SilentlyContinue |
                           Where-Object { $_.Name -notmatch "arm64" }
            if ($wildcardX64) {
                foreach ($dir in $wildcardX64) {
                    if (-not $candidateDirs.Contains($dir.FullName)) { $candidateDirs.Add($dir.FullName) }
                }
            }
        }
        if ($env:ProgramFiles) {
            $candidateDirs.Add("$env:ProgramFiles\Python312")
            $candidateDirs.Add("$env:ProgramFiles\Python311")
            $candidateDirs.Add("$env:ProgramFiles\Python310")
        }
        $candidateDirs.Add("C:\Python312")
        $candidateDirs.Add("C:\Python311")
        $candidateDirs.Add("C:\Python310")
    }

    # Also check if python.exe in current PATH matches architecture
    $cmdPython = Get-Command python.exe -ErrorAction SilentlyContinue
    if ($cmdPython -and $cmdPython.Source) {
        $parentDir = Split-Path -Parent $cmdPython.Source
        if ($parentDir -notmatch "WindowsApps" -and -not $candidateDirs.Contains($parentDir)) {
            $candidateDirs.Add($parentDir)
        }
    }

    $resolvedDir = $null
    $resolvedExe = $null

    foreach ($candidate in $candidateDirs) {
        if (-not [string]::IsNullOrWhiteSpace($candidate) -and (Test-Path $candidate)) {
            $exePath = Join-Path $candidate "python.exe"
            if (Test-Path $exePath) {
                $resolvedDir = $candidate
                $resolvedExe = $exePath
                break
            }
        }
    }

    $isValid = ($null -ne $resolvedExe -and (Test-Path $resolvedExe))
    $scriptsDir = if ($resolvedDir) { Join-Path $resolvedDir "Scripts" } else { $null }
    $pyVersion = $null

    if ($isValid) {
        try {
            $pyVersion = (& $resolvedExe --version 2>&1).ToString().Trim()
        } catch {
            $pyVersion = "Python (Detected)"
        }

        if ($SetEnvironment) {
            $pathParts = [System.Collections.Generic.List[string]]::new(($env:PATH -split ';'))
            
            # Ensure PythonDir is in PATH
            if (-not ($pathParts -contains $resolvedDir)) {
                $env:PATH = "$resolvedDir;" + $env:PATH
            }
            # Ensure ScriptsDir is in PATH
            if ($scriptsDir -and (Test-Path $scriptsDir) -and -not ($pathParts -contains $scriptsDir)) {
                $env:PATH = "$scriptsDir;" + $env:PATH
            }

            $env:PYTHONHOME = $resolvedDir
            $env:PYTHON_HOME = $resolvedDir
            $env:MEDIASTACK_PYTHON_DIR = $resolvedDir
            $env:MEDIASTACK_PYTHON_EXE = $resolvedExe
        }

        if ($ExportSystem) {
            try {
                $userPath = [System.Environment]::GetEnvironmentVariable("PATH", [System.EnvironmentVariableTarget]::User)
                $userPathParts = ($userPath -split ';')
                $modified = $false
                if ($userPathParts -notcontains $resolvedDir) {
                    $userPath = "$resolvedDir;" + $userPath
                    $modified = $true
                }
                if ($scriptsDir -and (Test-Path $scriptsDir) -and ($userPathParts -notcontains $scriptsDir)) {
                    $userPath = "$scriptsDir;" + $userPath
                    $modified = $true
                }
                if ($modified) {
                    [System.Environment]::SetEnvironmentVariable("PATH", $userPath, [System.EnvironmentVariableTarget]::User)
                }
            } catch {
                # Silently continue if user registry write permissions are restricted
            }
        }
    }

    $result = [PSCustomObject]@{
        Node          = $nodeName
        Architecture  = $procArch
        PythonDir     = $resolvedDir
        PythonExe     = $resolvedExe
        ScriptsDir    = $scriptsDir
        Version       = $pyVersion
        IsValid       = $isValid
    }

    if (-not $Quiet) {
        Write-Host "================================================================================" -ForegroundColor DarkCyan
        Write-Host " [MEDIASTACK PYTHON RESOLVER] Node Architecture & Path Check" -ForegroundColor Cyan
        Write-Host "================================================================================" -ForegroundColor DarkCyan
        Write-Host (" Target Cluster Node     : [{0}]" -f $result.Node) -ForegroundColor Yellow
        Write-Host (" Processor Architecture : [{0}]" -f $result.Architecture) -ForegroundColor Yellow
        Write-Host (" Resolved Python Path   : [{0}]" -f $(if ($result.IsValid) { $result.PythonDir } else { "NOT FOUND" })) -ForegroundColor $(if ($result.IsValid) { "Green" } else { "Red" })
        Write-Host (" Python Executable      : [{0}]" -f $(if ($result.IsValid) { $result.PythonExe } else { "N/A" })) -ForegroundColor DarkGray
        Write-Host (" Detected Version       : [{0}]" -f $(if ($result.IsValid) { $result.Version } else { "N/A" })) -ForegroundColor White
        Write-Host "--------------------------------------------------------------------------------" -ForegroundColor DarkGray
    }

    return $result
}

# Execute if run as a script directly
Resolve-MediaStackPythonPath -SetEnvironment:$SetEnvironment -ExportSystem:$ExportSystem -Quiet:$Quiet
