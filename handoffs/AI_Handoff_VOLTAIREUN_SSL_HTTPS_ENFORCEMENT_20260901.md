# 🛡️ MediaStack AI Handoff & Architecture Directives: VoltaireUn (192.168.4.21)

| Metadata Attribute | Directive Specification |
| :--- | :--- |
| **Authoring Ingress Node** | **`voltairedeux.local` (192.168.4.30)** |
| **Target Execution Node** | **`voltaireun.local` (192.168.4.21)** |
| **Release Tag** | **`VOLTAIREUN_SSL_HTTPS_MERGED_STACK_20260901`** |
| **Cluster Roles** | VoltaireUn: 24/7 Primary Streaming, Ingress & Media Storage Server<br>VoltaireDeux: AI Acceleration, Push Ingress & Metadata Tagging Workstation |
| **Security State** | Universal HTTP (:80) -> HTTPS (:443) 301 Permanent Redirection Enforced |
| **SSL/TLS Cryptography** | 4096-Bit RSA Root CA & SAN Certificates (3,649 Days Remaining / 10-Year Epoch) |

---

## 1. SSL/TLS Certificate Mapping & Ingress Directives for VoltaireUn

### A. Certificate File Pathways & Volume Mounts
Ensure all incoming connections on `voltaireun.local` and external WAN (`waltdakind.xubi.org`, `jellyfin.waltdakind.xubi.org`) use the cluster's cryptographic bundle located in `.\certs`:

```
Host Directory:       .\certs\
  ├── ca.crt          (MediaStack Root CA X.509 Certificate)
  ├── ca.key          (MediaStack Root CA Private Key)
  ├── cert.pem        (4096-bit Multi-Domain Public Certificate)
  ├── key.pem         (4096-bit Server Private Key)
  ├── server.crt      (DER/PEM Public Cert)
  ├── server.key      (RSA Private Key)
  ├── server.pfx      (PKCS#12 Bundle for Jellyfin Kestrel, Password: mediastack)
  └── openssl.cnf     (Cryptographic SAN Configuration)
```

#### Container Volume Mount Directives:
- **Caddy Gateway**: `./certs:/etc/caddy/certs:ro`
- **Jellyfin Server**: `./certs:/certs:ro`
- **API Gateway**: `./certs:/certs:ro`

### B. Caddy Reverse Proxy Configuration (`Caddyfile-VoltaireUn`)
Incorporate the universal HTTP redirect and custom TLS snippet:

```caddy
(custom_tls) {
    tls /etc/caddy/certs/cert.pem /etc/caddy/certs/key.pem
}

(security_headers) {
    header {
        Strict-Transport-Security "max-age=31536000; includeSubDomains; preload"
        X-Content-Type-Options "nosniff"
        X-Frame-Options "SAMEORIGIN"
        X-XSS-Protection "1; mode=block"
        Referrer-Policy "strict-origin-when-cross-origin"
    }
}

# 1. Universal HTTP (:80) to HTTPS (:443) Enforcement (All Hosts & Subdomains)
:80 {
    import security_headers
    encode gzip zstd
    redir https://{host}{uri} permanent
}

# 2. Secure HTTPS (:443) Ingress Endpoints
https://waltdakind.xubi.org, https://jellyfin.waltdakind.xubi.org, https://voltaireun.local, https://voltairedeux.local, https://192.168.4.21, https://192.168.4.30, https://localhost {
    import custom_tls
    import jellyfin_cluster
}
```

---

## 2. Merged MusicBrainz Local DB & Fleet Port Forwarding Matrix

All MusicBrainz services (`musicbrainz`, `musicbrainz-db`, `musicbrainz-search`, `musicbrainz-indexer`, `musicbrainz-valkey`) are now directly merged into `docker-compose.yml`. Each service exposes and binds direct host ports visible in Docker Desktop:

| Service / Container Name | Internal Port | Host Port Forward | Docker Desktop Display | Operational Function |
| :--- | :--- | :--- | :--- | :--- |
| **`caddy`** | `80`, `443`, `8096` | `80:80`, `443:443`, `8096:8096` | `0.0.0.0:80->80`, `443->443` | Reverse Proxy & SSL Ingress Router |
| **`jellyfin`** | `8096`, `8920` | `8096:8096`, `8920:8920` | `0.0.0.0:8096->8096`, `8920->8920` | Primary Media Streaming Engine |
| **`musicbrainz`** | `5000` | `5000:5000`, `5001:5000` | `0.0.0.0:5000->5000`, `5001->5000` | MusicBrainz Web & REST WS2 API Mirror |
| **`musicbrainz-db`** | `5432` | `5432:5432` | `0.0.0.0:5432->5432` | PostgreSQL 18 Local Database Engine |
| **`musicbrainz-search`** | `8983` | `8983:8983` | `0.0.0.0:8983->8983` | Apache Solr Full-Text Search Indexer |
| **`musicbrainz-valkey`** | `6379` | `6379:6379` | `0.0.0.0:6379->6379` | Valkey / Redis In-Memory Cache Store |
| **`sonarr`** | `8989` | `8989:8989` | `0.0.0.0:8989->8989` | TV Series Management & Automation |
| **`radarr`** | `7878` | `7878:7878` | `0.0.0.0:7878->7878` | Movie Collection & Automation |
| **`prowlarr`** | `9696` | `9696:9696` | `0.0.0.0:9696->9696` | Indexer Aggregator & FlareSolverr |
| **`bazarr`** | `6767` | `6767:6767` | `0.0.0.0:6767->6767` | Subtitle Synchronization Engine |
| **`jellyseerr`** | `5055` | `5055:5055` | `0.0.0.0:5055->5055` | Media Request & Discovery Gateway |
| **`transmission`** | `9091` | `9091:9091`, `51413:51413` | `0.0.0.0:9091->9091` | BitTorrent Client & Transfer Engine |
| **`tvheadend`** | `9981`, `9982` | `9981:9981`, `9982:9982` | `0.0.0.0:9981->9981` | Live TV Tuner & IPTV Stream Server |
| **`api-gateway`** | `3000` | `3001:3000` | `0.0.0.0:3001->3000` | Express REST Telemetry & SSL Probe API |
| **`homepage`** | `3000` | `3000:3000` | `0.0.0.0:3000->3000` | NOC Unified Fleet Dashboard |
| **`mediastack-db`** | `8080` | `8080:8080` | `0.0.0.0:8080->8080` | SQLite Web Database Management UI |

---

## 3. Diagnostics & Unified Fleet Backup Directives

### A. MusicBrainz Inclusion in Diagnostics
MusicBrainz is subjected to identical automated diagnostics:
1. **L4 Direct Socket Probe**: Port 5432 (PostgreSQL), Port 8983 (Solr), Port 6379 (Valkey).
2. **L7 Ingress Probe**: `http://localhost:5000/ws/2/artist/` and `https://musicbrainz.voltaireun.local/`.
3. **Database Integrity**:
   ```powershell
   docker exec musicbrainz-docker-db-1 psql -U musicbrainz -d musicbrainz -c "SELECT current_schema_sequence, last_replication_date FROM replication_control;"
   ```

### B. Fleet Backup with 5-Snapshot Retention (Older to Recycle Bin)
1. Execute `Backup-MediaStackFleet.ps1 -All` to stage secrets, certificates, SQLite databases, and MusicBrainz metadata.
2. The master orchestrator (`Start-MediaStackOrchestrator.ps1`) enforces:
   - Retaining exactly the **5 most recent** backup archives in `.\backups\`.
   - Safely moving any older backup archives to the **Windows Recycle Bin** via `Microsoft.VisualBasic.FileIO.FileSystem::DeleteFile(..., SendToRecycleBin)`.

---

## 4. Cross-Node Replication & Execution Directives

### A. MusicBrainz Replication & Picard Sync
- **Live Replication**: Run `Sync-MusicBrainzReplication.ps1` to ingest hourly replication packets from MetaBrainz using the token in `musicbrainz-docker\local\secrets\metabrainz_access_token`.
- **Picard Batch Tagging**: Configure MusicBrainz Picard on VoltaireUn to use the local mirror `http://192.168.4.21:5000` or peer workstation `http://192.168.4.30:5000`.

### B. Action Checklist for VoltaireUn Administrator:
- [x] Pull latest repository updates from OneDrive.
- [x] Confirm `.\certs` contains the regenerated 4096-bit certificate bundle.
- [x] Launch the unified stack using `.\Start-MediaStackOrchestrator.ps1`.
- [x] Confirm all 15 services (including MusicBrainz open ports 5000, 5001, 5432, 8983, 6379) are active in Docker Desktop.
- [x] Verify Autohealer (`logs/autohealer_daemon.log`) and AI Collaboration Hub (`logs/ai_collaboration_hub.log`) are active.

---
*Generated by VoltaireDeux AI Collaboration Engine for VoltaireUn Node.*
