# MediaStack Node Replication Report

| Metric | Value |
| :--- | :--- |
| **Replication Timestamp** | 2026-08-30 12:07:41 |
| **Node Name** | VOLTAIREDEUX |
| **Node Architecture** | x64 |
| **Primary Cluster Host** | 192.168.4.30 |
| **Valkey Container Instance** | \$ValkeyContainer\ |
| **Public Domain** | waltdakind.xubi.org |
| **Active Config Path** | \$activeConfig\ |
| **Media Library Path** | \$activeMedia\ |
| **Overall Status** | **SUCCESS (Node Fully Operational & Replicated)** |

### Verification Telemetry
| Endpoint | URL | HTTP Code | Status | Latency |
| :--- | :--- | :--- | :--- | :--- |
| Localhost Dashboard (HTTP) | \$(@{Endpoint=Localhost Dashboard (HTTP); URL=http://localhost:80/; Code=200; Status=PASS; Latency=75ms}.URL)\ | 200 | PASS | 75ms |
| Localhost Secure (HTTPS) | \$(@{Endpoint=Localhost Secure (HTTPS); URL=https://localhost:443/; Code=200; Status=PASS; Latency=167ms}.URL)\ | 200 | PASS | 167ms |
| Jellyfin API Ingress (HTTPS) | \$(@{Endpoint=Jellyfin API Ingress (HTTPS); URL=https://jellyfin.waltdakind.xubi.org/System/Info/Public; Code=200; Status=PASS; Latency=80ms}.URL)\ | 200 | PASS | 80ms |
| Jellyfin Web Player UI | \$(@{Endpoint=Jellyfin Web Player UI; URL=https://jellyfin.waltdakind.xubi.org/web/index.html; Code=200; Status=PASS; Latency=78ms}.URL)\ | 200 | PASS | 78ms |


### Replication Execution Guide for Additional Nodes
``powershell
# Run replication on target machine with automatic container startup and SSL trust installation:
.\Replicate-MediaStackNode.ps1 -TargetNodeName "VOLTAIREDEUX" -TargetArch "x64" -InstallCertificates -StartStack
``
