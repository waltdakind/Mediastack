# MediaStack MusicBrainz Mirror & High-Availability Failover Report

| Parameter | Value |
| :--- | :--- |
| **Audit Timestamp** | 2026-08-28 19:55:16 |
| **Host Node** | VOLTAIREDEUX |
| **Picard Target** | 192.168.4.30:5001 |
| **Caddy Proxy Route** | http://musicbrainz.voltaireun.local (Code: 500) |

---

## MusicBrainz Nodes Probed
| Node | Endpoint | TCP Port | HTTP UI | WS/2 API | Latency | Status | Details |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| Local Primary Mirror | 127.0.0.1:5001 | OPEN | 500 | 500 | 15ms | STANDBY | Database Tables Pending Import |
| Remote Fallback Mirror | 192.168.4.21:5000 | OPEN | 200 | 200 | 14ms | READY | WS/2 Queries Operational |

---
### Recommendations
- **Import Database Tables on Primary (5001):** Run `docker compose run --rm musicbrainz createdb.sh -fetch` in `C:\Users\waltd\OneDrive\Mediastack\musicbrainz-docker`.
- **Fallback Node (192.168.4.21:5000):** Active and available for failover routing.

---
*Audit generated automatically by MediaStack MusicBrainz Mirror Tester.*
