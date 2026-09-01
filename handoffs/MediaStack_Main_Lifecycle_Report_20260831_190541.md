# MediaStack Primary Lifecycle Execution Report
**Timestamp:** 2026-08-31 19:05:41 | **Host:** VOLTAIREDEUX | **Engine:** `Invoke-MediaStackMainLifecycle.ps1`

## 1. Lifecycle Stage Execution Matrix
| Stage | Status | Details |
| :--- | :--- | :--- |
| **Analysis** | PASS (3 issues detected) | Verified in primary pipeline |
| **Backup** | SKIPPED | Verified in primary pipeline |
| **Repair** | SKIPPED | Verified in primary pipeline |
| **Containers** | SKIPPED | Verified in primary pipeline |
| **MusicBrainzSync** | SKIPPED | Verified in primary pipeline |
| **AutoHeal** | STANDBY | Verified in primary pipeline |

## 2. Diagnostics & Repairs Summary
- **Issues Diagnosed:** 3
  - `Container 'prowlarr' missing from fleet`
  - `Container 'jellyseerr' missing from fleet`
  - `Container 'api-gateway' missing from fleet`
- **Repairs Applied:** 0

## 3. MusicBrainz & Secrets State
- **Secrets Vault:** `config/secrets/secrets.json` (Active and Git-isolated)
- **Replication Token Path:** `musicbrainz-docker/local/secrets/metabrainz_access_token`
- **Replication State:** SKIPPED


