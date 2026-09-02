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
| **Container Started** | 2026-09-01T20:07:40.194922677Z |
| **L7 Response Code** | HTTP 000 |
| **TTFB Latency** | 13.7 ms |
| **Vault Secrets Status**| SECURED IN VAULT |
| **Error Lines Detected**| 6 |
| **Audit Timestamp** | 2026-09-01 17:53:17 |

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
   --- End of inner exception stack trace ---    at NzbDrone.Core.Datastore.DbFactory.CreateMain(String connectionString, MigrationContext migrationContext, DatabaseType databaseType) in ./Sonarr.Core/Datastore/DbFactory.cs:line 164    at NzbDrone.Core.Datastore.DbFactory.Create(MigrationContext migrationContext) in ./Sonarr.Core/Datastore/DbFactory.cs:line 71    at NzbDrone.Core.Datastore.DbFactory.Create(MigrationType migrationType) in ./Sonarr.Core/Datastore/DbFactory.cs:line 59    at NzbDrone.Core.Datastore.Extensions.CompositionExtensions.<>c.<AddDatabase>b__0_0(IDbFactory f) in ./Sonarr.Core/Datastore/Extensions/CompositionExtensions.cs:line 10    at DryIoc.Registrator.ToFuncWithObjParams[D1,TService](Func`2 f, Object d1) in /_/src/DryIoc/Container.cs:line 8067    at DryIoc.Interpreter.TryInterpretFuncInvoke(IResolverContext r, MethodCallExpression e, IParameterProvider paramExprs, Object paramValues, ParentLambdaArgs parentArgs, Object& result) in /_/src/DryIoc/Container.cs:line 3727    at DryIoc.Interpreter.TryInterpretMethodCall(IResolverContext r, MethodCallExpression callExpr, IParameterProvider paramExprs, Object paramValues, ParentLambdaArgs parentArgs, Object& result) in /_/src/DryIoc/Container.cs:line 3525    at DryIoc.Interpreter.TryInterpret(IResolverContext r, Expression expr, IParameterProvider paramExprs, Object paramValues, ParentLambdaArgs parentArgs, Object& result) in /_/src/DryIoc/Container.cs:line 3176    at DryIoc.Interpreter.TryInterpretSingletonAndUnwrapContainerException(IResolverContext r, Expression expr, ImMapEntry`1 itemRef, Object& result) in /_/src/DryIoc/Container.cs:line 3105    at DryIoc.Factory.ApplyReuse(Expression serviceExpr, Request request) in /_/src/DryIoc/Container.cs:line 11136    at DryIoc.Factory.GetExpressionOrDefault(Request request) in /_/src/DryIoc/Container.cs:line 11055    at DryIoc.Container.ResolveAndCacheKeyed(Int32 serviceTypeHash, Type serviceType, Object serviceKey, IfUnresolved ifUnresolved, Object scopeName, Type requiredServiceType, Request preResolveParent, Object[] args) in /_/src/DryIoc/Container.cs:line 541    at DryIoc.Container.DryIoc.IResolver.Resolve(Type serviceType, Object serviceKey, IfUnresolved ifUnresolved, Type requiredServiceType, Request preResolveParent, Object[] args) in /_/src/DryIoc/Container.cs:line 469    at DryIoc.Interpreter.TryInterpretMethodCall(IResolverContext r, MethodCallExpression callExpr, IParameterProvider paramExprs, Object paramValues, ParentLambdaArgs parentArgs, Object& result) in /_/src/DryIoc/Container.cs:line 3661    at DryIoc.Interpreter.TryInterpret(IResolverContext r, Expression expr, IParameterProvider paramExprs, Object paramValues, ParentLambdaArgs parentArgs, Object& result) in /_/src/DryIoc/Container.cs:line 3188    at DryIoc.Interpreter.TryInterpretNestedLambdaBodyAndUnwrapException(IResolverContext r, Expression bodyExpr, IParameterProvider paramExprs, Object paramValues, ParentLambdaArgs parentArgs) in /_/src/DryIoc/Container.cs:line 3471    at DryIoc.Interpreter.<>c__DisplayClass5_0.<TryInterpretNestedLambda>b__0() in /_/src/DryIoc/Container.cs:line 3370    at DryIoc.Interpreter.<>c__DisplayClass9_0`1.<ConvertFunc>b__0() in /_/src/DryIoc/Container.cs:line 3481    at System.Lazy`1.ViaFactory(LazyThreadSafetyMode mode)    at System.Lazy`1.ExecutionAndPublication(LazyHelper executionAndPublication, Boolean useDefaultConstructor)    at System.Lazy`1.CreateValue()    at System.Lazy`1.get_Value()    at NzbDrone.Host.Startup.Configure(IApplicationBuilder app, IContainer container, IStartupContext startupContext, Lazy`1 mainDatabaseFactory, Lazy`1 logDatabaseFactory, DatabaseTarget dbTarget, ISingleInstancePolicy singleInstancePolicy, InitializeLogger initializeLogger, ReconfigureLogging reconfigureLogging, IAppFolderFactory appFolderFactory, IProvidePidFile pidFileProvider, IConfigFileProvider configFileProvider, IRuntimeInfo runtimeInfo, IFirewallAdapter firewallAdapter, IEventAggregator eventAggregator, SonarrErrorPipeline errorHandler) in ./Sonarr.Host/Startup.cs:line 229    at System.RuntimeMethodHandle.InvokeMethod(Object target, Span`1& arguments, Signature sig, Boolean constructor, Boolean wrapExceptions)    at System.Reflection.RuntimeMethodInfo.Invoke(Object obj, BindingFlags invokeAttr, Binder binder, Object[] parameters, CultureInfo culture)    at Microsoft.AspNetCore.Hosting.ConfigureBuilder.Invoke(Object instance, IApplicationBuilder builder)    at Microsoft.AspNetCore.Hosting.ConfigureBuilder.<>c__DisplayClass4_0.<Build>b__0(IApplicationBuilder builder)    at Microsoft.AspNetCore.Hosting.GenericWebHostBuilder.<>c__DisplayClass15_0.<UseStartup>b__1(IApplicationBuilder app)    at Microsoft.AspNetCore.Mvc.Filters.MiddlewareFilterBuilderStartupFilter.<>c__DisplayClass0_0.<Configure>g__MiddlewareFilterBuilder|0(IApplicationBuilder builder)    at Microsoft.AspNetCore.Hosting.GenericWebHostService.StartAsync(CancellationToken cancellationToken)    at Microsoft.Extensions.Hosting.Internal.Host.StartAsync(CancellationToken cancellationToken)    at Microsoft.Extensions.Hosting.HostingAbstractionsHostExtensions.RunAsync(IHost host, CancellationToken token)    at Microsoft.Extensions.Hosting.HostingAbstractionsHostExtensions.RunAsync(IHost host, CancellationToken token)    at Microsoft.Extensions.Hosting.HostingAbstractionsHostExtensions.Run(IHost host)    at NzbDrone.Host.Bootstrap.Start(String[] args, Action`1 trayCallback) in ./Sonarr.Host/Bootstrap.cs:line 80    at NzbDrone.Console.ConsoleApp.Main(String[] args) in ./Sonarr.Console/ConsoleApp.cs:line 45  Press enter to exit... Non-recoverable failure, waiting for user intervention...
`

---

## 5. Architectural Recommendations & Maintenance Tips
1. **Auto-Recovery:** If degraded, execute `.\Repair-sonarr.ps1` or `.\Repair-MediaStackFleet.ps1 -Service Servarr`.
2. **Backup Strategy:** Included in atomic hot backup snapshot via `.\Backup-MediaStackFleet.ps1`.
3. **Replication Strategy:** Synchronized across Voltaire nodes via `.\Replicate-MediaStackCluster.ps1`.

---
*Generated autonomously by MediaStack Deep Analysis Engine.*
