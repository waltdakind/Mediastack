# Expert Operational Handoff: Radarr Movies Manager

| Architectural Parameter | Runtime Specification |
| :--- | :--- |
| **Service Key** | radarr |
| **Display Name** | Radarr Movies Manager |
| **Service Category** | Servarr |
| **Container Name** | radarr |
| **Image Tag** | lscr.io/linuxserver/radarr:latest |
| **Primary Ingress Port** | 7878 |
| **Associated Storage/DB**| radarr.db |
| **Container Status** | **RUNNING** |
| **Restart Count** | 0 |
| **Container Started** | 2026-09-01T20:07:40.191988534Z |
| **L7 Response Code** | HTTP 302 |
| **TTFB Latency** | 86.8 ms |
| **Vault Secrets Status**| SECURED IN VAULT |
| **Error Lines Detected**| 2 |
| **Audit Timestamp** | 2026-09-01 17:53:17 |

---

## 1. Network & Reverse-Proxy Topology
- **Local Ingress Endpoint:** `http://localhost:7878/`
- **Caddy Virtual Host Route:** `http://radarr.voltairedeux.local/`
- **Peer Cluster Gateway:** `http://192.168.4.30:7878/`
- **Security Policy:** TLS 1.3 / Reverse-Proxy Ingress isolated via Caddy network.

---

## 2. Storage & Database Layout
- **Host Config Root:** `C:\MediastackConfig\radarr`
- **Active Database File:** `radarr.db`
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
   at System.Data.SQLite.SQLiteDataReader.NextResult()    at System.Data.SQLite.SQLiteDataReader..ctor(SQLiteCommand cmd, CommandBehavior behave)    at System.Data.SQLite.SQLiteCommand.ExecuteNonQuery(CommandBehavior behavior)    at System.Data.SQLite.SQLiteConnection.Open()    at NzbDrone.Core.Datastore.BasicRepository`1.Insert(TModel model) in ./NzbDrone.Core/Datastore/BasicRepository.cs:line 168    at NzbDrone.Core.Messaging.Commands.CommandQueueManager.Push[TCommand](TCommand command, CommandPriority priority, CommandTrigger trigger) in ./NzbDrone.Core/Messaging/Commands/CommandQueueManager.cs:line 135    at NzbDrone.Core.Jobs.Scheduler.ExecuteCommands() in ./NzbDrone.Core/Jobs/Scheduler.cs:line 34    at System.Threading.ExecutionContext.RunFromThreadPoolDispatchLoop(Thread threadPoolThread, ExecutionContext executionContext, ContextCallback callback, Object state) --- End of stack trace from previous location ---    at System.Threading.ExecutionContext.RunFromThreadPoolDispatchLoop(Thread threadPoolThread, ExecutionContext executionContext, ContextCallback callback, Object state)    at System.Threading.Tasks.Task.ExecuteWithThreadLocal(Task& currentTaskSlot, Thread threadPoolThread)   [Error] TaskExtensions: Task Error   [v6.3.0.10514] code = NotADb (26), message = System.Data.SQLite.SQLiteException (0x87AF0570): file is not a database file is not a database    at System.Data.SQLite.SQLite3.Prepare(SQLiteConnection cnn, SQLiteCommand command, String strSql, SQLiteStatement previous, UInt32 timeoutMS, String& strRemain)    at System.Data.SQLite.SQLiteCommand.BuildNextCommand()    at System.Data.SQLite.SQLiteDataReader.NextResult()    at System.Data.SQLite.SQLiteDataReader..ctor(SQLiteCommand cmd, CommandBehavior behave)    at System.Data.SQLite.SQLiteCommand.ExecuteNonQuery(CommandBehavior behavior)    at System.Data.SQLite.SQLiteConnection.Open()    at NzbDrone.Core.Datastore.BasicRepository`1.Insert(TModel model) in ./NzbDrone.Core/Datastore/BasicRepository.cs:line 168    at NzbDrone.Core.Messaging.Commands.CommandQueueManager.Push[TCommand](TCommand command, CommandPriority priority, CommandTrigger trigger) in ./NzbDrone.Core/Messaging/Commands/CommandQueueManager.cs:line 135    at NzbDrone.Core.Jobs.Scheduler.ExecuteCommands() in ./NzbDrone.Core/Jobs/Scheduler.cs:line 34    at System.Threading.ExecutionContext.RunFromThreadPoolDispatchLoop(Thread threadPoolThread, ExecutionContext executionContext, ContextCallback callback, Object state) --- End of stack trace from previous location ---    at System.Threading.ExecutionContext.RunFromThreadPoolDispatchLoop(Thread threadPoolThread, ExecutionContext executionContext, ContextCallback callback, Object state)    at System.Threading.Tasks.Task.ExecuteWithThreadLocal(Task& currentTaskSlot, Thread threadPoolThread)   [Info] RssSyncService: Starting RSS Sync  [Warn] FetchAndParseRssService: No available indexers. check your configuration.  [Info] DownloadDecisionMaker: No results found  [Info] RssSyncService: RSS Sync Completed. Reports found: 0, Reports grabbed: 0  [Info] RssSyncService: Starting RSS Sync  [Warn] FetchAndParseRssService: No available indexers. check your configuration.  [Info] DownloadDecisionMaker: No results found  [Info] RssSyncService: RSS Sync Completed. Reports found: 0, Reports grabbed: 0 
`

---

## 5. Architectural Recommendations & Maintenance Tips
1. **Auto-Recovery:** If degraded, execute `.\Repair-radarr.ps1` or `.\Repair-MediaStackFleet.ps1 -Service Servarr`.
2. **Backup Strategy:** Included in atomic hot backup snapshot via `.\Backup-MediaStackFleet.ps1`.
3. **Replication Strategy:** Synchronized across Voltaire nodes via `.\Replicate-MediaStackCluster.ps1`.

---
*Generated autonomously by MediaStack Deep Analysis Engine.*
