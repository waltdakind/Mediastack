# MediaStack Secrets and Token Security Report
**Audit Timestamp:** 2026-08-31 18:56:03 | **Engine:** Sync-MediaStackSecrets.ps1

## 1. Multi-Node Token and Service Credential Audit
| Service | Type | Port | Vault Status | Masked Key |
| :--- | :--- | :--- | :--- | :--- |
| **MusicBrainz / MetaBrainz** | Replication Token | 5000 | SECURED IN VAULT | `test...2345` |
| **Picard / AcoustID** | Fingerprint Key | 5001 | SECURED IN VAULT | `4wzg...6hwM` |
| **Sonarr** | API Key | 8989 | SECURED IN VAULT | `38c6...0bac` |
| **Radarr** | API Key | 7878 | SECURED IN VAULT | `a5e0...f95e` |
| **Prowlarr** | API Key | 9696 | SECURED IN VAULT | `f07e...2596` |
| **Bazarr** | API Key | 6767 | SECURED IN VAULT | `5f1e...1cfd` |
| **Jellyseerr** | API Key | 5055 | SECURED IN VAULT | `MTc4...NA==` |
| **Jellyfin** | API Key | 8096 | SECURED IN VAULT | `aa8e...a219` |
| **Syncthing** | API Key | 8384 | SECURED IN VAULT | `o3ZL...Gujw` |
| **PostgreSQL DB** | Credentials | 5432 | SECURED IN VAULT | `musi...ainz` |
| **Transmission** | Web Credentials | 9091 | SECURED IN VAULT | `admi...word` |

## 2. Multi-Node MusicBrainz Token Access Matrix
- **Primary Node (VoltaireUn - 192.168.4.21):** Port 5000 upstream with Docker secrets integration at musicbrainz-docker/local/secrets/metabrainz_access_token.
- **Secondary Node (VoltaireDeux - 192.168.4.30):** Port 5001 mirror with failover routing in Caddy.
- **Caddy Reverse Proxy Ingress:** Authorization header pass-through, CORS headers, and cross-node upstream failover configured across all domain names.

## 3. Git Isolation and Leak Prevention Status
> [!NOTE]
> **ALL SECRETS ISOLATED.** No API keys, access tokens, or live environment files are tracked by Git.


