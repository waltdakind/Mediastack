#!/usr/bin/env pwsh
# =============================================================================
# start-x64.ps1  --  MediaStack  x64  Main Server Launcher
# =============================================================================
param(
    [Parameter(Position=0)] [string]$Command = "up",
    [switch]$Build,
    [switch]$Force,
    [switch]$NoWait,
    [switch]$NoDiag,
    [Parameter(ValueFromRemainingArguments=$true)] [string[]]$RemainingArgs
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Continue"

$COMPOSE_FILES = if (Test-Path ".env") {
    @("--env-file", ".env", "--env-file", ".env.x64", "-f", "docker-compose.yml", "-f", "docker-compose.x64.yml")
} else {
    @("--env-file", ".env.x64", "-f", "docker-compose.yml", "-f", "docker-compose.x64.yml")
}
$env:ARCH_PROFILE = "x64"

# == Colour helpers =============================================================
function C    { param($t,$fg,[bool]$nl=$true) if($nl){Write-Host $t -ForegroundColor $fg}else{Write-Host $t -ForegroundColor $fg -NoNewline} }
function NL   { Write-Host "" }
function Ln   { param([string]$c="DarkGray",[int]$w=74)  C ("  " + ([string][char]0x2500 * $w)) $c }
function DLn  { param([string]$c="Cyan"   ,[int]$w=74)  C ("  " + ([string][char]0x2550 * $w)) $c }

function Ok   ($t) { C "  [ok] $t" Green   }
function Warn ($t) { C "  [!]  $t" Yellow  }
function Info ($t) { C "  [>]  $t" White   }
function Err  ($t) { C "  [x]  $t" Red     }

function Hdr ($label, $color="Cyan") {
    NL
    DLn $color
    C "  >>  $label" $color
    Ln $color
}

# == Read .env helper ===========================================================
function Get-EnvVal([string]$key, [string]$default = "") {
    if (Test-Path ".env.x64") {
        $m = Select-String -Path ".env.x64" -Pattern "^${key}=(.+)" | Select-Object -First 1
        if ($m) { return $m.Matches[0].Groups[1].Value.Trim() }
    }
    return $default
}

# == ASCII Banner ===============================================================
# Uses block-letter style drawn with pipe/underscore/backslash chars so that
# the letters are legible in any fixed-width terminal font (no Unicode block
# elements that may render at different widths on Windows Terminal vs conhost).
function Show-Banner {
    NL
    DLn Cyan 74
    $art = @(
        "   __  __         _ _       ____  _             _     ",
        "  |  \/  |  ___  | (_) __ _/ ___|| |_ __ _  ___| | __ ",
        "  | |\/| | / _ \ | | |/ _\` |\___ \| __/ _\` |/ __| |/ /",
        "  | |  | ||  __/ | | | (_| | ___) | || (_| | (__|   < ",
        "  |_|  |_| \___| |_|_|\__,_||____/ \__\__,_|\___|_|\_\"
    )
    foreach ($line in $art) {
        Write-Host $line -ForegroundColor Cyan
    }
    NL
    Write-Host "  x64 Main Server  |  Full Stack  |  External-Facing  |  $(Get-Date -Format 'yyyy-MM-dd HH:mm')" -ForegroundColor DarkCyan
    DLn Cyan 74
    NL
}

# == Environment Summary ========================================================
function Show-EnvSummary {
    param([string]$Domain, [string]$ConfigRoot, [string]$DownloadRoot, [string]$MusicRoot, [string]$MediaRoot)
    Hdr "ENVIRONMENT" Cyan
    $puidVal = Get-EnvVal "PUID" "1000"
    $pgidVal = Get-EnvVal "PGID" "1000"
    $tzVal   = Get-EnvVal "TZ" "America/New_York"
    $rows = @(
        @{ K="ARCH_PROFILE"  ; V="x64 (Full Stack -- Main Server)" ; C="Cyan"     }
        @{ K="CADDY_DOMAIN"  ; V=$Domain                            ; C="White"    }
        @{ K="CONFIG_ROOT"   ; V=$ConfigRoot                        ; C="DarkCyan" }
        @{ K="MUSIC_ROOT"    ; V=$MusicRoot                         ; C="DarkCyan" }
        @{ K="MEDIA_ROOT"    ; V=$MediaRoot                         ; C="DarkCyan" }
        @{ K="DOWNLOAD_ROOT" ; V=$DownloadRoot                      ; C="DarkCyan" }
        @{ K="TZ"            ; V=$tzVal                             ; C="DarkGray" }
        @{ K="PUID/PGID"     ; V="$puidVal / $pgidVal"              ; C="DarkGray" }
    )
    foreach ($r in $rows) {
        Write-Host ("    {0,-16}" -f $r.K) -ForegroundColor DarkGray -NoNewline
        Write-Host $r.V -ForegroundColor $r.C
    }
    NL
}

# == Service table ==============================================================
function Show-Services {
    param([string]$Domain)
    Hdr "SERVICES LAUNCHING" Cyan
    Write-Host ("  {0,-5} {1,-16} {2,-22} {3,-40} {4}" -f " ", "SERVICE", "ROLE", "URL", "PORT(S)") -ForegroundColor DarkGray
    Ln DarkGray

    $services = @(
        @{ G="Proxy";      Icon="[^]"; Name="Caddy";        Role="Reverse Proxy";       Url="http://$Domain";               Port="80 / 443"     }
        @{ G="Media";      Icon="[>]"; Name="Jellyfin";     Role="Media Server";         Url="http://$Domain";               Port="8096"         }
        @{ G="Media";      Icon="[>]"; Name="TVHeadend";    Role="TV Stream + EPG";      Url="http://tvheadend.$Domain";     Port="9981 / 9982"  }
        @{ G="Automation"; Icon="[*]"; Name="Prowlarr";     Role="Indexer Manager";      Url="http://prowlarr.$Domain";      Port="9696"         }
        @{ G="Automation"; Icon="[*]"; Name="Radarr";       Role="Movie Automation";     Url="http://radarr.$Domain";        Port="7878"         }
        @{ G="Automation"; Icon="[*]"; Name="Sonarr";       Role="TV Automation";        Url="http://sonarr.$Domain";        Port="8989"         }
        @{ G="Automation"; Icon="[*]"; Name="Transmission"; Role="Torrent Client";       Url="http://transmission.$Domain";  Port="9091 / 51413" }
        @{ G="Sync";       Icon="[~]"; Name="Syncthing";    Role="File Sync + Theming";  Url="http://syncthing.$Domain";     Port="8384 / 22000" }
        @{ G="System";     Icon="[-]"; Name="healthguard";  Role="Self-Healing";         Url="(background daemon)";           Port="--"           }
        @{ G="System";     Icon="[-]"; Name="Watchtower";   Role="Auto-Updates";         Url="(daily 04:00 cron)";            Port="--"           }
        @{ G="System";     Icon="[-]"; Name="db-init";      Role="Startup Init";         Url="(one-shot, exits 0)";           Port="--"           }
    )

    $lastGroup = ""
    foreach ($s in $services) {
        if ($s.G -ne $lastGroup) {
            Write-Host ("  -- {0} --" -f $s.G.ToUpper()) -ForegroundColor DarkGray
            $lastGroup = $s.G
        }
        $isFg = $s.Port -ne "--"
        $iUrl = $s.Url.StartsWith("http")
        $iCol = if ($iUrl) { "Cyan" } else { "DarkGray" }
        $nCol = if ($isFg) { "White" } else { "DarkGray" }
        $pCol = if ($isFg) { "DarkCyan" } else { "DarkGray" }
        Write-Host ("  {0}  " -f $s.Icon)               -ForegroundColor Cyan     -NoNewline
        Write-Host ("{0,-16}" -f $s.Name)                -ForegroundColor $nCol    -NoNewline
        Write-Host ("{0,-22}" -f $s.Role)                -ForegroundColor DarkGray -NoNewline
        Write-Host ("{0,-40}" -f $s.Url)                 -ForegroundColor $iCol    -NoNewline
        Write-Host $s.Port                               -ForegroundColor $pCol
    }
    Ln DarkGray
    NL
}

# == Database & Config Mapping ==================================================
function Show-DatabaseMap {
    param([string]$ConfigRoot, [string]$DownloadRoot, [string]$MusicRoot)
    Hdr "DATABASE & VOLUME MAP" Cyan
    Write-Host "  SQLite config databases and bind-mounts per service:" -ForegroundColor DarkGray
    NL
    Write-Host ("  {0,-14} {1,-30} {2,-28} {3}" -f "SERVICE", "HOST PATH", "CONTAINER PATH", "TYPE") -ForegroundColor DarkGray
    Ln DarkGray

    $maps = @(
        @{ Svc="Caddy";        Host="[vol] mediastack_caddy_data";           Ct="/data";                    Type="Docker volume"  }
        @{ Svc="Caddy";        Host="[vol] mediastack_caddy_config";         Ct="/config";                  Type="Docker volume"  }
        @{ Svc="Caddy";        Host="./Caddyfile";                           Ct="/etc/caddy/Caddyfile";     Type="Config :ro"     }
        @{ Svc="Jellyfin";     Host="$ConfigRoot/jellyfin";                  Ct="/config";                  Type="SQLite+config"  }
        @{ Svc="Jellyfin";     Host="/dev/shm/jellyfin_cache";               Ct="/cache";                   Type="RAM disk"       }
        @{ Svc="Jellyfin";     Host="$MusicRoot";                            Ct="/data/music";              Type="Media :ro"      }
        @{ Svc="Jellyfin";     Host='\\VoltaireUn\MediaStack-Movies';         Ct="/data/movies";             Type="UNC share :ro"  }
        @{ Svc="Jellyfin";     Host='\\VoltaireUn\MediaStack-Shows';          Ct="/data/shows";              Type="UNC share :ro"  }
        @{ Svc="Jellyfin";     Host='\\VoltaireUn\MediaStack-TV';             Ct="/data/tv";                 Type="UNC share :ro"  }
        @{ Svc="Prowlarr";     Host="$ConfigRoot/prowlarr";                  Ct="/config";                  Type="SQLite+config"  }
        @{ Svc="Radarr";       Host="$ConfigRoot/radarr";                    Ct="/config";                  Type="SQLite+config"  }
        @{ Svc="Radarr";       Host='\\VoltaireUn\MediaStack-Movies';         Ct="/movies";                  Type="UNC share rw"   }
        @{ Svc="Radarr";       Host="$DownloadRoot";                         Ct="/downloads";               Type="Downloads rw"   }
        @{ Svc="Sonarr";       Host="$ConfigRoot/sonarr";                    Ct="/config";                  Type="SQLite+config"  }
        @{ Svc="Sonarr";       Host='\\VoltaireUn\MediaStack-Shows';          Ct="/shows";                   Type="UNC share rw"   }
        @{ Svc="Sonarr";       Host='\\VoltaireUn\MediaStack-TV';             Ct="/tv";                      Type="UNC share rw"   }
        @{ Svc="Sonarr";       Host="$DownloadRoot";                         Ct="/downloads";               Type="Downloads rw"   }
        @{ Svc="Transmission"; Host="$ConfigRoot/transmission";              Ct="/config";                  Type="Config+settings"}
        @{ Svc="Transmission"; Host="$DownloadRoot";                         Ct="/downloads";               Type="Downloads rw"   }
        @{ Svc="TVHeadend";    Host="$ConfigRoot/tvheadend";                 Ct="/config";                  Type="SQLite+config"  }
        @{ Svc="TVHeadend";    Host='\\VoltaireUn\MediaStack-Videos\Record';  Ct="/recordings";              Type="UNC share rw"   }
        @{ Svc="Syncthing";    Host="$ConfigRoot/syncthing";                 Ct="/var/syncthing/config";    Type="Config+index DB"}
        @{ Svc="Syncthing";    Host="$ConfigRoot/jellyfin/web";              Ct="/data/jellyfin-theme";     Type="Theme share rw" }
        @{ Svc="healthguard";  Host="$BaseDir";                              Ct="/mediastack";              Type="Logs+scripts"   }
        @{ Svc="healthguard";  Host="/var/run/docker.sock";                   Ct="/var/run/docker.sock";     Type="Docker socket"  }
        @{ Svc="db-init";      Host="$ConfigRoot (ro)";                       Ct="/opt/mediastack/config";   Type="Backup src :ro" }
        @{ Svc="db-init";      Host="$BaseDir";                              Ct="/mediastack";              Type="Backup target"  }
    )

    $lastSvc = ""
    foreach ($m in $maps) {
        if ($m.Svc -ne $lastSvc) {
            NL
            Write-Host ("  >> {0}" -f $m.Svc.ToUpper()) -ForegroundColor Cyan
            $lastSvc = $m.Svc
        }
        $hostDisp = if ($m.Host.Length -gt 29) { $m.Host.Substring(0,27) + ".." } else { $m.Host }
        $ctDisp   = if ($m.Ct.Length   -gt 27) { $m.Ct.Substring(0,25)   + ".." } else { $m.Ct   }
        $tCol = switch -Wildcard ($m.Type) {
            "*SQLite*"  { "Yellow"   }
            "*volume*"  { "Magenta"  }
            "*NAS*"     { "DarkCyan" }
            "*socket*"  { "Red"      }
            "*RAM*"     { "Green"    }
            default     { "DarkGray" }
        }
        Write-Host ("    {0,-30} {1,-28} " -f $hostDisp, $ctDisp) -ForegroundColor DarkGray -NoNewline
        Write-Host $m.Type -ForegroundColor $tCol
    }
    NL
    Ln DarkGray
    NL
    Write-Host "  SQLite DB files: radarr.db  sonarr.db  prowlarr.db  jellyfin.db  (inside /config)" -ForegroundColor DarkGray
    Write-Host "  Backups:  $BaseDir\backups\<timestamp>\  (created by db-init every start)" -ForegroundColor DarkGray
    NL
}

# == Live Status Table ==========================================================
function Show-Status {
    param([int]$WaitSecs = 8)
    NL
    Write-Host "  >> CONTAINER STATUS" -ForegroundColor Cyan -NoNewline
    if ($WaitSecs -gt 0) {
        Write-Host "  (polling in ${WaitSecs}s...)" -ForegroundColor DarkGray
        Start-Sleep $WaitSecs
    } else { NL }

    $jsonLines = docker compose @COMPOSE_FILES ps --format json 2>$null
    if (-not $jsonLines -or $jsonLines.Length -eq 0) {
        $jsonLines = docker compose ps --format json 2>$null
    }
    if (-not $jsonLines) { Warn "No containers found -- is the stack running?"; return }

    Ln DarkGray
    Write-Host ("  {0,-24} {1,-34} {2,-18} {3}" -f "CONTAINER", "STATUS", "HEALTH", "ROLE") -ForegroundColor DarkGray
    Ln DarkGray

    foreach ($line in $jsonLines) {
        if ([string]::IsNullOrWhiteSpace($line)) { continue }
        try {
            $obj = $line | ConvertFrom-Json
            $name   = if ($obj.Name) { $obj.Name } elseif ($obj.Service) { $obj.Service } else { "container" }
            $status = if ($obj.Status) { $obj.Status } else { $obj.State }
            $health = if ($obj.Health) { $obj.Health } else { "" }

            $statusColor = switch -Wildcard ($status) {
                "Up*"     { "Green"   }
                "Exited*" { if ($name -match "db-init") { "DarkGray" } else { "Red" } }
                default   { "Yellow"  }
            }
            $healthIcon = switch ($health) {
                "healthy"   { "[OK] healthy"    }
                "unhealthy" { "[X]  unhealthy"  }
                "starting"  { "[..] starting"   }
                ""          { if ($name -match "db-init") { "[OK] exited (normal)" } else { "--" } }
                default     { $health }
            }
            $healthColor = switch ($health) {
                "healthy"   { "Green"    }
                "unhealthy" { "Red"      }
                "starting"  { "Yellow"   }
                default     { "DarkGray" }
            }
            $role = switch -Wildcard ($name) {
                "*db-init*"      { "one-shot initialiser"   }
                "*healthguard*"  { "self-heal daemon"        }
                "*watchtower*"   { "auto-update daemon"      }
                "*caddy*"        { "reverse proxy"           }
                "*jellyfin*"     { "media server"            }
                "*radarr*"       { "movie automation"        }
                "*sonarr*"       { "tv automation"           }
                "*prowlarr*"     { "indexer manager"         }
                "*bazarr*"       { "subtitle manager"        }
                "*jellyseerr*"   { "media requests"          }
                "*transmission*" { "torrent client"          }
                "*tvheadend*"    { "TV stream + EPG"         }
                "*syncthing*"    { "file sync + theming"     }
                "*api-gateway*"  { "microservice REST proxy" }
                "*mediastack-db*"{ "SQLite web explorer"     }
                default          { "" }
            }
            Write-Host ("  {0,-24}" -f $name)        -ForegroundColor White       -NoNewline
            Write-Host ("{0,-34}" -f $status)         -ForegroundColor $statusColor -NoNewline
            Write-Host ("{0,-18}" -f $healthIcon)     -ForegroundColor $healthColor -NoNewline
            Write-Host $role                          -ForegroundColor DarkGray
        } catch { }
    }
    Ln DarkGray
    NL
}

# == Connectivity Diagnostics ===================================================
function Show-ConnectivityReport {
    param([string]$Domain)
    Hdr "CONNECTIVITY DIAGNOSTICS" Cyan

    # Ping checks
    $checks = @(
        @{ Label="Internet (Google DNS)";  Host="8.8.8.8";        Desc="outbound internet"         }
        @{ Label="External Domain";        Host=$Domain;           Desc="CADDY_DOMAIN target"       }
        @{ Label="Media NAS (primary)";    Host="VoltaireUn"; Desc='\\VoltaireUn\MediaStack-*'  }
    )
    foreach ($c in $checks) {
        if ([string]::IsNullOrWhiteSpace($c.Host)) { continue }
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
    Write-Host "  Port probes (localhost -- are services accepting connections?):" -ForegroundColor DarkGray
    Ln DarkGray
    $ports = @(
        @{ Name="Caddy HTTP";    Port=80   }
        @{ Name="Caddy HTTPS";   Port=443  }
        @{ Name="Jellyfin";      Port=8096 }
        @{ Name="Prowlarr";      Port=9696 }
        @{ Name="Radarr";        Port=7878 }
        @{ Name="Sonarr";        Port=8989 }
        @{ Name="Transmission";  Port=9091 }
        @{ Name="TVHeadend";     Port=9981 }
        @{ Name="TVHeadend (HTSP)"; Port=9982 }
        @{ Name="Syncthing";     Port=8384 }
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
    DLn Cyan 74
    NL
}

# == healthguard Log Tail =======================================================
function Show-HealthguardStatus {
    Hdr "HEALTHGUARD SUMMARY" Cyan
    $logPath = Join-Path $BaseDir "logs\healthguard.log"
    if (Test-Path $logPath) {
        $lines = Get-Content $logPath -Tail 12
        foreach ($l in $lines) {
            $col = switch -Wildcard ($l) {
                "*CRITICAL*" { "Red"      }
                "*ERROR*"    { "Red"      }
                "*WARN*"     { "Yellow"   }
                "*ACTION*"   { "Cyan"     }
                "*RECOVER*"  { "Magenta"  }
                default      { "DarkGray" }
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

# == Quick-Access Service Links =================================================
function Show-AccessLinks {
    param([string]$Domain)
    Hdr "ACCESS YOUR SERVICES" Cyan
    $links = @(
        @{ Icon="[>]"; Label="Jellyfin (main)";  Url="http://$Domain";                     Note="All media"    }
        @{ Icon="[*]"; Label="Prowlarr";          Url="http://prowlarr.$Domain";            Note="Indexers"     }
        @{ Icon="[*]"; Label="Radarr";            Url="http://radarr.$Domain";              Note="Movies"       }
        @{ Icon="[*]"; Label="Sonarr";            Url="http://sonarr.$Domain";              Note="TV shows"     }
        @{ Icon="[*]"; Label="Transmission";      Url="http://transmission.$Domain";        Note="Torrents"     }
        @{ Icon="[>]"; Label="TVHeadend";         Url="http://tvheadend.$Domain   (:9981)"; Note="Live TV + DVR"  }
        @{ Icon="[~]"; Label="Syncthing";         Url="http://syncthing.$Domain  (:8384)";  Note="File sync"    }
    )
    foreach ($l in $links) {
        Write-Host ("  {0}  {1,-22}" -f $l.Icon, $l.Label) -ForegroundColor White -NoNewline
        Write-Host ("{0,-52}" -f $l.Url)                    -ForegroundColor Cyan  -NoNewline
        Write-Host $l.Note                                  -ForegroundColor DarkGray
    }
    NL
}

# == Quick Commands =============================================================
function Show-Commands {
    Hdr "QUICK COMMANDS" Cyan
    $cmds = @(
        @{ Cmd = ".\start-x64.ps1 ps";               Desc = "Live container status + healthguard tail" }
        @{ Cmd = ".\start-x64.ps1 logs";             Desc = "Tail all service logs" }
        @{ Cmd = ".\start-x64.ps1 down";             Desc = "Stop the entire stack" }
        @{ Cmd = ".\start-x64.ps1 restart";          Desc = "Stop then start all services" }
        @{ Cmd = ".\start-x64.ps1 up -Build";        Desc = "Pull fresh images then start" }
        @{ Cmd = ".\start-x64.ps1 up -NoDiag";       Desc = "Start without diagnostics/db map" }
        @{ Cmd = ".\start-x64.ps1 diag";             Desc = "Run full diagnostics + db map standalone" }
        @{ Cmd = "docker compose logs -f db-init";    Desc = "View startup backup + health report" }
        @{ Cmd = "docker compose logs -f healthguard"; Desc = "Live self-heal event stream" }
    )
    foreach ($c in $cmds) {
        Write-Host "  " -NoNewline
        Write-Host $c.Cmd.PadRight(46) -ForegroundColor Cyan -NoNewline
        Write-Host $c.Desc             -ForegroundColor DarkGray
    }
    NL
    DLn Cyan 74
    NL
}

# ==============================================================================
# Main Dispatch
# ==============================================================================
Show-Banner

# Architecture guard
$procArch = $env:PROCESSOR_ARCHITECTURE
if ($procArch -match "ARM" -and -not $Force -and $Command -notin @("ps", "diag", "logs", "status")) {
    Warn "ARM architecture detected ($procArch). The x64 profile targets x86-64 hardware."
    $answer = Read-Host "  Continue with x64 profile anyway? (y/N)"
    if ($answer -notmatch "^[Yy]$") { Info "Tip: use .\start-arm.ps1 for this device."; exit 0 }
} else {
    Ok "Architecture : $procArch"
}

# Load .env values
$envDomain     = Get-EnvVal "CADDY_DOMAIN"        "media.local"
$configRoot    = Get-EnvVal "CONFIG_ROOT"          "$BaseDir/config"
$downloadRoot  = Get-EnvVal "DOWNLOAD_ROOT"        "$BaseDir/downloads"
$musicRoot     = Get-EnvVal "MUSIC_ROOT"           "$BaseDir/Music"
$mediaRoot     = Get-EnvVal "MEDIA_ROOT"           "$BaseDir"
$watchtowerSch = Get-EnvVal "WATCHTOWER_SCHEDULE"  "0 0 4 * * *"

Ok "Domain       : http://$envDomain"
Ok "Config root  : $configRoot"
Ok "Watchtower   : $watchtowerSch"
NL

switch ($Command.ToLower()) {

    "up" {
        Show-Services -Domain $envDomain

        if (-not $NoDiag) {
            Show-EnvSummary   -Domain $envDomain -ConfigRoot $configRoot `
                              -DownloadRoot $downloadRoot -MusicRoot $musicRoot -MediaRoot $mediaRoot
            Show-DatabaseMap  -ConfigRoot $configRoot -DownloadRoot $downloadRoot -MusicRoot $musicRoot
        }

        if ($Build) {
            Info "Pulling latest images first..."
            docker compose @COMPOSE_FILES pull
            NL
        }

        Info "Launching MediaStack x64..."
        NL
        docker compose @COMPOSE_FILES up -d
        NL

        if ($LASTEXITCODE -ne 0) {
            Err "docker compose up exited with code $LASTEXITCODE"
            exit $LASTEXITCODE
        }

        Ok "Stack is up -- services are initialising!"

        if (-not $NoWait) { Show-Status -WaitSecs 8 }

        Show-AccessLinks -Domain $envDomain

        if (-not $NoDiag) {
            Show-ConnectivityReport -Domain $envDomain
            Show-HealthguardStatus
        }

        Show-Commands
    }

    "down" {
        Info "Stopping MediaStack x64..."
        docker compose @COMPOSE_FILES down
        Ok "Stack stopped."
        NL
    }

    "restart" {
        Info "Restarting MediaStack x64..."
        docker compose @COMPOSE_FILES down
        NL
        docker compose @COMPOSE_FILES up -d
        if ($LASTEXITCODE -eq 0) {
            if (-not $NoWait) { Show-Status -WaitSecs 8 }
            Show-ConnectivityReport -Domain $envDomain
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
        Info "Pulling latest x64 images..."
        docker compose @COMPOSE_FILES pull
        Ok "Images updated. Run '.\start-x64.ps1 restart' to apply."
        NL
    }

    "diag" {
        Show-EnvSummary    -Domain $envDomain -ConfigRoot $configRoot `
                           -DownloadRoot $downloadRoot -MusicRoot $musicRoot -MediaRoot $mediaRoot
        Show-DatabaseMap   -ConfigRoot $configRoot -DownloadRoot $downloadRoot -MusicRoot $musicRoot
        Show-Status        -WaitSecs 0
        Show-ConnectivityReport -Domain $envDomain
        Show-HealthguardStatus
        Show-Commands
    }

    default {
        docker compose @COMPOSE_FILES $Command @args
    }
}

