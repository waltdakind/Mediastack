# Expert Operational Handoff: Sonarr TV Series Manager

| Architectural Parameter | Runtime Specification |
| :--- | :--- |
| **Service Key** | sonarr |
| **Display Name** | Sonarr TV Series Manager |
| **Service Category** | Servarr |
| **Container Name** | sonarr |
| **Image Tag** | lscr.io/linuxserver/sonarr:latest |
| **Primary Ingress Port** | 8989 |
| **Associated Storage/DB**| sonarr.db |
| **Container Status** | **RUNNING** |
| **Restart Count** | 0 |
| **Container Started** | 2026-08-31T23:38:20.454072494Z |
| **L7 Response Code** | HTTP 401 |
| **TTFB Latency** | 22.5 ms |
| **Vault Secrets Status**| SECURED IN VAULT |
| **Error Lines Detected**| 2 |
| **Audit Timestamp** | 2026-08-31 20:00:15 |

---

## 1. Network & Reverse-Proxy Topology
- **Local Ingress Endpoint:** `http://localhost:8989/`
- **Caddy Virtual Host Route:** `http://sonarr.voltairedeux.local/`
- **Peer Cluster Gateway:** `http://192.168.4.30:8989/`
- **Security Policy:** TLS 1.3 / Reverse-Proxy Ingress isolated via Caddy network.

---

## 2. Storage & Database Layout
- **Host Config Root:** `C:\MediastackConfig\sonarr`
- **Active Database File:** `sonarr.db`
- **Persistent Media Mounts:** `C:\MediastackShares\` (Music, TV, Videos, Radio, Podcasts)
- **Lock Management:** SQLite WAL with zero-downtime checkpoints.

---

## 3. Inter-Service Handshake Matrix
- **Upstream Gateway:** Caddy Reverse Proxy (`caddy:80/443`)
- **Downstream Dependencies:** `mediastack-db`, `redis`, `postgres`
- **Cluster Peer Target:** VoltaireUn (`192.168.4.21`) via reciprocal SMB & Syncthing mesh.

---

## 4. Diagnostic Log Mining & Health Assessment
### Log Extraction (Last 40 Lines)
`	ext
[custom-init] No custom files found, skipping... [Info] Bootstrap: Starting Sonarr - /app/sonarr/bin/Sonarr - Version 4.0.19.2979  [Info] AppFolderInfo: Data directory is being overridden to [/config]  [Debug] Bootstrap: Console selected  [Info] AppFolderInfo: Data directory is being overridden to [/config]  [Info] AppFolderInfo: Data directory is being overridden to [/config]  [Info] MigrationController: *** Migrating data source=/config/sonarr.db;cache size=-20000;datetimekind=Utc;journal mode=Wal;pooling=True;version=3;busytimeout=100 ***  [Info] FluentMigrator.Runner.MigrationRunner: DatabaseEngineVersionCheck migrating  [Info] FluentMigrator.Runner.MigrationRunner: PerformDBOperation   [Info] NzbDrone.Core.Datastore.Migration.Framework.NzbDroneSQLiteProcessor: Performing DB Operation  [Info] DatabaseEngineVersionCheck: SQLite 3.53.2  [Info] FluentMigrator.Runner.MigrationRunner: => 0.2370752s  [Info] FluentMigrator.Runner.MigrationRunner: DatabaseEngineVersionCheck migrated  [Info] FluentMigrator.Runner.MigrationRunner: => 0.2560675s  [Info] MigrationController: *** Migrating data source=/config/logs.db;cache size=-20000;datetimekind=Utc;journal mode=Wal;pooling=True;version=3;busytimeout=100 ***  [Info] FluentMigrator.Runner.MigrationRunner: DatabaseEngineVersionCheck migrating  [Info] FluentMigrator.Runner.MigrationRunner: PerformDBOperation   [Info] NzbDrone.Core.Datastore.Migration.Framework.NzbDroneSQLiteProcessor: Performing DB Operation  [Info] DatabaseEngineVersionCheck: SQLite 3.53.2  [Info] FluentMigrator.Runner.MigrationRunner: => 0.0329455s  [Info] FluentMigrator.Runner.MigrationRunner: DatabaseEngineVersionCheck migrated  [Info] FluentMigrator.Runner.MigrationRunner: => 0.041468s  [Info] Microsoft.Hosting.Lifetime: Now listening on: http://[::]:8989  [ls.io-init] done. [Info] Microsoft.Hosting.Lifetime: Application started. Press Ctrl+C to shut down.  [Info] Microsoft.Hosting.Lifetime: Hosting environment: Production  [Info] Microsoft.Hosting.Lifetime: Content root path: /app/sonarr/bin  [Info] ManagedHttpDispatcher: IPv4 is available: True, IPv6 will be disabled  [Info] RssSyncService: Starting RSS Sync  [Warn] FetchAndParseRssService: No available indexers. check your configuration.  [Info] DownloadDecisionMaker: No results found  [Info] RssSyncService: RSS Sync Completed. Reports found: 0, Reports grabbed: 0  [Info] RssSyncService: Starting RSS Sync  [Warn] FetchAndParseRssService: No available indexers. check your configuration.  [Info] DownloadDecisionMaker: No results found  [Info] RssSyncService: RSS Sync Completed. Reports found: 0, Reports grabbed: 0  [Info] Sonarr.Http.Authentication.BasicAuthenticationHandler: Basic was not authenticated. Failure message: Authorization header missing.  [Info] Sonarr.Http.Authentication.BasicAuthenticationHandler: AuthenticationScheme: Basic was challenged.  [Info] Sonarr.Http.Authentication.BasicAuthenticationHandler: Basic was not authenticated. Failure message: Authorization header missing.  [Info] Sonarr.Http.Authentication.BasicAuthenticationHandler: AuthenticationScheme: Basic was challenged. 
`

---

## 5. Architectural Recommendations & Maintenance Tips
1. **Auto-Recovery:** If degraded, execute `.\Repair-sonarr.ps1` or `.\Repair-MediaStackFleet.ps1 -Service Servarr`.
2. **Backup Strategy:** Included in atomic hot backup snapshot via `.\Backup-MediaStackFleet.ps1`.
3. **Replication Strategy:** Synchronized across Voltaire nodes via `.\Replicate-MediaStackCluster.ps1`.

---
*Generated autonomously by MediaStack Deep Analysis Engine.*
