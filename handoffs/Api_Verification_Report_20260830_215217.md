# MediaStack API Verification & Credentials Audit Report

| Parameter | Value |
| :--- | :--- |
| **Audit Timestamp** | 2026-08-30 21:52:17 |
| **Host System** | ORDINATEURDEVOL |
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
| Jellyfin | Not Set / Public | Public |
| AcoustID | 4wzgif... (Length: 10) | Found |
| PicardOAuth | IczZMS... (Length: 43) | Found |
| MetaBrainz | test-t... (Length: 16) | Found |

---

## Live API Endpoint Responses
| Service | Endpoint URL | Status | HTTP Code | Latency | Details |
| :--- | :--- | :--- | :--- | :--- | :--- |
| Sonarr API | http://localhost:8989/api/v3/system/status | OK | 200 | 640ms | version: 4.0.19.2979 |
| Radarr API | http://localhost:7878/api/v3/system/status | OK | 200 | 195ms | version: 6.3.0.10514 |
| Prowlarr API | http://localhost:9696/api/v1/system/status | OK | 200 | 487ms | version: 2.5.2.5491 |
| Bazarr API | http://localhost:6767/api/system/status | OK | 200 | 308ms | HTTP 200 OK |
| Jellyseerr API | http://localhost:5055/api/v1/status | OK | 200 | 4337ms | version: 3.4.1 |
| Jellyfin API | http://localhost:8096/System/Info/Public | FAIL | FAIL | 4077ms | Unable to connect to the remote server |
| MusicBrainz WS2 | http://localhost:80/ws/2/artist/5b11f4ce-a62d-471e-81fc-a69a8278c7da?fmt=json | STANDBY | FAIL | 46ms | STANDBY (Database dump import pending on port 5001) |
| AcoustID API | https://api.acoustid.org/v2/user/lookup?user=4wzgif6hwM | OK | 200 | 4106ms | status: ok |
| API Gateway | http://localhost:3000/api/system/status | OK | 200 | 2435ms | HTTP 200 OK |
| SQLite DB Web | http://localhost:8080/ | OK | 200 | 44ms | HTTP 200 OK (HTML/Text) |
| HDHomeRun Tuner | http://localhost:80/discover.json | STANDBY | FAIL | 3004ms | STANDBY (Hardware Tuner Standby / 192.168.4.45) |

---
*Audit generated automatically by MediaStack API Verification Suite.*
