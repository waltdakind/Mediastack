# MediaStack MusicBrainz Mirror & High-Availability Failover Report

| Parameter | Value |
| :--- | :--- |
| **Audit Timestamp** | 2026-09-01 16:53:52 |
| **Host Node** | VOLTAIREDEUX |
| **Picard Target** | 127.0.0.1:5000 |
| **Caddy Proxy Route** | http://musicbrainz.voltaireun.local (Code: 301) |

---

## MusicBrainz Nodes Probed
| Node | Endpoint | TCP Port | HTTP UI | WS/2 API | Latency | Status | Details |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| Local Primary Mirror | 127.0.0.1:5001 | OPEN | 000 | 000 | 16ms | OFFLINE | HTTP 000 |
| Remote Fallback Mirror | 192.168.4.21:5000 | OPEN | 000 | 000 | 34ms | OFFLINE | HTTP 000 |

---
### Recommendations
- **Import Database Tables on Primary (5001):** Run `docker compose run --rm musicbrainz createdb.sh -fetch` in `C:\Users\waltd\OneDrive\Mediastack\musicbrainz-docker`.

---
*Audit generated automatically by MediaStack MusicBrainz Mirror Tester.*
