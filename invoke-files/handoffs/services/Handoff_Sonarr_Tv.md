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
| **Container Started** | 2026-09-05T15:08:57.8554566Z |
| **L7 Response Code** | HTTP 401 |
| **TTFB Latency** | 150.4 ms |
| **Vault Secrets Status**| SYSTEM MANAGED |
| **Error Lines Detected**| 1 |
| **Audit Timestamp** | 2026-09-05 12:09:46 |

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
   --- End of inner exception stack trace ---
   at System.Net.Http.HttpConnectionPool.ConnectToTcpHostAsync(String host, Int32 port, HttpRequestMessage initialRequest, Boolean async, CancellationToken cancellationToken)
   at System.Net.Http.HttpConnectionPool.ConnectAsync(HttpRequestMessage request, Boolean async, CancellationToken cancellationToken)
   at System.Net.Http.HttpConnectionPool.CreateHttp11ConnectionAsync(HttpRequestMessage request, Boolean async, CancellationToken cancellationToken)
   at System.Net.Http.HttpConnectionPool.AddHttp11ConnectionAsync(HttpRequestMessage request)
   at System.Threading.Tasks.TaskCompletionSourceWithCancellation`1.WaitWithCancellationAsync(CancellationToken cancellationToken)
   at System.Net.Http.HttpConnectionPool.GetHttp11ConnectionAsync(HttpRequestMessage request, Boolean async, CancellationToken cancellationToken)
   at System.Net.Http.HttpConnectionPool.SendWithVersionDetectionAndRetryAsync(HttpRequestMessage request, Boolean async, Boolean doRequestAuth, CancellationToken cancellationToken)
   at System.Net.Http.AuthenticationHelper.SendWithAuthAsync(HttpRequestMessage request, Uri authUri, Boolean async, ICredentials credentials, Boolean preAuthenticate, Boolean isProxyAuth, Boolean doRequestAuth, HttpConnectionPool pool, CancellationToken cancellationToken)
   at System.Net.Http.DecompressionHandler.SendAsync(HttpRequestMessage request, Boolean async, CancellationToken cancellationToken)
   at System.Net.Http.HttpClient.<SendAsync>g__Core|83_0(HttpRequestMessage request, HttpCompletionOption completionOption, CancellationTokenSource cts, Boolean disposeCts, CancellationTokenSource pendingRequestsCts, CancellationToken originalCancellationToken)
   at NzbDrone.Common.Http.Dispatchers.ManagedHttpDispatcher.GetResponseAsync(HttpRequest request, CookieContainer cookies) in ./Sonarr.Common/Http/Dispatchers/ManagedHttpDispatcher.cs:line 115
   at NzbDrone.Common.Http.HttpClient.ExecuteRequestAsync(HttpRequest request, CookieContainer cookieContainer) in ./Sonarr.Common/Http/HttpClient.cs:line 157
   at NzbDrone.Common.Http.HttpClient.ExecuteAsync(HttpRequest request) in ./Sonarr.Common/Http/HttpClient.cs:line 70
   at NzbDrone.Common.Http.HttpClient.Execute(HttpRequest request) in ./Sonarr.Common/Http/HttpClient.cs:line 128
   at NzbDrone.Core.Download.Clients.Transmission.TransmissionProxy.ProcessRequest(String action, Object arguments, TransmissionSettings settings) in ./Sonarr.Core/Download/Clients/Transmission/TransmissionProxy.cs:line 372
   at NzbDrone.Core.Download.Clients.Transmission.TransmissionProxy.GetTorrentStatus(IEnumerable`1 hashStrings, TransmissionSettings settings) in ./Sonarr.Core/Download/Clients/Transmission/TransmissionProxy.cs:line 205
   at NzbDrone.Core.Download.Clients.Transmission.TransmissionProxy.GetTorrents(IReadOnlyCollection`1 hashStrings, TransmissionSettings settings) in ./Sonarr.Core/Download/Clients/Transmission/TransmissionProxy.cs:line 50
   at NzbDrone.Core.Download.Clients.Transmission.TransmissionBase.GetItems() in ./Sonarr.Core/Download/Clients/Transmission/TransmissionBase.cs:line 43
   at NzbDrone.Core.Download.TrackedDownloads.DownloadMonitoringService.ProcessClientDownloads(IDownloadClient downloadClient) in ./Sonarr.Core/Download/TrackedDownloads/DownloadMonitoringService.cs:line 90

[Info] RssSyncService: Starting RSS Sync 
[Warn] FetchAndParseRssService: No available indexers. check your configuration. 
[Info] DownloadDecisionMaker: No results found 
[Info] RssSyncService: RSS Sync Completed. Reports found: 0, Reports grabbed: 0 

`

---

## 5. Architectural Recommendations & Maintenance Tips
1. **Auto-Recovery:** If degraded, execute `.\Repair-sonarr.ps1` or `.\Repair-MediaStackFleet.ps1 -Service Servarr`.
2. **Backup Strategy:** Included in atomic hot backup snapshot via `.\Backup-MediaStackFleet.ps1`.
3. **Replication Strategy:** Synchronized across Voltaire nodes via `.\Replicate-MediaStackCluster.ps1`.

---
*Generated autonomously by MediaStack Deep Analysis Engine.*
