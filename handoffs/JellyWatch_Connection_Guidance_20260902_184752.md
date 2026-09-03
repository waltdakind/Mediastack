# JellyWatch Resilient Connection & Guidance Report

- **Target Application:** JellyWatch (watchOS / Companion Client)
- **License Tier:** Premium Activation (4f3eeea865c64d649330bdae9dde2ca1)
- **Timestamp:** 2026-09-02 18:47:52
- **Primary Live Route:** VoltaireUn Direct Socket (Local Network Fallback) (http://192.168.4.21:8096) - Latency: 252 ms

---

## 1. Multi-Tier Cascade Status

| Tier | Pathway / Candidate | Endpoint URL | Protocol | Status | Latency | Ideal Use Case |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| 1 | Remote WAN Gateway (Public DDNS - Main Login) | https://waltdakind.xubi.org | HTTPS/WAN | [!] UNREACHABLE | 2241 ms | Primary Default Login (Anywhere, LTE/Cellular & External Networks) |
| 2 | VoltaireUn Direct Socket (Local Network Fallback) | http://192.168.4.21:8096 | HTTP/REST | [OK] ONLINE | 252 ms | Local Home Network Fallback (Zero TLS friction, lowest LAN latency) |
| 3 | VoltaireUn Ingress Gateway (Caddy HTTPS) | https://voltaireun.local | HTTPS/HTTP2 | [OK] ONLINE | 1161 ms | Local LAN Ingress & Web Companion |
| 4 | VoltaireDeux AI Node (Failover LAN) | http://192.168.4.30:8096 | HTTP/REST | [!] UNREACHABLE | 1822 ms | Automated Failover when VoltaireUn is restarting/updating |
| 5 | Localhost Loopback Socket | http://127.0.0.1:8096 | HTTP/Loopback | [OK] ONLINE | 1801 ms | Local Server Diagnostic & Docker Host Testing |

---

## 2. Expert Diagnostic Guidance & Triage

### Issue: JellyWatch Multi-Tier Connection Cascade (ERR_GENERAL_DISCONNECT)
- **Root Cause:** Standard resilient connection profile.
- **Immediate Action:** Use Tier 1 Direct LAN Socket (http://192.168.4.21:8096).

#### Step-by-Step Remediation:

1. Tier 1 (LAN): http://192.168.4.21:8096
1. Tier 2 (Proxy): https://voltaireun.local
1. Tier 3 (Failover): http://192.168.4.30:8096
1. Tier 4 (WAN): https://waltdakind.xubi.org

---

## 3. Configuration & Auto-Healing Registry

- **Master Registry:** config/api_credentials_registry.json
- **Jellyfin Plugin XML:** config/jellyfin/data/plugins/configurations/Jellyfin.Plugin.JellyWatch.xml
- **Multicast Discovery Ports:** UDP 7359 (Jellyfin Bonjour), UDP 5353 (mDNS)

*Generated automatically by MediaStack JellyWatch Resilient Connection Sentinel.*
