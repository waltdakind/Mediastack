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
| **Container Started** | 2026-09-05T15:08:57.8165909Z |
| **L7 Response Code** | HTTP 302 |
| **TTFB Latency** | 183.4 ms |
| **Vault Secrets Status**| SYSTEM MANAGED |
| **Error Lines Detected**| 2 |
| **Audit Timestamp** | 2026-09-05 12:09:46 |

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
   at System.Net.Sockets.Socket.AwaitableSocketAsyncEventArgs.ThrowException(SocketError error, CancellationToken cancellationToken)
   at System.Net.Sockets.Socket.AwaitableSocketAsyncEventArgs.System.Threading.Tasks.Sources.IValueTaskSource.GetResult(Int16 token)
   at System.Net.Sockets.Socket.<ConnectAsync>g__WaitForConnectWithCancellation|285_0(AwaitableSocketAsyncEventArgs saea, ValueTask connectTask, CancellationToken cancellationToken)
   at NzbDrone.Common.Http.Dispatchers.ManagedHttpDispatcher.attemptConnection(AddressFamily addressFamily, SocketsHttpConnectionContext context, CancellationToken cancellationToken) in ./NzbDrone.Common/Http/Dispatchers/ManagedHttpDispatcher.cs:line 326
   at NzbDrone.Common.Http.Dispatchers.ManagedHttpDispatcher.onConnect(SocketsHttpConnectionContext context, CancellationToken cancellationToken) in ./NzbDrone.Common/Http/Dispatchers/ManagedHttpDispatcher.cs:line 312
   at System.Net.Http.HttpConnectionPool.ConnectToTcpHostAsync(String host, Int32 port, HttpRequestMessage initialRequest, Boolean async, CancellationToken cancellationToken)
   --- End of inner exception stack trace ---
   at System.Net.Http.HttpConnectionPool.ConnectToTcpHostAsync(String host, Int32 port, HttpRequestMessage initialRequest, Boolean async, CancellationToken cancellationToken)
   at System.Net.Http.HttpConnectionPool.ConnectAsync(HttpRequestMessage request, Boolean async, CancellationToken cancellationToken)
   at System.Net.Http.HttpConnectionPool.CreateHttp11ConnectionAsync(HttpRequestMessage request, Boolean async, CancellationToken cancellationToken)
   at System.Net.Http.HttpConnectionPool.AddHttp11ConnectionAsync(QueueItem queueItem)
   at System.Threading.Tasks.TaskCompletionSourceWithCancellation`1.WaitWithCancellationAsync(CancellationToken cancellationToken)
   at System.Net.Http.HttpConnectionPool.SendWithVersionDetectionAndRetryAsync(HttpRequestMessage request, Boolean async, Boolean doRequestAuth, CancellationToken cancellationToken)
   at System.Net.Http.AuthenticationHelper.SendWithAuthAsync(HttpRequestMessage request, Uri authUri, Boolean async, ICredentials credentials, Boolean preAuthenticate, Boolean isProxyAuth, Boolean doRequestAuth, HttpConnectionPool pool, CancellationToken cancellationToken)
   at System.Net.Http.DecompressionHandler.SendAsync(HttpRequestMessage request, Boolean async, CancellationToken cancellationToken)
   at System.Net.Http.HttpClient.<SendAsync>g__Core|83_0(HttpRequestMessage request, HttpCompletionOption completionOption, CancellationTokenSource cts, Boolean disposeCts, CancellationTokenSource pendingRequestsCts, CancellationToken originalCancellationToken)
   at NzbDrone.Common.Http.Dispatchers.ManagedHttpDispatcher.GetResponseAsync(HttpRequest request, CookieContainer cookies) in ./NzbDrone.Common/Http/Dispatchers/ManagedHttpDispatcher.cs:line 115
   at NzbDrone.Common.Http.HttpClient.ExecuteRequestAsync(HttpRequest request, CookieContainer cookieContainer) in ./NzbDrone.Common/Http/HttpClient.cs:line 157
   at NzbDrone.Common.Http.HttpClient.ExecuteAsync(HttpRequest request) in ./NzbDrone.Common/Http/HttpClient.cs:line 70
   at NzbDrone.Core.Download.Clients.Transmission.TransmissionProxy.ProcessRequest(String action, Object arguments, TransmissionSettings settings) in ./NzbDrone.Core/Download/Clients/Transmission/TransmissionProxy.cs:line 330
   at NzbDrone.Core.Download.Clients.Transmission.TransmissionProxy.GetTorrentStatus(IEnumerable`1 hashStrings, TransmissionSettings settings) in ./NzbDrone.Core/Download/Clients/Transmission/TransmissionProxy.cs:line 242
   at NzbDrone.Core.Download.Clients.Transmission.TransmissionBase.GetItems() in ./NzbDrone.Core/Download/Clients/Transmission/TransmissionBase.cs:line 42
   at NzbDrone.Core.Download.TrackedDownloads.DownloadMonitoringService.ProcessClientDownloads(IDownloadClient downloadClient) in ./NzbDrone.Core/Download/TrackedDownloads/DownloadMonitoringService.cs:line 94



`

---

## 5. Architectural Recommendations & Maintenance Tips
1. **Auto-Recovery:** If degraded, execute `.\Repair-radarr.ps1` or `.\Repair-MediaStackFleet.ps1 -Service Servarr`.
2. **Backup Strategy:** Included in atomic hot backup snapshot via `.\Backup-MediaStackFleet.ps1`.
3. **Replication Strategy:** Synchronized across Voltaire nodes via `.\Replicate-MediaStackCluster.ps1`.

---
*Generated autonomously by MediaStack Deep Analysis Engine.*
