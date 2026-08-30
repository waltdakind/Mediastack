# MediaStack MusicBrainz Mirror & High-Availability Failover Report

| Parameter | Value |
| :--- | :--- |
| **Audit Timestamp** | 2026-08-28 20:56:11 |
| **Host Node** | VOLTAIREDEUX |
| **Picard Target** | 192.168.4.30:5001 |
| **Caddy Proxy Route** | http://musicbrainz.ordinateur.local (Code: 500) |

---

## MusicBrainz Nodes Probed
| Node | Endpoint | TCP Port | HTTP UI | WS/2 API | Latency | Status | Details |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| Local Primary Mirror | 127.0.0.1:5001 | OPEN | 500 | 500 | 10ms | STANDBY | Database Tables Pending Import |
| Remote Fallback Mirror | 192.168.4.21:5000 | OPEN | 000 | 000 | 8ms | OFFLINE | HTTP 000 |

---
### Recommendations
- **Import Database Tables on Primary (5001):** Run `docker compose run --rm musicbrainz createdb.sh -fetch` in `C:\Users\waltd\OneDrive\Mediastack\musicbrainz-docker`.

---
*Audit generated automatically by MediaStack MusicBrainz Mirror Tester.*
