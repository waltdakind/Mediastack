# MediaStack API Verification & Credentials Audit Report

| Parameter | Value |
| :--- | :--- |
| **Audit Timestamp** | 2026-08-31 18:56:19 |
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
| Sonarr API | http://localhost:8989/api/v3/system/status | FAIL | FAIL | 6056ms | The operation has timed out |
| Radarr API | http://localhost:7878/api/v3/system/status | OK | 200 | 96ms | version: 6.3.0.10514 |
| Prowlarr API | http://localhost:9696/api/v1/system/status | OK | 200 | 923ms | version: 2.5.2.5491 |
| Bazarr API | http://localhost:6767/api/system/status | FAIL | FAIL | 6013ms | The request was aborted: The operation has timed out. |
| Jellyseerr API | http://localhost:5055/api/v1/status | FAIL | FAIL | 6008ms | The request was aborted: The operation has timed out. |
| Jellyfin HTTP | http://localhost:8096/System/Info/Public | FAIL | FAIL | 6003ms | The request was aborted: The operation has timed out. |
| Jellyfin HTTPS | https://localhost/System/Info/Public | FAIL | FAIL | 6020ms | The operation has timed out |
| MusicBrainz WS2 | http://localhost:80/ws/2/artist/5b11f4ce-a62d-471e-81fc-a69a8278c7da?fmt=json | STANDBY | FAIL | 8004ms | STANDBY (Database dump import pending on port 5001) |
| AcoustID API | https://api.acoustid.org/v2/user/lookup?user=4wzgif6hwM | OK | 200 | 247ms | status: ok |
| API Gateway | http://localhost:3000/api/system/status | OK | 200 | 421ms | HTTP 200 OK |
| SQLite DB Web | http://localhost:8080/ | OK | 200 | 303ms | HTTP 200 OK (HTML/Text) |
| HDHomeRun Tuner | http://localhost:80/discover.json | STANDBY | FAIL | 3019ms | STANDBY (Hardware Tuner Standby / 192.168.4.45) |

---
*Audit generated automatically by MediaStack API Verification Suite.*
