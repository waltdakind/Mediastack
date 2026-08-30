# MusicBrainz Database Connection & Failover Resolution Report

| Parameter | Value |
| :--- | :--- |
| **Scan Timestamp** | 2026-08-29 21:13:48 |
| **PostgreSQL Engine Status** | ONLINE (Ready) |
| **Populated Database Tables** | 0 tables |
| **Fallback Node (192.168.4.21)** | TCP Ports 5000 & 5001 Active |

---

## Container States
| Container | Role | Status | Exit Code | Needs Reboot |
| :--- | :--- | :--- | :--- | :--- |
| **musicbrainz-docker-musicbrainz-1** | Web / REST API | running | 0 | False |
| **musicbrainz-docker-db-1** | Postgres DB | running | 0 | False |
| **musicbrainz-docker-search-1** | Solr Search | running | 0 | False |
| **musicbrainz-docker-indexer-1** | Indexer | running | 0 | False |
| **musicbrainz-docker-valkey-1** | Valkey Cache | running | 0 | False |

---

## Port Listener Connectivity
| Endpoint | Status | Latency |
| :--- | :--- | :--- |
| **Local Primary Port (127.0.0.1:5000)** | OPEN | 15ms |
| **Local Secondary Port (127.0.0.1:5001)** | OPEN | 0ms |
| **Remote Fallback Node (192.168.4.21:5000)** | OPEN | 9ms |
| **Remote Fallback Node (192.168.4.21:5001)** | OPEN | 13ms |

---
### Summary & Next Actions
- **Docker Container Reboot Needed?**: No critical container crash detected. All 5 containers are running stably.
- **Port Listening Status**: Ports **5000** and **5001** are listening locally on this machine, and TCP ports **5000** and **5001** are also active on the fallback server (**192.168.4.21**).
- **Database State**: PostgreSQL is accepting connections on 5432.
