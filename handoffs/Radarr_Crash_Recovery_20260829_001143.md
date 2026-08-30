# Radarr Crash Recovery & Fresh Image Rebuild Report

| Parameter | Value |
| :--- | :--- |
| **Timestamp** | 2026-08-29 00:11:43 |
| **Host System** | VOLTAIREDEUX |
| **Trigger Reason** | Explicit Forced Repair Request |
| **Image Downloaded** | `lscr.io/linuxserver/radarr:latest` |
| **Database Status** | OK |
| **Post-Recovery Health** | ONLINE (HTTP 200 OK) |

---

## Crash Logs Snapshot (Pre-Recovery)
``text
Radarr: https://opencollective.com/radarr

To support LSIO projects visit:
https://www.linuxserver.io/donate/

───────────────────────────────────────
GID/UID
───────────────────────────────────────

User UID:    1000
User GID:    1000
───────────────────────────────────────
Linuxserver.io version: 6.3.0.10514-ls313
Build-date: 2026-08-02T17:49:44+00:00
───────────────────────────────────────
    
[custom-init] No custom files found, skipping...
[Info] Bootstrap: Starting Radarr - /app/radarr/bin/Radarr - Version 6.3.0.10514 
[Info] AppFolderInfo: Data directory is being overridden to [/config] 
[Debug] Bootstrap: Console selected 
[Info] AppFolderInfo: Data directory is being overridden to [/config] 
[Info] AppFolderInfo: Data directory is being overridden to [/config] 
[Info] MigrationController: *** Migrating data source=/config/radarr.db;cache size=-20000;datetimekind=Utc;journal mode=Wal;pooling=True;version=3;busytimeout=1000 *** 
[Info] FluentMigrator.Runner.MigrationRunner: DatabaseEngineVersionCheck migrating 
[Info] FluentMigrator.Runner.MigrationRunner: PerformDBOperation  
[Info] NzbDrone.Core.Datastore.Migration.Framework.NzbDroneSQLiteProcessor: Performing DB Operation 
[Info] DatabaseEngineVersionCheck: SQLite 3.50.4 
[Info] FluentMigrator.Runner.MigrationRunner: => 0.1360021s 
[Info] FluentMigrator.Runner.MigrationRunner: DatabaseEngineVersionCheck migrated 
[Info] FluentMigrator.Runner.MigrationRunner: => 0.1895652s 
[Info] MigrationController: *** Migrating data source=/config/logs.db;cache size=-20000;datetimekind=Utc;journal mode=Wal;pooling=True;version=3;busytimeout=1000 *** 
[Info] FluentMigrator.Runner.MigrationRunner: DatabaseEngineVersionCheck migrating 
[Info] FluentMigrator.Runner.MigrationRunner: PerformDBOperation  
[Info] NzbDrone.Core.Datastore.Migration.Framework.NzbDroneSQLiteProcessor: Performing DB Operation 
[Info] DatabaseEngineVersionCheck: SQLite 3.50.4 
[Info] FluentMigrator.Runner.MigrationRunner: => 0.1282606s 
[Info] FluentMigrator.Runner.MigrationRunner: DatabaseEngineVersionCheck migrated 
[Info] FluentMigrator.Runner.MigrationRunner: => 0.1898242s 
[Info] Microsoft.Hosting.Lifetime: Now listening on: http://[::]:7878 
[ls.io-init] done.
[Info] CommandExecutor: Starting 2 threads for tasks. 
[Info] Radarr.Http.Authentication.ApiKeyAuthenticationHandler: AuthenticationScheme: API was challenged. 
[Info] Microsoft.Hosting.Lifetime: Application started. Press Ctrl+C to shut down. 
[Info] Microsoft.Hosting.Lifetime: Hosting environment: Production 
[Info] ManagedHttpDispatcher: IPv4 is available: True, IPv6 will be disabled 
[Info] Microsoft.Hosting.Lifetime: Content root path: /app/radarr/bin 
[Info] RssSyncService: Starting RSS Sync 
[Info] RecycleBinProvider: Recycle Bin has not been configured, cannot cleanup. 
[Info] HousekeepingService: Running housecleaning tasks 
[Warn] FetchAndParseRssService: No available indexers. check your configuration. 
[Info] DownloadDecisionMaker: No results found 
[Info] RssSyncService: RSS Sync Completed. Reports found: 0, Reports grabbed: 0 
[Info] Database: Vacuuming Log database 
[Info] Database: Log database compressed 
[Info] Database: Vacuuming Main database 
[Info] Database: Main database compressed 
[Info] RssSyncService: Starting RSS Sync 
[Warn] FetchAndParseRssService: No available indexers. check your configuration. 
[Info] DownloadDecisionMaker: No results found 
[Info] RssSyncService: RSS Sync Completed. Reports found: 0, Reports grabbed: 0 

``

---
*Report generated automatically by Radarr Crash Recovery Engine.*
