# MediaStack API Verification & Credentials Audit Report

| Parameter | Value |
| :--- | :--- |
| **Audit Timestamp** | 2026-09-05 11:58:17 |
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
| Jellyfin | 8d5945... (Length: 32) | Found |
| AcoustID | 4wzgif... (Length: 10) | Found |
| PicardOAuth | Not Set / Public | Public |
| MetaBrainz | test-t... (Length: 16) | Found |

---

## Live API Endpoint Responses
| Service | Endpoint URL | Status | HTTP Code | Latency | Details |
| :--- | :--- | :--- | :--- | :--- | :--- |
| Sonarr API | http://localhost:8989/api/v3/system/status | OK | 200 | 39ms | version: 4.0.19.2979 |
| Radarr API | http://localhost:7878/api/v3/system/status | OK | 200 | 5ms | version: 6.3.0.10514 |
| Prowlarr API | http://localhost:9696/api/v1/system/status | OK | 200 | 7ms | version: 2.5.2.5491 |
| Bazarr API | http://localhost:6767/api/system/status | OK | 200 | 9ms | HTTP 200 OK |
| Jellyseerr API | http://localhost:5055/api/v1/status | OK | 200 | 12ms | version: 3.4.1 |
| Jellyfin HTTP | http://localhost:8096/System/Info/Public | OK | 307 | 3ms | HTTP 307 OK (HTML/Text) |
| Jellyfin HTTPS | https://localhost/System/Info/Public | OK | 200 | 21ms | HTTP 200 OK (HTML/Text) |
| MusicBrainz WS2 | http://localhost:80/ws/2/artist/5b11f4ce-a62d-471e-81fc-a69a8278c7da?fmt=json | OK | 301 | 3ms | HTTP 301 OK (HTML/Text) |
| AcoustID API | https://api.acoustid.org/v2/user/lookup?user=4wzgif6hwM | OK | 200 | 195ms | status: ok |
| API Gateway | http://localhost:3000/api/system/status | OK | 200 | 1900ms | HTTP 200 OK |
| SQLite DB Web | http://localhost:8080/ | OK | 200 | 49ms | HTTP 200 OK (HTML/Text) |
| HDHomeRun Tuner | http://localhost:80/discover.json | OK | 301 | 1ms | HTTP 301 OK (HTML/Text) |
| JellyWatch Requests API | http://localhost:3000/api/jellywatch/requests/stats | OK | 200 | 2ms | server: JellyWatch Requests Server |
| JellyWatch Issues API | http://localhost:3000/api/jellywatch/issues/stats | OK | 200 | 2ms | server: JellyWatch Issues Server |
| Requests Web Portal | http://localhost:80/requests | OK | 301 | 1ms | HTTP 301 OK (HTML/Text) |
| Issues Web Portal | http://localhost:80/issues | OK | 301 | 1ms | HTTP 301 OK (HTML/Text) |
| Portainer API | http://localhost:9000/api/system/status | OK | 303 | 5ms | Version:  |

---
*Audit generated automatically by MediaStack API Verification Suite.*
