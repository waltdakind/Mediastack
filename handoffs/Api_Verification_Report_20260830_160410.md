# MediaStack API Verification & Credentials Audit Report

| Parameter | Value |
| :--- | :--- |
| **Audit Timestamp** | 2026-08-30 16:04:10 |
| **Host System** | VOLTAIREUN |
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
| Sonarr API | http://localhost:8989/api/v3/system/status | FAIL | FAIL | 9857ms | The operation has timed out |
| Radarr API | http://localhost:7878/api/v3/system/status | FAIL | FAIL | 7502ms | The request was aborted: The operation has timed out. |
| Prowlarr API | http://localhost:9696/api/v1/system/status | FAIL | FAIL | 6002ms | The request was aborted: The operation has timed out. |
| Bazarr API | http://localhost:6767/api/system/status | FAIL | FAIL | 6095ms | The operation has timed out |
| Jellyseerr API | http://localhost:5055/api/v1/status | FAIL | FAIL | 6022ms | The request was aborted: The operation has timed out. |
| Jellyfin API | http://localhost:8096/System/Info/Public | FAIL | FAIL | 3194ms | The remote server returned an error: (500) Internal Server Error. |
| MusicBrainz WS2 | http://localhost:80/ws/2/artist/5b11f4ce-a62d-471e-81fc-a69a8278c7da?fmt=json | STANDBY | FAIL | 979ms | STANDBY (Database dump import pending on port 5001) |
| AcoustID API | https://api.acoustid.org/v2/user/lookup?user=4wzgif6hwM | OK | 200 | 2845ms | status: ok |
| API Gateway | http://localhost:3000/api/system/status | FAIL | FAIL | 6017ms | The request was aborted: The operation has timed out. |
| SQLite DB Web | http://localhost:8080/ | FAIL | FAIL | 6006ms | The request was aborted: The operation has timed out. |
| HDHomeRun Tuner | http://localhost:80/discover.json | STANDBY | FAIL | 221ms | STANDBY (Hardware Tuner Standby / 192.168.4.45) |

---
*Audit generated automatically by MediaStack API Verification Suite.*
