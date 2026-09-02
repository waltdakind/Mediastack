# Expert Operational Handoff: Jellyfin Streaming Server

| Architectural Parameter | Runtime Specification |
| :--- | :--- |
| **Service Key** | jellyfin |
| **Display Name** | Jellyfin Streaming Server |
| **Service Category** | Streaming |
| **Container Name** | jellyfin |
| **Image Tag** | lscr.io/linuxserver/jellyfin:latest |
| **Primary Ingress Port** | 8096 |
| **Associated Storage/DB**| jellyfin.db |
| **Container Status** | **RUNNING** |
| **Restart Count** | 0 |
| **Container Started** | 2026-09-01T20:07:40.214983852Z |
| **L7 Response Code** | HTTP 302 |
| **TTFB Latency** | 33.8 ms |
| **Vault Secrets Status**| SECURED IN VAULT |
| **Error Lines Detected**| 7 |
| **Audit Timestamp** | 2026-09-01 17:53:17 |

---

## 1. Network & Reverse-Proxy Topology
- **Local Ingress Endpoint:** `http://localhost:8096/`
- **Caddy Virtual Host Route:** `http://jellyfin.voltairedeux.local/`
- **Peer Cluster Gateway:** `http://192.168.4.30:8096/`
- **Security Policy:** TLS 1.3 / Reverse-Proxy Ingress isolated via Caddy network.

---

## 2. Storage & Database Layout
- **Host Config Root:** `C:\MediastackConfig\jellyfin`
- **Active Database File:** `jellyfin.db`
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
   at lambda_method2476(Closure, Object, Object[])    at Microsoft.AspNetCore.Mvc.Infrastructure.ActionMethodExecutor.SyncObjectResultExecutor.Execute(ActionContext actionContext, IActionResultTypeMapper mapper, ObjectMethodExecutor executor, Object controller, Object[] arguments)    at Microsoft.AspNetCore.Mvc.Infrastructure.ControllerActionInvoker.InvokeActionMethodAsync()    at Microsoft.AspNetCore.Mvc.Infrastructure.ControllerActionInvoker.Next(State& next, Scope& scope, Object& state, Boolean& isCompleted)    at Microsoft.AspNetCore.Mvc.Infrastructure.ControllerActionInvoker.InvokeNextActionFilterAsync() --- End of stack trace from previous location ---    at Microsoft.AspNetCore.Mvc.Infrastructure.ControllerActionInvoker.Rethrow(ActionExecutedContextSealed context)    at Microsoft.AspNetCore.Mvc.Infrastructure.ControllerActionInvoker.Next(State& next, Scope& scope, Object& state, Boolean& isCompleted)    at Microsoft.AspNetCore.Mvc.Infrastructure.ControllerActionInvoker.InvokeInnerFilterAsync() --- End of stack trace from previous location ---    at Microsoft.AspNetCore.Mvc.Infrastructure.ResourceInvoker.<InvokeNextResourceFilter>g__Awaited|25_0(ResourceInvoker invoker, Task lastTask, State next, Scope scope, Object state, Boolean isCompleted)    at Microsoft.AspNetCore.Mvc.Infrastructure.ResourceInvoker.Rethrow(ResourceExecutedContextSealed context)    at Microsoft.AspNetCore.Mvc.Infrastructure.ResourceInvoker.Next(State& next, Scope& scope, Object& state, Boolean& isCompleted)    at Microsoft.AspNetCore.Mvc.Infrastructure.ResourceInvoker.InvokeFilterPipelineAsync() --- End of stack trace from previous location ---    at Microsoft.AspNetCore.Mvc.Infrastructure.ResourceInvoker.<InvokeAsync>g__Awaited|17_0(ResourceInvoker invoker, Task task, IDisposable scope)    at Microsoft.AspNetCore.Mvc.Infrastructure.ResourceInvoker.<InvokeAsync>g__Awaited|17_0(ResourceInvoker invoker, Task task, IDisposable scope)    at Jellyfin.Api.Middleware.ServerStartupMessageMiddleware.Invoke(HttpContext httpContext, IServerApplicationHost serverApplicationHost, ILocalizationManager localizationManager)    at Jellyfin.Api.Middleware.WebSocketHandlerMiddleware.Invoke(HttpContext httpContext, IWebSocketManager webSocketManager)    at Jellyfin.Api.Middleware.IPBasedAccessValidationMiddleware.Invoke(HttpContext httpContext, INetworkManager networkManager)    at Microsoft.AspNetCore.Authorization.AuthorizationMiddleware.Invoke(HttpContext context)    at Jellyfin.Api.Middleware.QueryStringDecodingMiddleware.Invoke(HttpContext httpContext)    at Swashbuckle.AspNetCore.ReDoc.ReDocMiddleware.Invoke(HttpContext httpContext)    at Swashbuckle.AspNetCore.SwaggerUI.SwaggerUIMiddleware.Invoke(HttpContext httpContext)    at Swashbuckle.AspNetCore.Swagger.SwaggerMiddleware.Invoke(HttpContext httpContext, ISwaggerProvider swaggerProvider)    at Microsoft.AspNetCore.Authentication.AuthenticationMiddleware.Invoke(HttpContext context)    at Jellyfin.Api.Middleware.RobotsRedirectionMiddleware.Invoke(HttpContext httpContext)    at Jellyfin.Api.Middleware.LegacyEmbyRouteRewriteMiddleware.Invoke(HttpContext httpContext)    at Microsoft.AspNetCore.ResponseCompression.ResponseCompressionMiddleware.InvokeCore(HttpContext context)    at Jellyfin.Api.Middleware.ResponseTimeMiddleware.Invoke(HttpContext context, IServerConfigurationManager serverConfigurationManager)    at Jellyfin.Api.Middleware.ExceptionMiddleware.Invoke(HttpContext context) [17:40:00] [INF] [33] Jellyfin.Api.Auth.CustomAuthenticationHandler: CustomAuthentication was not authenticated. Failure message: Invalid token. [17:40:00] [INF] [33] Jellyfin.Api.Auth.CustomAuthenticationHandler: CustomAuthentication was not authenticated. Failure message: Invalid token. [17:40:00] [INF] [33] Jellyfin.Api.Auth.CustomAuthenticationHandler: AuthenticationScheme: CustomAuthentication was challenged. [17:45:00] [INF] [13] Jellyfin.Api.Auth.CustomAuthenticationHandler: CustomAuthentication was not authenticated. Failure message: Invalid token. [17:45:00] [INF] [13] Jellyfin.Api.Auth.CustomAuthenticationHandler: CustomAuthentication was not authenticated. Failure message: Invalid token. [17:45:00] [INF] [13] Jellyfin.Api.Auth.CustomAuthenticationHandler: AuthenticationScheme: CustomAuthentication was challenged. [17:50:00] [INF] [51] Jellyfin.Api.Auth.CustomAuthenticationHandler: CustomAuthentication was not authenticated. Failure message: Invalid token. [17:50:00] [INF] [51] Jellyfin.Api.Auth.CustomAuthenticationHandler: CustomAuthentication was not authenticated. Failure message: Invalid token. [17:50:00] [INF] [51] Jellyfin.Api.Auth.CustomAuthenticationHandler: AuthenticationScheme: CustomAuthentication was challenged.
`

---

## 5. Architectural Recommendations & Maintenance Tips
1. **Auto-Recovery:** If degraded, execute `.\Repair-jellyfin.ps1` or `.\Repair-MediaStackFleet.ps1 -Service Streaming`.
2. **Backup Strategy:** Included in atomic hot backup snapshot via `.\Backup-MediaStackFleet.ps1`.
3. **Replication Strategy:** Synchronized across Voltaire nodes via `.\Replicate-MediaStackCluster.ps1`.

---
*Generated autonomously by MediaStack Deep Analysis Engine.*
