# MediaStack API Verification & Credentials Audit Report

| Parameter | Value |
| :--- | :--- |
| **Audit Timestamp** | 2026-08-28 19:47:06 |
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
| Sonarr API | http://localhost:80/api/v3/system/status | FAIL | 000 | 66ms | Exception calling "Add" with "2" argument(s): "The 'Host' header must be modified using the appropriate property or method.
Parameter name: name" |
| Radarr API | http://localhost:80/api/v3/system/status | FAIL | 000 | 0ms | Exception calling "Add" with "2" argument(s): "The 'Host' header must be modified using the appropriate property or method.
Parameter name: name" |
| Prowlarr API | http://localhost:80/api/v1/system/status | FAIL | 000 | 0ms | Exception calling "Add" with "2" argument(s): "The 'Host' header must be modified using the appropriate property or method.
Parameter name: name" |
| Bazarr API | http://localhost:80/api/system/status | FAIL | 000 | 0ms | Exception calling "Add" with "2" argument(s): "The 'Host' header must be modified using the appropriate property or method.
Parameter name: name" |
| Jellyseerr API | http://localhost:80/api/v1/status | FAIL | 000 | 0ms | Exception calling "Add" with "2" argument(s): "The 'Host' header must be modified using the appropriate property or method.
Parameter name: name" |
| Jellyfin API | http://localhost:80/System/Info/Public | FAIL | 000 | 0ms | Exception calling "Add" with "2" argument(s): "The 'Host' header must be modified using the appropriate property or method.
Parameter name: name" |
| MusicBrainz WS2 | http://localhost:80/ws/2/artist/5b11f4ce-a62d-471e-81fc-a69a8278c7da?fmt=json | FAIL | 000 | 0ms | Exception calling "Add" with "2" argument(s): "The 'Host' header must be modified using the appropriate property or method.
Parameter name: name" |
| AcoustID API | https://api.acoustid.org/v2/lookup?client=4wzgif6hwM&meta=recordings | FAIL | FAIL | 309ms | The remote server returned an error: (400) Bad Request. |
| API Gateway | http://localhost:80/api/system/status | FAIL | 000 | 0ms | Exception calling "Add" with "2" argument(s): "The 'Host' header must be modified using the appropriate property or method.
Parameter name: name" |
| SQLite DB Web | http://localhost:80/ | FAIL | 000 | 0ms | Exception calling "Add" with "2" argument(s): "The 'Host' header must be modified using the appropriate property or method.
Parameter name: name" |

---
*Audit generated automatically by MediaStack API Verification Suite.*
