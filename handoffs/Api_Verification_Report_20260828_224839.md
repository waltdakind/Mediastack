# MediaStack API Verification & Credentials Audit Report

| Parameter | Value |
| :--- | :--- |
| **Audit Timestamp** | 2026-08-28 22:48:39 |
| **Host System** | VOLTAIREDEUX |
| **Config Directory** | C:\MediastackConfig |

---

## Discovered API Credentials
| Service | Key Discovered | Status |
| :--- | :--- | :--- |
| Sonarr | 14d760... (Length: 32) | Found |
| Radarr | ad87fd... (Length: 32) | Found |
| Prowlarr | 83eac6... (Length: 32) | Found |
| Bazarr | 94596d... (Length: 32) | Found |
| Jellyseerr | MTc4Nz... (Length: 68) | Found |
| Jellyfin | Not Set / Public | Public |
| AcoustID | 4wzgif... (Length: 10) | Found |
| PicardOAuth | Not Set / Public | Public |
| MetaBrainz | test-t... (Length: 16) | Found |

---

## Live API Endpoint Responses
| Service | Endpoint URL | Status | HTTP Code | Latency | Details |
| :--- | :--- | :--- | :--- | :--- | :--- |
| Sonarr API | http://localhost:80/api/v3/system/status | OK | 200 | 44ms | version: 4.0.19.2979 |
| Radarr API | http://localhost:80/api/v3/system/status | OK | 200 | 7ms | version: 6.3.0.10514 |
| Prowlarr API | http://localhost:80/api/v1/system/status | OK | 200 | 5ms | version: 2.5.2.5491 |
| Bazarr API | http://localhost:80/api/system/status | OK | 200 | 7ms | HTTP 200 OK |
| Jellyseerr API | http://localhost:80/api/v1/status | OK | 200 | 13ms | version: 3.4.1 |
| Jellyfin API | http://localhost:80/System/Info/Public | OK | 200 | 6ms | Version: 10.11.11 |
| MusicBrainz WS2 | http://localhost:80/ws/2/artist/5b11f4ce-a62d-471e-81fc-a69a8278c7da?fmt=json | STANDBY | FAIL | 491ms | STANDBY (Database dump import pending on port 5001) |
| AcoustID API | https://api.acoustid.org/v2/user/lookup?user=4wzgif6hwM | OK | 200 | 238ms | status: ok |
| API Gateway | http://localhost:80/api/system/status | OK | 200 | 74ms | HTTP 200 OK |
| SQLite DB Web | http://localhost:80/ | OK | 200 | 38ms | HTTP 200 OK (HTML/Text) |
| HDHomeRun Tuner | http://localhost:80/discover.json | STANDBY | FAIL | 3003ms | STANDBY (Hardware Tuner Standby / 192.168.4.45) |

---
*Audit generated automatically by MediaStack API Verification Suite.*
