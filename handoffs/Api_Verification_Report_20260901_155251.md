# MediaStack API Verification & Credentials Audit Report

| Parameter | Value |
| :--- | :--- |
| **Audit Timestamp** | 2026-09-01 15:52:51 |
| **Host System** | VOLTAIREDEUX |
| **Config Directory** | C:\MediastackConfig |

---

## Discovered API Credentials
| Service | Key Discovered | Status |
| :--- | :--- | :--- |
| Sonarr | 38c67d... (Length: 32) | Found |
| Radarr | a5e014... (Length: 32) | Found |
| Prowlarr | f07e5d... (Length: 32) | Found |
| Bazarr | 5f1ec7... (Length: 32) | Found |
| Jellyseerr | MTc4Nz... (Length: 68) | Found |
| Jellyfin | aa8e1b... (Length: 32) | Found |
| AcoustID | 4wzgif... (Length: 10) | Found |
| PicardOAuth | Not Set / Public | Public |
| MetaBrainz | test-t... (Length: 16) | Found |

---

## Live API Endpoint Responses
| Service | Endpoint URL | Status | HTTP Code | Latency | Details |
| :--- | :--- | :--- | :--- | :--- | :--- |
| Sonarr API | http://localhost:8989/api/v3/system/status | FAIL | FAIL | 69ms | The underlying connection was closed: The connection was closed unexpectedly. |
| Radarr API | http://localhost:7878/api/v3/system/status | OK | 200 | 246ms | version: 6.3.0.10514 |
| Prowlarr API | http://localhost:9696/api/v1/system/status | OK | 200 | 365ms | version: 2.5.2.5491 |
| Bazarr API | http://localhost:6767/api/system/status | OK | 200 | 489ms | HTTP 200 OK |
| Jellyseerr API | http://localhost:5055/api/v1/status | OK | 200 | 1799ms | version: 3.4.1 |
| Jellyfin HTTP | http://localhost:8096/System/Info/Public | OK | 200 | 29ms | HTTP 200 OK (HTML/Text) |
| Jellyfin HTTPS | https://localhost/System/Info/Public | OK | 200 | 85ms | HTTP 200 OK (HTML/Text) |
| MusicBrainz WS2 | http://localhost:80/ws/2/artist/5b11f4ce-a62d-471e-81fc-a69a8278c7da?fmt=json | STANDBY | FAIL | 140ms | STANDBY (Database dump import pending on port 5001) |
| AcoustID API | https://api.acoustid.org/v2/user/lookup?user=4wzgif6hwM | OK | 200 | 761ms | status: ok |
| API Gateway | http://localhost:3000/api/system/status | OK | 200 | 1967ms | HTTP 200 OK |
| SQLite DB Web | http://localhost:8080/ | OK | 200 | 64ms | HTTP 200 OK (HTML/Text) |
| HDHomeRun Tuner | http://localhost:80/discover.json | STANDBY | FAIL | 181ms | STANDBY (Hardware Tuner Standby / 192.168.4.45) |

---
*Audit generated automatically by MediaStack API Verification Suite.*
