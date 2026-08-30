#!/usr/bin/env pwsh
# =============================================================================
# start-arm.ps1  --  MediaStack ARM Satellite Launcher (Windows ARM / Pi)
# =============================================================================
param(
    [Parameter(Position=0)] [string]$Command = "up",
    [switch]$Build,
    [switch]$NoWait,
    [switch]$NoDiag,
    [Parameter(ValueFromRemainingArguments=$true)] [string[]]$RemainingArgs
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Continue"

$COMPOSE_FILES = if (Test-Path ".env") {
    @("--env-file", ".env", "--env-file", ".env.arm", "-f", "docker-compose.yml", "-f", "docker-compose.arm.yml")
} else {
    @("--env-file", ".env.arm", "-f", "docker-compose.yml", "-f", "docker-compose.arm.yml")
}
$env:ARCH_PROFILE = "arm"

# == Colour helpers =============================================================
function C    { param($t,$fg,[bool]$nl=$true) if($nl){Write-Host $t -ForegroundColor $fg}else{Write-Host $t -ForegroundColor $fg -NoNewline} }
function NL   { Write-Host "" }
function Ln   { param([string]$c="DarkGray",[int]$w=72)  C ("  " + ([string][char]0x2500 * $w)) $c }
function DLn  { param([string]$c="Magenta" ,[int]$w=72)  C ("  " + ([string][char]0x2550 * $w)) $c }

function Ok   ($t) { C "  [ok] $t" Green    }
function Warn ($t) { C "  [!]  $t" Yellow   }
function Info ($t) { C "  [>]  $t" White    }
function Err  ($t) { C "  [x]  $t" Red      }

function Hdr ($label, $color="Magenta") {
    NL
    DLn $color
    C "  >>  $label" $color
    Ln $color
}

# == Read .env helper ===========================================================
function Get-EnvVal([string]$key, [string]$default = "") {
    if (Test-Path ".env.arm") {
        $m = Select-String -Path ".env.arm" -Pattern "^${key}=(.+)" | Select-Object -First 1
        if ($m) { return $m.Matches[0].Groups[1].Value.Trim() }
    }
    return $default
}

# == Get LAN IP =================================================================
function Get-LanIP {
    try {
        (Get-NetIPAddress -AddressFamily IPv4 |
         Where-Object { $_.PrefixOrigin -ne "WellKnown" -and $_.IPAddress -ne "127.0.0.1" -and $_.InterfaceAlias -notmatch "vEthernet" } |
         Select-Object -First 1).IPAddress
    } catch { "unknown" }
}

# == ASCII Banner ===============================================================
function Show-Banner {
    NL
    DLn Magenta 72
    $art = @(
        '    __  __         _ _       _____ _             _    ',
        '   |  \/  | ___  __| (_) __ _/ ____| |_ __ _  ___| | __',
        '   | |\/| |/ _ \/ _` | |/ _` \___ \| __/ _` |/ __| |/ /',
        '   | |  | |  __/ (_| | | (_| |___) | || (_| | (__|   < ',
        '   |_|  |_|\___|\__,_|_|\__,_|____/ \__\__,_|\___|_|\_\'
    )
    foreach ($line in $art) {
        Write-Host $line -ForegroundColor Magenta
    }
    NL
    Write-Host "  ARM Satellite  |  Music + Theming  |  LAN-only  |  $(Get-Date -Format 'yyyy-MM-dd HH:mm')" -ForegroundColor DarkMagenta
    DLn Magenta 72
    NL
}

# == Environment Summary ========================================================
function Show-EnvSummary {
    param([string]$LanIP, [string]$MainHost, [string]$DeviceName, [string]$ConfigRoot, [string]$MusicRoot)
    Hdr "ENVIRONMENT" Magenta
    $rows = @(
        @{ K="ARCH_PROFILE"   ; V="arm (Satellite -- Music + Theming)"  ; C="Magenta"     }
        @{ K="LAN IP"          ; V=$LanIP                                 ; C="White"       }
        @{ K="DEVICE NAME"     ; V=$DeviceName                            ; C="White"       }
        @{ K="MAIN_SERVER"     ; V=if ($MainHost) { "http://$MainHost" } else { "(not set -- MAIN_SERVER_HOST missing)" }; C=if ($MainHost) {"DarkCyan"} else {"Yellow"} }
        @{ K="LAN_DOMAIN"      ; V=(Get-EnvVal "LAN_DOMAIN" "mediastack.local"); C="DarkGray" }
        @{ K="CONFIG_ROOT"     ; V=$ConfigRoot                            ; C="DarkMagenta" }
        @{ K="MUSIC_ROOT"      ; V=$MusicRoot                             ; C="DarkMagenta" }
        @{ K="TZ"              ; V=(Get-EnvVal "TZ" "America/New_York")   ; C="DarkGray"    }
        @{ K="PUID/PGID"       ; V="$(Get-EnvVal 'PUID' '1000') / $(Get-EnvVal 'PGID' '1000')"; C="DarkGray" }
    )
    foreach ($r in $rows) {
        Write-Host ("    {0,-16}" -f $r.K) -ForegroundColor DarkGray -NoNewline
        Write-Host $r.V -ForegroundColor $r.C
    }
    NL
}

# == Service Table ==============================================================
function Show-Services {
    param([string]$LanIP, [string]$MainHost)
    Hdr "SATELLITE SERVICES" Magenta
    Write-Host ("  {0,-5} {1,-16} {2,-24} {3}" -f " ", "SERVICE", "ROLE", "ACCESS URL") -ForegroundColor DarkGray
    Ln DarkGray

    $ip = if ($LanIP -and $LanIP -ne "unknown") { $LanIP } else { "<pi-ip>" }

    $services = @(
        @{ G="Proxy";  Icon="[^]"; Name="Caddy";       Role="LAN Reverse Proxy";    Url="http://$ip  (port 80)";   Color="Cyan"     }
        @{ G="Media";  Icon="[>]"; Name="Jellyfin";    Role="Music Server";          Url="http://$ip  (port 8096)"; Color="Cyan"     }
        @{ G="Sync";   Icon="[~]"; Name="Syncthing";   Role="Theme Sync Receiver";   Url="http://${ip}:8384";       Color="Cyan"     }
        @{ G="System"; Icon="[-]"; Name="healthguard"; Role="Self-Healing";          Url="(background daemon)";     Color="DarkGray" }
        @{ G="System"; Icon="[-]"; Name="Watchtower";  Role="Auto Image Updates";    Url="(daily 04:00 cron)";      Color="DarkGray" }
        @{ G="System"; Icon="[-]"; Name="db-init";     Role="Startup Init";          Url="(one-shot, exits 0)";     Color="DarkGray" }
    )

    $lastGroup = ""
    foreach ($s in $services) {
        if ($s.G -ne $lastGroup) {
            Write-Host ("  -- {0} --" -f $s.G.ToUpper()) -ForegroundColor DarkGray
            $lastGroup = $s.G
        }
        $nc = if ($s.Color -eq "DarkGray") { "DarkGray" } else { "White" }
        Write-Host ("  {0}  " -f $s.Icon)   -ForegroundColor DarkMagenta -NoNewline
        Write-Host ("{0,-16}" -f $s.Name)    -ForegroundColor $nc         -NoNewline
        Write-Host ("{0,-24}" -f $s.Role)    -ForegroundColor DarkGray    -NoNewline
        Write-Host $s.Url                    -ForegroundColor $s.Color
    }

    Ln DarkGray

    # Link to main server
    if ($MainHost) {
        NL
        Write-Host "  [>]  Main Server (x64)           " -ForegroundColor White -NoNewline
        Write-Host "http://$MainHost" -ForegroundColor DarkCyan
    }
    NL
}

# == Database & Volume Map ======================================================
function Show-DatabaseMap {
    param([string]$ConfigRoot, [string]$MusicRoot)
    Hdr "DATABASE & VOLUME MAP" Magenta
    Write-Host "  SQLite config databases and bind-mounts per satellite service:" -ForegroundColor DarkGray
    NL
    Write-Host ("  {0,-14} {1,-30} {2,-28} {3}" -f "SERVICE", "HOST PATH", "CONTAINER PATH", "TYPE") -ForegroundColor DarkGray
    Ln DarkGray

    $maps = @(
        @{ Svc="Caddy";      Host="[vol] mediastack_caddy_data";         Ct="/data";                   Type="Docker volume"  }
        @{ Svc="Caddy";      Host="[vol] mediastack_caddy_config";       Ct="/config";                 Type="Docker volume"  }
        @{ Svc="Caddy";      Host="./Caddyfile.arm";                     Ct="/etc/caddy/Caddyfile";    Type="Config :ro"     }
        @{ Svc="Jellyfin";   Host="$ConfigRoot/jellyfin";                Ct="/config";                 Type="SQLite+config"  }
        @{ Svc="Jellyfin";   Host="$ConfigRoot/jellyfin-arm-cache";      Ct="/cache";                  Type="Bind (no shm)"  }
        @{ Svc="Jellyfin";   Host="$MusicRoot";                          Ct="/data/music";             Type="Music :ro"      }
        @{ Svc="Jellyfin";   Host="$ConfigRoot/jellyfin/web";            Ct="/config/web";             Type="Theme sync rw"  }
        @{ Svc="Syncthing";  Host="$ConfigRoot/syncthing";               Ct="/var/syncthing/config";   Type="Config+index DB"}
        @{ Svc="Syncthing";  Host="$ConfigRoot/jellyfin/web";            Ct="/data/jellyfin-theme";    Type="Theme target rw"}
        @{ Svc="healthguard";Host="C:/Users/Public/Mediastack";          Ct="/mediastack";             Type="Logs+scripts"   }
        @{ Svc="healthguard";Host="/var/run/docker.sock";                 Ct="/var/run/docker.sock";    Type="Docker socket"  }
        @{ Svc="db-init";    Host="$ConfigRoot (ro)";                     Ct="/opt/mediastack/config";  Type="Backup src :ro" }
        @{ Svc="db-init";    Host="C:/Users/Public/Mediastack";          Ct="/mediastack";             Type="Backup target"  }
    )

    $lastSvc = ""
    foreach ($m in $maps) {
        if ($m.Svc -ne $lastSvc) {
            NL
            Write-Host ("  >> {0}" -f $m.Svc.ToUpper()) -ForegroundColor Magenta
            $lastSvc = $m.Svc
        }
        $hostDisp = if ($m.Host.Length -gt 29) { $m.Host.Substring(0,27) + ".." } else { $m.Host }
        $ctDisp   = if ($m.Ct.Length   -gt 27) { $m.Ct.Substring(0,25)   + ".." } else { $m.Ct   }
        $tCol = switch -Wildcard ($m.Type) {
            "*SQLite*"  { "Yellow"      }
            "*volume*"  { "Magenta"     }
            "*socket*"  { "Red"         }
            "*Music*"   { "DarkMagenta" }
            "*Theme*"   { "Cyan"        }
            default     { "DarkGray"    }
        }
        Write-Host ("    {0,-30} {1,-28} " -f $hostDisp, $ctDisp) -ForegroundColor DarkGray -NoNewline
        Write-Host $m.Type -ForegroundColor $tCol
    }
    NL
    Ln DarkGray
    NL
    Write-Host "  Theme sync flow:  x64 Syncthing --> CONFIG_ROOT/jellyfin/web/ --> Jellyfin serves automatically" -ForegroundColor DarkGray
    Write-Host "  Music share:      Same network path as x64 -- library content is identical across devices" -ForegroundColor DarkGray
    NL
}

# == Live Status ================================================================
function Show-Status {
    param([int]$WaitSecs = 6)
    NL
    Write-Host "  >> CONTAINER STATUS" -ForegroundColor Magenta -NoNewline
    if ($WaitSecs -gt 0) {
        Write-Host "  (checking in ${WaitSecs}s...)" -ForegroundColor DarkGray
        Start-Sleep $WaitSecs
    } else { NL }

    $jsonLines = docker compose @COMPOSE_FILES ps --format json 2>$null
    if (-not $jsonLines -or $jsonLines.Length -eq 0) {
        $jsonLines = docker compose ps --format json 2>$null
    }
    if (-not $jsonLines) { Warn "No containers found -- is the stack running?"; return }

    Ln DarkGray
    Write-Host ("  {0,-22} {1,-32} {2,-20} {3}" -f "CONTAINER", "STATUS", "HEALTH", "ROLE") -ForegroundColor DarkGray
    Ln DarkGray

    foreach ($line in $jsonLines) {
        if ([string]::IsNullOrWhiteSpace($line)) { continue }
        try {
            $obj = $line | ConvertFrom-Json
            $name   = if ($obj.Name) { $obj.Name } elseif ($obj.Service) { $obj.Service } else { "container" }
            $status = if ($obj.Status) { $obj.Status } else { $obj.State }
            $health = if ($obj.Health) { $obj.Health } else { "" }

            $sc = switch -Wildcard ($status) {
                "Up*"     { "Green"   }
                "Exited*" { if ($name -match "db-init") { "DarkGray" } else { "Red" } }
                default   { "Yellow"  }
            }
            $hi = switch ($health) {
                "healthy"   { "[OK] healthy"           }
                "unhealthy" { "[X]  unhealthy"          }
                "starting"  { "[..] starting"           }
                ""          { if ($name -match "db-init") { "[OK] exited (normal)" } else { "--" } }
                default     { $health }
            }
            $hc = switch ($health) {
                "healthy"   { "Green"    }
                "unhealthy" { "Red"      }
                "starting"  { "Yellow"   }
                default     { "DarkGray" }
            }
            $role = switch -Wildcard ($name) {
                "*db-init*"     { "one-shot initialiser"   }
                "*healthguard*" { "self-heal daemon"        }
                "*watchtower*"  { "auto-update daemon"      }
                "*caddy*"       { "LAN reverse proxy"       }
                "*jellyfin*"    { "music server"            }
                "*syncthing*"   { "theme sync receiver"     }
                "*sonarr*"      { "TV management"           }
                "*radarr*"      { "movie management"        }
                "*prowlarr*"    { "indexer manager"         }
                "*bazarr*"      { "subtitle manager"        }
                "*jellyseerr*"  { "media requests"          }
                "*transmission*"{ "torrent client"          }
                "*tvheadend*"   { "live TV & DVR tuner"     }
                "*api-gateway*" { "microservice REST proxy" }
                "*mediastack-db*"{ "SQLite web explorer"    }
                default         { "" }
            }
            Write-Host ("  {0,-22}" -f $name)  -ForegroundColor White    -NoNewline
            Write-Host ("{0,-32}" -f $status)   -ForegroundColor $sc      -NoNewline
            Write-Host ("{0,-20}" -f $hi)       -ForegroundColor $hc      -NoNewline
            Write-Host $role                    -ForegroundColor DarkGray
        } catch { }
    }
    Ln DarkGray
    NL
}

# == Connectivity Diagnostics ===================================================
function Show-ConnectivityReport {
    param([string]$MainHost, [string]$LanIP)
    Hdr "CONNECTIVITY DIAGNOSTICS" Magenta

    $checks = @(
        @{ Label="Internet (Google DNS)"; Host="8.8.8.8";        Desc="outbound internet"  }
        @{ Label="Main Server (x64)";     Host=$MainHost;         Desc="MAIN_SERVER_HOST"   }
        @{ Label="Media NAS (primary)";   Host="Ordinateurdevol"; Desc="\\Ordinateurdevol"  }
    )
    foreach ($c in $checks) {
        if ([string]::IsNullOrWhiteSpace($c.Host)) {
            Write-Host ("  [*] {0,-28} ({1,-20}) ... " -f $c.Label, $c.Desc) -ForegroundColor White -NoNewline
            Write-Host "[--] SKIPPED (not configured)" -ForegroundColor DarkGray
            continue
        }
        Write-Host ("  [*] {0,-28} ({1,-20}) ... " -f $c.Label, $c.Desc) -ForegroundColor White -NoNewline
        $ok = Test-Connection -ComputerName $c.Host -Count 1 -Quiet -ErrorAction SilentlyContinue
        if ($ok) { Write-Host "[OK] ONLINE"      -ForegroundColor Green }
        else      { Write-Host "[X]  UNREACHABLE" -ForegroundColor Red   }
    }

    # Docker daemon
    Write-Host "  [*] Docker daemon                    (docker socket)          ... " -ForegroundColor White -NoNewline
    $dv = docker version --format "{{.Server.Version}}" 2>$null
    if ($dv) { Write-Host "[OK] running  v$dv" -ForegroundColor Green }
    else      { Write-Host "[X]  not reachable" -ForegroundColor Red   }

    # TCP port probes
    NL
    Write-Host "  Port probes (localhost):" -ForegroundColor DarkGray
    Ln DarkGray
    $ports = @(
        @{ Name="Caddy HTTP";  Port=80   }
        @{ Name="Jellyfin";    Port=8096 }
        @{ Name="Syncthing";   Port=8384 }
    )
    foreach ($p in $ports) {
        Write-Host ("    {0,-20} :{1,-6}  " -f $p.Name, $p.Port) -ForegroundColor DarkGray -NoNewline
        $tcp = New-Object System.Net.Sockets.TcpClient
        try {
            $tcp.Connect("127.0.0.1", $p.Port)
            if ($tcp.Connected) { Write-Host "[OK] open"   -ForegroundColor Green }
            else                 { Write-Host "[X]  closed" -ForegroundColor Red   }
        } catch {
            Write-Host "[X]  closed" -ForegroundColor Red
        } finally {
            $tcp.Dispose()
        }
    }

    NL
    DLn Magenta 72
    NL
}

# == healthguard Log Tail =======================================================
function Show-HealthguardStatus {
    Hdr "HEALTHGUARD SUMMARY" Magenta
    $logPath = Join-Path $env:PUBLIC "Mediastack\logs\healthguard.log"
    if (Test-Path $logPath) {
        $lines = Get-Content $logPath -Tail 10
        foreach ($l in $lines) {
            $col = switch -Wildcard ($l) {
                "*CRITICAL*" { "Red"         }
                "*ERROR*"    { "Red"         }
                "*WARN*"     { "Yellow"      }
                "*ACTION*"   { "Magenta"     }
                "*RECOVER*"  { "DarkMagenta" }
                default      { "DarkGray"    }
            }
            Write-Host "  $l" -ForegroundColor $col
        }
        NL
        Write-Host "  Full log: $logPath" -ForegroundColor DarkGray
    } else {
        Write-Host "  Log not found yet -- healthguard may still be starting." -ForegroundColor DarkGray
        Write-Host "  Run: docker compose logs -f healthguard" -ForegroundColor DarkGray
    }
    NL
}

# == Quick Commands =============================================================
function Show-Commands {
    Hdr "QUICK COMMANDS" Magenta
    $cmds = @(
        @{ Cmd = ".\start-arm.ps1 ps";               Desc = "Live container status + healthguard tail" }
        @{ Cmd = ".\start-arm.ps1 logs";             Desc = "Tail all logs" }
        @{ Cmd = ".\start-arm.ps1 down";             Desc = "Stop the satellite stack" }
        @{ Cmd = ".\start-arm.ps1 restart";          Desc = "Restart all services" }
        @{ Cmd = ".\start-arm.ps1 up -NoDiag";       Desc = "Start without diagnostics" }
        @{ Cmd = ".\start-arm.ps1 diag";             Desc = "Run full diagnostics standalone" }
        @{ Cmd = "docker compose -f docker-compose.yml -f docker-compose.arm.yml logs -f healthguard"
           Desc = "Live self-heal events" }
    )
    foreach ($c in $cmds) {
        Write-Host "  " -NoNewline
        Write-Host $c.Cmd.PadRight(60) -ForegroundColor Magenta -NoNewline
        Write-Host $c.Desc             -ForegroundColor DarkGray
    }
    NL
    DLn Magenta 72
    NL
}

# ==============================================================================
# Main Dispatch
# ==============================================================================
Show-Banner

$lanIP      = Get-LanIP
$mainHost   = Get-EnvVal "MAIN_SERVER_HOST" ""
$deviceName = Get-EnvVal "ARM_DEVICE_NAME"  "mediastack-arm"
$configRoot = Get-EnvVal "CONFIG_ROOT"      "/opt/mediastack/config"
$musicRoot  = Get-EnvVal "MUSIC_ROOT"       "C:/Users/Public/Music"

$procArch = $env:PROCESSOR_ARCHITECTURE
Ok "Architecture  : $procArch"
Ok "Device name   : $deviceName"
if ($lanIP) { Ok "LAN IP        : $lanIP" }
if ($mainHost) { Ok "Main server   : http://$mainHost" } else { Warn "MAIN_SERVER_HOST not set in .env" }
NL

switch ($Command.ToLower()) {

    "up" {
        Show-Services -LanIP $lanIP -MainHost $mainHost

        if (-not $NoDiag) {
            Show-EnvSummary  -LanIP $lanIP -MainHost $mainHost -DeviceName $deviceName `
                             -ConfigRoot $configRoot -MusicRoot $musicRoot
            Show-DatabaseMap -ConfigRoot $configRoot -MusicRoot $musicRoot
        }

        if ($Build) {
            Info "Pulling latest ARM images..."
            docker compose @COMPOSE_FILES pull
            NL
        }

        Info "Launching ARM satellite stack..."
        NL
        docker compose @COMPOSE_FILES up -d
        NL

        if ($LASTEXITCODE -ne 0) { Err "docker compose up failed (exit $LASTEXITCODE)"; exit $LASTEXITCODE }

        Ok "Satellite is up!"

        if (-not $NoWait) { Show-Status -WaitSecs 6 }

        Hdr "ACCESS SERVICES" Magenta
        $ip = if ($lanIP) { $lanIP } else { "<pi-ip>" }
        @(
            @{ Icon="[>]"; Label="Jellyfin (music)";  Url="http://$ip          or  http://${ip}:8096" }
            @{ Icon="[~]"; Label="Syncthing";          Url="http://${ip}:8384   (pair with x64 for theme sync)" }
        ) | ForEach-Object {
            Write-Host ("  {0}  {1,-22}" -f $_.Icon, $_.Label) -ForegroundColor White -NoNewline
            Write-Host $_.Url -ForegroundColor Magenta
        }
        if ($mainHost) {
            Write-Host "  [>]  Main server (x64)        " -ForegroundColor White -NoNewline
            Write-Host "http://$mainHost" -ForegroundColor DarkCyan
        }
        NL

        if (-not $NoDiag) {
            Show-ConnectivityReport -MainHost $mainHost -LanIP $lanIP
            Show-HealthguardStatus
        }

        Show-Commands
    }

    "down" {
        Info "Stopping ARM satellite stack..."
        docker compose @COMPOSE_FILES down
        Ok "Stack stopped."
        NL
    }

    "restart" {
        Info "Restarting ARM satellite..."
        docker compose @COMPOSE_FILES down
        docker compose @COMPOSE_FILES up -d
        if ($LASTEXITCODE -eq 0) {
            if (-not $NoWait) { Show-Status -WaitSecs 6 }
            Show-ConnectivityReport -MainHost $mainHost -LanIP $lanIP
            Ok "Restart complete."
        }
        NL
    }

    "logs"  {
        if ($RemainingArgs) {
            docker compose @COMPOSE_FILES logs @RemainingArgs
        } else {
            docker compose @COMPOSE_FILES logs -f
        }
    }

    "ps" {
        Show-Status -WaitSecs 0
        Show-HealthguardStatus
        Show-Commands
    }

    "pull" {
        Info "Pulling latest ARM images..."
        docker compose @COMPOSE_FILES pull
        Ok "Done. Run '.\start-arm.ps1 restart' to apply."
        NL
    }

    "diag" {
        Show-EnvSummary    -LanIP $lanIP -MainHost $mainHost -DeviceName $deviceName `
                           -ConfigRoot $configRoot -MusicRoot $musicRoot
        Show-DatabaseMap   -ConfigRoot $configRoot -MusicRoot $musicRoot
        Show-Status        -WaitSecs 0
        Show-ConnectivityReport -MainHost $mainHost -LanIP $lanIP
        Show-HealthguardStatus
        Show-Commands
    }

    default { docker compose @COMPOSE_FILES $Command @args }
}


