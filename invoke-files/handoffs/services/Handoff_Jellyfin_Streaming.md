# Expert Operational Handoff: Jellyfin Streaming Server

| Architectural Parameter | Runtime Specification |
| :--- | :--- |
| **Service Key** | jellyfin |
| **Display Name** | Jellyfin Streaming Server |
| **Service Category** | Streaming |
| **Container Name** | jellyfin |
| **Image Tag** | lscr.io/linuxserver/jellyfin:latest |
| **Primary Ingress Port** | 8096 |
| **Associated Storage/DB**| jellyfin.db |
| **Container Status** | **RUNNING** |
| **Restart Count** | 0 |
| **Container Started** | 2026-09-05T15:08:57.9504467Z |
| **L7 Response Code** | HTTP 302 |
| **TTFB Latency** | 10.9 ms |
| **Vault Secrets Status**| SYSTEM MANAGED |
| **Error Lines Detected**| 0 |
| **Audit Timestamp** | 2026-09-05 12:09:46 |

---

## 1. Network & Reverse-Proxy Topology
- **Local Ingress Endpoint:** `http://localhost:8096/`
- **Caddy Virtual Host Route:** `http://jellyfin.voltairedeux.local/`
- **Peer Cluster Gateway:** `http://192.168.4.30:8096/`
- **Security Policy:** TLS 1.3 / Reverse-Proxy Ingress isolated via Caddy network.

---

## 2. Storage & Database Layout
- **Host Config Root:** `C:\MediastackConfig\jellyfin`
- **Active Database File:** `jellyfin.db`
- **Persistent Media Mounts:** `C:\MediastackShares\` (Music, TV, Videos, Radio, Podcasts)
- **Lock Management:** SQLite WAL with zero-downtime checkpoints.

---

## 3. Inter-Service Handshake Matrix
- **Upstream Gateway:** Caddy Reverse Proxy (`caddy:80/443`)
- **Downstream Dependencies:** `mediastack-db`, `redis`, `postgres`
- **Cluster Peer Target:** VoltaireUn (`192.168.4.21`) via reciprocal SMB & Syncthing mesh.

---

## 4. Diagnostic Log Mining & Health Assessment
### Log Extraction (Last 40 Lines)
`	ext
[11:10:33] [INF] [9] Emby.Server.Implementations.Plugins.PluginManager: Loaded plugin: AudioDB 10.11.11.0
[11:10:33] [INF] [9] Jellyfin.Server.Migrations.JellyfinMigrationService: There are 0 migrations for stage AppInitialisation.
[11:10:33] [INF] [9] Main: Kestrel is listening on all interfaces
[11:10:34] [WRN] [9] Microsoft.AspNetCore.StaticFiles.StaticFileMiddleware: The WebRootPath was not found: /run/s6-rc:s6-rc-init:JKfOEF/servicedirs/svc-jellyfin/wwwroot. Static files may be unavailable.
[11:10:34] [INF] [9] Emby.Server.Implementations.ApplicationHost: Running startup tasks
[11:10:34] [INF] [11] Emby.Server.Implementations.IO.LibraryMonitor: Watching directory /data/videos
[11:10:34] [INF] [9] Emby.Server.Implementations.ScheduledTasks.TaskManager: Daily trigger for Generate Trickplay Images set to fire at 2026-09-06 03:00:00.000 -04:00, which is 15:49:25.1316175 from now.
[11:10:34] [INF] [9] Emby.Server.Implementations.ScheduledTasks.TaskManager: Daily trigger for Audio Normalization set to fire at 2026-09-06 00:00:00.000 -04:00, which is 12:49:25.0553377 from now.
[11:10:34] [INF] [9] Emby.Server.Implementations.ScheduledTasks.TaskManager: Daily trigger for Extract Chapter Images set to fire at 2026-09-06 02:00:00.000 -04:00, which is 14:49:25.0437736 from now.
[11:10:35] [INF] [15] Emby.Server.Implementations.IO.LibraryMonitor: Watching directory /data/downloads
[11:10:35] [INF] [7] Emby.Server.Implementations.IO.LibraryMonitor: Watching directory /data/music
[11:10:35] [INF] [9] MediaBrowser.MediaEncoding.Encoder.MediaEncoder: Found ffmpeg version 7.1.4
[11:10:35] [INF] [9] MediaBrowser.MediaEncoding.Encoder.MediaEncoder: Available decoders: ["libdav1d", "av1", "av1_cuvid", "av1_rkmpp", "h264", "h264_rkmpp", "h264_cuvid", "hevc", "hevc_rkmpp", "hevc_cuvid", "mpeg1_rkmpp", "mpeg2video", "mpeg2_rkmpp", "mpeg2_cuvid", "mpeg4", "mpeg4_rkmpp", "mpeg4_cuvid", "msmpeg4", "vc1_cuvid", "vp8", "vp8_rkmpp", "libvpx", "vp8_cuvid", "vp9", "vp9_rkmpp", "libvpx-vp9", "vp9_cuvid", "aac", "ac3", "ac4", "dca", "flac", "mp3", "truehd"]
[11:10:35] [INF] [9] MediaBrowser.MediaEncoding.Encoder.MediaEncoder: Available encoders: ["libsvtav1", "av1_nvenc", "libx264", "h264_nvenc", "h264_v4l2m2m", "h264_rkmpp", "libx265", "hevc_nvenc", "hevc_rkmpp", "mjpeg_rkmpp", "aac", "libfdk_aac", "ac3", "alac", "dca", "flac", "libmp3lame", "libopus", "truehd", "libvorbis", "srt"]
[11:10:35] [INF] [9] MediaBrowser.MediaEncoding.Encoder.MediaEncoder: Available filters: ["bwdif_cuda", "bwdif_opencl", "hwupload_cuda", "overlay_opencl", "overlay_cuda", "overlay_rkrga", "scale_cuda", "scale_opencl", "scale_rkrga", "tonemapx", "tonemap_cuda", "tonemap_opencl", "transpose_cuda", "transpose_opencl", "vpp_rkrga", "yadif_cuda", "yadif_opencl", "zscale", "alphasrc"]
[11:10:35] [WRN] [9] MediaBrowser.MediaEncoding.Encoder.MediaEncoder: Filter: overlay_vaapi with option Action to take when encountering EOF from secondary input is not available
[11:10:35] [WRN] [9] MediaBrowser.MediaEncoding.Encoder.MediaEncoder: Filter: overlay_vulkan with option Action to take when encountering EOF from secondary input is not available
[11:10:35] [INF] [9] MediaBrowser.MediaEncoding.Encoder.MediaEncoder: Available hwaccel types: ["cuda", "drm", "opencl", "rkmpp"]
[11:10:37] [INF] [15] Emby.Server.Implementations.ScheduledTasks.TaskManager: Clean up collections and playlists Completed after 0 minute(s) and 0 seconds
[11:10:38] [INF] [14] Emby.Server.Implementations.ScheduledTasks.TaskManager: Clean Transcode Directory Completed after 0 minute(s) and 0 seconds
[11:10:41] [INF] [11] Emby.Server.Implementations.ScheduledTasks.TaskManager: Update Plugins Completed after 0 minute(s) and 2 seconds
[11:10:54] [INF] [9] MediaBrowser.MediaEncoding.Encoder.MediaEncoder: FFmpeg: /usr/lib/jellyfin-ffmpeg/ffmpeg
[11:10:54] [INF] [9] Emby.Server.Implementations.ApplicationHost: ServerId: d9fa4abb39204b6e9d680e4b8a0e7df9
[11:10:54] [INF] [9] Emby.Server.Implementations.ApplicationHost: Core startup complete
[11:10:54] [INF] [9] Main: Startup complete 0:01:50.9254764

`

---

## 5. Architectural Recommendations & Maintenance Tips
1. **Auto-Recovery:** If degraded, execute `.\Repair-jellyfin.ps1` or `.\Repair-MediaStackFleet.ps1 -Service Streaming`.
2. **Backup Strategy:** Included in atomic hot backup snapshot via `.\Backup-MediaStackFleet.ps1`.
3. **Replication Strategy:** Synchronized across Voltaire nodes via `.\Replicate-MediaStackCluster.ps1`.

---
*Generated autonomously by MediaStack Deep Analysis Engine.*
