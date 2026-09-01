# MediaStack Fix & Deploy Checklist
# Hand this to another AI agent or human to complete deployment

## Pre-Deployment Tasks

### Directory Creation
- [x] Verify `C:\Users\Public\MediaStack` exists
- [x] Run bash script: `cd MediaStack && bash setup.sh`
- [x] Or manually create all subdirectories (see AGENT_HANDOFF.md)
- [x] Verify external paths: `C:\Users\Public\Videos`, `C:\Users\Public\Music`, `C:\Users\Public\Pictures`

### Windows Configuration
- [ ] Enable Network Discovery (Settings → Network & Internet → Advanced)
- [ ] Enable File & Printer Sharing
- [ ] Configure Windows Firewall to allow SMB (if using network shares)
- [ ] Create SMB shares (see SHARES_SETUP.md for 5 shares to create)

### Docker Configuration
- [x] Docker Desktop installed and running
- [x] WSL2 integration enabled (if on Windows)
- [x] Docker daemon has access to `C:\Users\Public\` directory

## Validation Tasks

- [x] `docker compose config` runs without errors
- [x] `docker ps` shows working Docker daemon
- [x] All volume paths resolve: `docker inspect jellyfin | grep -A 30 Mounts`
- [x] Port conflicts checked: ports 80, 443, 8096, 8989, 7878, 6767, 9117, 9091, 9981, 5055 are free

## Deployment

- [x] Run: `docker compose up -d`
- [x] Wait 2-3 minutes for initial startup
- [x] Run: `docker ps` and verify all 10 containers are up
- [x] Run: `docker ps` again and verify healthchecks pass (should show "healthy")

## Post-Deployment Verification

- [x] Jellyfin (8096): `curl http://localhost:8096/health` → 200 OK
- [x] Sonarr (8989): `curl http://localhost:8989/health` → 200 OK
- [x] Radarr (7878): `curl http://localhost:7878/health` → 200 OK
- [x] Jackett (9117): `curl http://localhost:9117/` → 200 OK
- [x] Transmission (9091): `curl http://localhost:9091/transmission/web/` → 200 OK
- [x] Bazarr (6767): `curl http://localhost:6767/` → 200 OK
- [x] JellySeerr (5055): `curl http://localhost:5055/api/v1/status` → 200 OK
- [x] TVHeadend (9981): `curl http://localhost:9981/` → 200 OK
- [x] Caddy (80): `curl http://localhost:2019/config` → 200 OK
- [x] Syncthing (8384): `curl http://localhost:8384/rest/noauth/health` → 200 OK

## Service Configuration (In Order)

### Phase 1: Core (Essential)
- [x] Jellyfin: Create admin user, add media libraries
- [x] Caddy: Edit Caddyfile if HTTPS needed (optional)

### Phase 2: Downloads & Discovery (Required for content)
- [x] Transmission: Verify `/downloads` mount, note RPC credentials
- [x] Jackett: Add torrent indexers, copy Torznab URL
- [x] Sonarr: Add Jackett indexer, add Transmission client, add `/media/videos` root folder
- [x] Radarr: Add Jackett indexer, add Transmission client, add `/media/videos` root folder

### Phase 3: Enhancements (Optional but Recommended)
- [ ] Bazarr: Connect to Sonarr/Radarr, select subtitle languages
- [ ] JellySeerr: Connect to Jellyfin/Sonarr/Radarr, enable requests
- [ ] Syncthing: Configure if multi-machine sync needed
- [ ] TVHeadend: Configure if live TV needed

## Troubleshooting Steps

If any service fails to start:
1. Check logs: `docker logs <service_name>`
2. Verify volumes: `docker inspect <service_name> | grep -A 30 Mounts`
3. Check ports: `netstat -ano | findstr :<port>`
4. Restart: `docker compose restart <service_name>`
5. Full reset: `docker compose down && docker compose up -d`

If healthcheck fails:
1. Wait 30-60 seconds (startup grace period)
2. Check logs: `docker logs <service_name>`
3. Service should auto-restart; verify: `docker ps --filter name=<service_name>`

## Files Provided

- `docker-compose.yml` — Complete service definitions (ready to deploy)
- `AGENT_HANDOFF.md` — Complete deployment guide (read this first!)
- `SHARES_SETUP.md` — Windows SMB share configuration (if needed)
- `SERVICE_SETUP.md` — Per-service initial config steps
- `HEALTH_CHECKS.md` — Healthcheck monitoring details
- `setup.sh` — Bash script to create directories
- `.env.example` — Environment variable template
- `FIX_AND_DEPLOY_CHECKLIST.md` — This file

## What's Already Done

✓ All 10 services configured in docker-compose.yml  
✓ All healthchecks added (with self-healing)  
✓ All volume mounts standardized  
✓ All dependencies configured  
✓ Jackett healthcheck added  
✓ All documentation generated  

## What You Must Do

- [x] Create directories (run `setup.sh` or manual)  
- [ ] Enable SMB shares (Windows configuration)  
- [x] Run `docker compose up -d`  
- [x] Wait for healthchecks to pass  
- [ ] Configure each service (1-2 hours total)  

---

**Estimated Time to Full Deployment:** 3-4 hours (mostly service configuration)

**Support Documentation:**
- Start with: `AGENT_HANDOFF.md`
- Service setup: `SERVICE_SETUP.md`
- Networking: `NETWORK_CONFIG.md`
- Troubleshooting: `docker logs` or reference docs


## ARM Satellite Node Status (VOLTAIREDEUX)
- [x] ARM profile setup and tested (.env.arm, docker-compose.arm.yml)
- [x] Fixed port 8096 collision between Caddy and Jellyfin in root compose file
- [x] Isolated x64 services from ARM stack using profiles: [disabled]
- [x] MAIN_SERVER_HOST pointing to 192.168.4.21
- [x] LAN IP detection patched in start-arm.ps1 to ignore WSL vEthernet adapters
- [x] Playback debugging script created (Debug-Playback.ps1)
- [x] Automated Deduplication completed on OneDrive

## Agent Handoff Summary
The ARM node (VOLTAIREDEUX / 192.168.4.30) is fully functional and running the Music + Theming stack (Jellyfin, Caddy, Syncthing, Homepage, Diun). It successfully communicates with the x64 main server (VOLTAIREUN / 192.168.4.21).
Future agents: If managing the x64 machine, ensure the Syncthing folder is shared with this ARM node to allow theme synchronizations to propagate.
