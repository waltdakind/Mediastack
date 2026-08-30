# MediaStack API Verification & Credentials Audit Report

| Parameter | Value |
| :--- | :--- |
| **Audit Timestamp** | 2026-08-28 20:56:08 |
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
| PicardOAuth | meba_D... (Length: 47) | Found |
| MetaBrainz | test-t... (Length: 16) | Found |

---

## Live API Endpoint Responses
| Service | Endpoint URL | Status | HTTP Code | Latency | Details |
| :--- | :--- | :--- | :--- | :--- | :--- |
| Sonarr API | http://localhost:80/api/v3/system/status | OK | 200 | 99ms | version: 4.0.19.2979 |
| Radarr API | http://localhost:80/api/v3/system/status | OK | 200 | 58ms | version: 6.3.0.10514 |
| Prowlarr API | http://localhost:80/api/v1/system/status | OK | 200 | 70ms | version: 2.5.2.5491 |
| Bazarr API | http://localhost:80/api/system/status | OK | 200 | 58ms | HTTP 200 OK |
| Jellyseerr API | http://localhost:80/api/v1/status | OK | 200 | 110ms | version: 3.4.1 |
| Jellyfin API | http://localhost:80/System/Info/Public | OK | 200 | 140ms | Version: 10.11.11 |
| MusicBrainz WS2 | http://localhost:80/ws/2/artist/5b11f4ce-a62d-471e-81fc-a69a8278c7da?fmt=json | FAIL | FAIL | 1551ms | The remote server returned an error: (500) Internal Server Error. |
| AcoustID API | https://api.acoustid.org/v2/user/info?client=4wzgif6hwM | FAIL | FAIL | 227ms | The remote server returned an error: (404) Not Found. |
| API Gateway | http://localhost:80/api/system/status | OK | 200 | 91ms | HTTP 200 OK |
| SQLite DB Web | http://localhost:80/ | OK | 200 | 46ms | HTTP 200 OK (HTML/Text) |

---
*Audit generated automatically by MediaStack API Verification Suite.*
