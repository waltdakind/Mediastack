# MediaStack Node Replication Report

| Metric | Value |
| :--- | :--- |
| **Replication Timestamp** | 2026-08-30 15:19:00 |
| **Node Name** | ORDINATEURDEVOL |
| **Node Architecture** | x64 |
| **Primary Cluster Host** | 192.168.4.30 |
| **Valkey Container Instance** | \$ValkeyContainer\ |
| **Public Domain** | waltdakind.xubi.org |
| **Active Config Path** | \$activeConfig\ |
| **Media Library Path** | \$activeMedia\ |
| **Overall Status** | **PARTIAL (Node Initialized - Minor Warmup Warnings)** |

### Verification Telemetry
| Endpoint | URL | HTTP Code | Status | Latency |
| :--- | :--- | :--- | :--- | :--- |
| Localhost Dashboard (HTTP) | \$(@{Endpoint=Localhost Dashboard (HTTP); URL=http://localhost:80/; Code=200; Status=PASS; Latency=205ms}.URL)\ | 200 | PASS | 205ms |
| Localhost Secure (HTTPS) | \$(@{Endpoint=Localhost Secure (HTTPS); URL=https://localhost:443/; Code=200; Status=PASS; Latency=196ms}.URL)\ | 200 | PASS | 196ms |
| Jellyfin API Ingress (HTTPS) | \$(@{Endpoint=Jellyfin API Ingress (HTTPS); URL=https://jellyfin.waltdakind.xubi.org/System/Info/Public; Code=500; Status=WARN; Latency=274ms}.URL)\ | 500 | WARN | 274ms |
| Jellyfin Web Player UI | \$(@{Endpoint=Jellyfin Web Player UI; URL=https://jellyfin.waltdakind.xubi.org/web/index.html; Code=503; Status=WARN; Latency=273ms}.URL)\ | 503 | WARN | 273ms |


### Replication Execution Guide for Additional Nodes
``powershell
# Run replication on target machine with automatic container startup and SSL trust installation:
.\Replicate-MediaStackNode.ps1 -TargetNodeName "ORDINATEURDEVOL" -TargetArch "x64" -InstallCertificates -StartStack
``
