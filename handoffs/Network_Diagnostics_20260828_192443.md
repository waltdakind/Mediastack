# ðŸŒ Comprehensive Network & WAN Diagnostics Report

| Field | Value |
| :--- | :--- |
| **Timestamp** | 2026-08-28 19:24:43 |
| **Host System** | VOLTAIREDEUX (Microsoft Windows 11 Home) |
| **Default Gateway** | 192.168.4.1 |
| **Public IPv4** | 73.178.82.157 |
| **Public IPv6** | 2601:85:c200:3e78:a0d9:37c5:f6d2:292d |

---

## 1. Local LAN & Cross-Node Connectivity
| Target Node | IP Address | Ping Status | Service Port | Port Status |
| :--- | :--- | :--- | :--- | :--- |
| Gateway / Router | 192.168.4.1 | âœ… OK | 80 | âš ï¸ Closed |
| Local Node (VoltaireDeux) | 192.168.4.30 | âœ… OK | 80 | âœ… Open |
| Primary Server (OrdinateurdeVolt) | 192.168.4.21 | âœ… OK | 8096 | âœ… Open |
| HDHomeRun Physical Tuner | 192.168.4.45 | âŒ Fail | 80 | âš ï¸ Closed |

---

## 2. Local Docker Fleet Listening Ports
| Service Name | Port | Status |
| :--- | :--- | :--- |
| Caddy Gateway (HTTP) | 80 | âœ… Listening |
| Caddy Gateway (HTTPS) | 443 | âœ… Listening |
| Jellyfin Media Server | 8096 | âœ… Listening |
| MusicBrainz Mirror (Local) | 5001 | âœ… Listening |
| API Gateway / Dashboard | 3000 | âœ… Listening |
| Mediastack SQLite DB GUI | 8080 | âœ… Listening |
| Transmission Torrent Peer | 51413 | âœ… Listening |

---

## 3. External WAN Port Forwarding Status
| Port | Protocol / Purpose | Status |
| :--- | :--- | :--- |
| 80 | HTTP Gateway | OPEN (Forwarded) |
| 443 | HTTPS Gateway | OPEN (Forwarded) |
| 8096 | Jellyfin Remote Stream | CLOSED (NAT/Firewalled) |
| 5001 | MusicBrainz Mirror | CLOSED (NAT/Firewalled) |

---

## 4. Picard & MusicBrainz API Configuration
- **Server Host:** 192.168.4.30
- **Server Port:** 5001
- **AcoustID API Key:** Configured âœ…
- **OAuth User:** waltdakind
- **MusicBrainz WS/2 Live:** Container Online

---
*Report generated automatically by MediaStack Network Diagnostic Suite.*
