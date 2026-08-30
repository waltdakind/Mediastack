# 🤖 AI Autoheal Handoff: `transmission`

| Field            | Value |
|------------------|-------|
| **Container**    | `transmission` |
| **Timestamp**    | 2026-08-22 14:34:00 (-04:00) |
| **Trigger**      | Proxy returned 501 |
| **Handoff File** | `C:\Users\Public\MediaStack\handoffs\AI_Handoff_transmission_20260822_143400.md` |
| **Config Path**  | `C:\Users\Public\MediaStack\transmission\config` |

---




---

## 📋 Environment Variables

| Variable | Value |
|----------|-------|
| `PUID` | `1000` |
| `PGID` | `1000` |
| `TZ` | `America/New_York` |
| `PATH` | `/lsiopy/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin` |
| `PS1` | `$(whoami)@$(hostname):$(pwd)\$ ` |
| `HOME` | `/root` |
| `TERM` | `xterm` |
| `S6_CMD_WAIT_FOR_SERVICES_MAXTIME` | `0` |
| `S6_VERBOSITY` | `1` |
| `S6_STAGE2_HOOK` | `/docker-mods` |
| `VIRTUAL_ENV` | `/lsiopy` |
| `LSIO_FIRST_PARTY` | `true` |


---

## 🔍 Process Tree at Time of Failure

`	ext
UID                 PID                 PPID                C                   STIME               TTY                 TIME                CMD root                14811               14786               0                   18:27               ?                   00:00:00            /package/admin/s6/command/s6-svscan -d4 -- /run/service root                14874               14811               0                   18:28               ?                   00:00:00            s6-supervise s6-linux-init-shutdownd root                14877               14874               0                   18:28               ?                   00:00:00            /package/admin/s6-linux-init/command/s6-linux-init-shutdownd -d3 -c /run/s6/basedir -g 3000 -C -B root                14893               14811               0                   18:28               ?                   00:00:00            s6-supervise svc-transmission root                14894               14811               0                   18:28               ?                   00:00:00            s6-supervise s6rc-fdholder root                14895               14811               0                   18:28               ?                   00:00:00            s6-supervise svc-cron root                14896               14811               0                   18:28               ?                   00:00:00            s6-supervise s6rc-oneshot-runner root                14904               14896               0                   18:28               ?                   00:00:00            /package/admin/s6/command/s6-ipcserverd -1 -- /package/admin/s6/command/s6-ipcserver-access -v0 -E -l0 -i data/rules -- /package/admin/s6/command/s6-sudod -t 30000 -- /package/admin/s6-rc/command/s6-rc-oneshot-run -l ../.. -- root                15020               14895               0                   18:28               ?                   00:00:00            busybox crond -f -S -l 5 root                15021               14893               0                   18:28               ?                   00:00:00            bash ./run svc-transmission 1000                15029               15021               0                   18:28               ?                   00:00:01            /usr/bin/transmission-daemon -g /config -f
`

---

## 📁 Volume / Config Directory Tree

> Host path mapped to `/config` inside the container (max 3 levels deep).

`	ext
Path                                                      Size        
----                                                      ----        
blocklists                                                <DIR>       
resume                                                    <DIR>       
torrents                                                  <DIR>       
bandwidth-groups.json                                     2 bytes     
dht.dat                                                   721 bytes   
queue.json                                                282 bytes   
settings.json                                             3000 bytes  
stats.json                                                149 bytes   
resume\17e6807250b8932e5f30c0086dd398edb9630138.resume    189282 bytes
resume\355271a91d3f6b969d938298326c3e0b50a73df7.resume    1964 bytes  
resume\41f459ebf0aea0c48987a209f7fb877c539ced99.resume    661560 bytes
resume\4ea929ab7ab306c323bfc93b96fa6833c2be1e67.resume    2937 bytes  
resume\d7b21ca3a5556b8012a65b37b9484f2e0c0bdda5.resume    712051 bytes
torrents\17e6807250b8932e5f30c0086dd398edb9630138.torrent 69388 bytes 
torrents\355271a91d3f6b969d938298326c3e0b50a73df7.torrent 6963 bytes  
torrents\41f459ebf0aea0c48987a209f7fb877c539ced99.torrent 123776 bytes
torrents\4ea929ab7ab306c323bfc93b96fa6833c2be1e67.torrent 25134 bytes 
torrents\d7b21ca3a5556b8012a65b37b9484f2e0c0bdda5.torrent 110994 bytes
`

---

## ⚙️ Configuration Files


### `settings.json`
> Path: `C:\Users\Public\MediaStack\transmission\config\settings.json`
> Size: 3000 bytes | Last Modified: 08/22/2026 14:28:00

```json
{
    "alt-speed-down": 50,
    "alt-speed-enabled": false,
    "alt-speed-time-begin": 540,
    "alt-speed-time-day": 127,
    "alt-speed-time-enabled": false,
    "alt-speed-time-end": 1020,
    "alt-speed-up": 50,
    "announce-ip": "",
    "announce-ip-enabled": false,
    "anti-brute-force-enabled": false,
    "anti-brute-force-threshold": 100,
    "bind-address-ipv4": "0.0.0.0",
    "bind-address-ipv6": "::",
    "blocklist-enabled": false,
    "blocklist-url": "http://www.example.com/blocklist",
    "cache-size-mb": 4,
    "default-trackers": "",
    "dht-enabled": true,
    "download-dir": "/downloads/complete",
    "download-queue-enabled": true,
    "download-queue-size": 5,
    "encryption": 1,
    "idle-seeding-limit": 30,
    "idle-seeding-limit-enabled": false,
    "incomplete-dir": "/downloads/incomplete",
    "incomplete-dir-enabled": true,
    "lpd-enabled": false,
    "message-level": 2,
    "peer-congestion-algorithm": "",
    "peer-id-ttl-hours": 6,
    "peer-limit-global": 200,
    "peer-limit-per-torrent": 50,
    "peer-port": 51413,
    "peer-port-random-high": 65535,
    "peer-port-random-low": 49152,
    "peer-port-random-on-start": false,
    "peer-socket-tos": "le",
    "pex-enabled": true,
    "pidfile": "",
    "port-forwarding-enabled": true,
    "preallocation": 1,
    "preferred_transports": [
        "tcp"
    ],
    "prefetch-enabled": 1,
    "proxy_url": null,
    "queue-stalled-enabled": true,
    "queue-stalled-minutes": 30,
    "ratio-limit": 2.0,
    "ratio-limit-enabled": false,
    "rename-partial-files": true,
    "reqq": 2000,
    "rpc-authentication-required": false,
    "rpc-bind-address": "[::]",
    "rpc-enabled": true,
    "rpc-host-whitelist": "127.0.0.1",
    "rpc-host-whitelist-enabled": false,
    "rpc-password": "{1ddd3f1f6a71d655cde7767242a23a575b44c909n5YuRT.f",
    "rpc-port": 9091,
    "rpc-socket-mode": "0750",
    "rpc-url": "/transmission/",
    "rpc-username": "",
    "rpc-whitelist": "127.0.0.1",
    "rpc-whitelist-enabled": false,
    "scrape-paused-torrents-enabled": true,
    "script-torrent-added-enabled": false,
    "script-torrent-added-filename": "",
    "script-torrent-done-enabled": false,
    "script-torrent-done-filename": "",
    "script-torrent-done-seeding-enabled": false,
    "script-torrent-done-seeding-filename": "",
    "seed-queue-enabled": false,
    "seed-queue-size": 10,
    "sequential_download": false,
    "sleep-per-seconds-during-verify": 100,
    "speed-limit-down": 100,
    "speed-limit-down-enabled": false,
    "speed-limit-up": 100,
    "speed-limit-up-enabled": false,
    "start-added-torrents": true,
    "start_paused": false,
    "tcp-enabled": true,
    "torrent-added-verify-mode": "fast",
    "torrent_complete_verify_enabled": false,
    "trash-original-torrent-files": false,
    "umask": "002",
    "upload-slots-per-torrent": 14,
    "utp-enabled": false,
    "watch-dir": "/watch",
    "watch-dir-enabled": true,
    "watch-dir-force-generic": false
}
```


---

## 📜 Recent Logs (last 150 lines with timestamps)

`	ext
2026-08-22T18:24:09.087186282Z [migrations] no migrations found 2026-08-22T18:24:09.097263088Z usermod: no changes 2026-08-22T18:24:09.098967157Z ─────────────────────────────────────── 2026-08-22T18:24:09.098975957Z  2026-08-22T18:24:09.098977957Z       ██╗     ███████╗██╗ ██████╗ 2026-08-22T18:24:09.098980057Z       ██║     ██╔════╝██║██╔═══██╗ 2026-08-22T18:24:09.098981957Z       ██║     ███████╗██║██║   ██║ 2026-08-22T18:24:09.098983857Z       ██║     ╚════██║██║██║   ██║ 2026-08-22T18:24:09.098985757Z       ███████╗███████║██║╚██████╔╝ 2026-08-22T18:24:09.098987657Z       ╚══════╝╚══════╝╚═╝ ╚═════╝ 2026-08-22T18:24:09.098989558Z  2026-08-22T18:24:09.098991258Z    Brought to you by linuxserver.io 2026-08-22T18:24:09.098993258Z ─────────────────────────────────────── 2026-08-22T18:24:09.099351772Z  2026-08-22T18:24:09.099356172Z To support LSIO projects visit: 2026-08-22T18:24:09.099366273Z https://www.linuxserver.io/donate/ 2026-08-22T18:24:09.099367773Z  2026-08-22T18:24:09.099369073Z ─────────────────────────────────────── 2026-08-22T18:24:09.099372673Z GID/UID 2026-08-22T18:24:09.099374073Z ─────────────────────────────────────── 2026-08-22T18:24:09.102469598Z  2026-08-22T18:24:09.102485598Z User UID:    1000 2026-08-22T18:24:09.102487299Z User GID:    1000 2026-08-22T18:24:09.102488699Z ─────────────────────────────────────── 2026-08-22T18:24:09.103683647Z Linuxserver.io version: 4.1.3-r0-ls357 2026-08-22T18:24:09.103877855Z Build-date: 2026-08-04T12:22:56+00:00 2026-08-22T18:24:09.103883155Z ─────────────────────────────────────── 2026-08-22T18:24:09.103955758Z      2026-08-22T18:24:09.150335127Z ln: failed to create symbolic link '/transmissionic/index.html': File exists 2026-08-22T18:24:09.151939192Z ln: failed to create symbolic link '/combustion-release/index.html': File exists 2026-08-22T18:24:09.153134240Z ln: failed to create symbolic link '/flood-for-transmission/index.html': File exists 2026-08-22T18:24:09.154790907Z ln: failed to create symbolic link '/kettu/index.html': File exists 2026-08-22T18:24:09.156182563Z ln: failed to create symbolic link '/transmission-web-control/index.html': File exists 2026-08-22T18:24:09.206266182Z [custom-init] No custom files found, skipping... 2026-08-22T18:24:10.233024414Z Connection to localhost (::1) 9091 port [tcp/*] succeeded! 2026-08-22T18:24:10.246208547Z [ls.io-init] done. 2026-08-22T18:25:23.064120928Z 127.0.0.1:9091/transmission/rpc/ acknowledged notification 2026-08-22T18:25:26.626326582Z [migrations] started 2026-08-22T18:25:26.626354283Z [migrations] no migrations found 2026-08-22T18:25:26.637952154Z usermod: no changes 2026-08-22T18:25:26.639379012Z ─────────────────────────────────────── 2026-08-22T18:25:26.639392913Z  2026-08-22T18:25:26.639395113Z       ██╗     ███████╗██╗ ██████╗ 2026-08-22T18:25:26.639397313Z       ██║     ██╔════╝██║██╔═══██╗ 2026-08-22T18:25:26.639399213Z       ██║     ███████╗██║██║   ██║ 2026-08-22T18:25:26.639401213Z       ██║     ╚════██║██║██║   ██║ 2026-08-22T18:25:26.639403113Z       ███████╗███████║██║╚██████╔╝ 2026-08-22T18:25:26.639405013Z       ╚══════╝╚══════╝╚═╝ ╚═════╝ 2026-08-22T18:25:26.639417814Z  2026-08-22T18:25:26.639419214Z    Brought to you by linuxserver.io 2026-08-22T18:25:26.639420614Z ─────────────────────────────────────── 2026-08-22T18:25:26.639628522Z  2026-08-22T18:25:26.639632522Z To support LSIO projects visit: 2026-08-22T18:25:26.639634222Z https://www.linuxserver.io/donate/ 2026-08-22T18:25:26.639635623Z  2026-08-22T18:25:26.639637023Z ─────────────────────────────────────── 2026-08-22T18:25:26.639638623Z GID/UID 2026-08-22T18:25:26.639640023Z ─────────────────────────────────────── 2026-08-22T18:25:26.642725948Z  2026-08-22T18:25:26.642734948Z User UID:    1000 2026-08-22T18:25:26.642736348Z User GID:    1000 2026-08-22T18:25:26.642737748Z ─────────────────────────────────────── 2026-08-22T18:25:26.644022201Z Linuxserver.io version: 4.1.3-r0-ls357 2026-08-22T18:25:26.644033901Z Build-date: 2026-08-04T12:22:56+00:00 2026-08-22T18:25:26.644035601Z ─────────────────────────────────────── 2026-08-22T18:25:26.644037601Z      2026-08-22T18:25:26.692791381Z ln: failed to create symbolic link '/transmissionic/index.html': File exists 2026-08-22T18:25:26.694253340Z ln: failed to create symbolic link '/combustion-release/index.html': File exists 2026-08-22T18:25:26.695491791Z ln: failed to create symbolic link '/flood-for-transmission/index.html': File exists 2026-08-22T18:25:26.696744242Z ln: failed to create symbolic link '/kettu/index.html': File exists 2026-08-22T18:25:26.698003293Z ln: failed to create symbolic link '/transmission-web-control/index.html': File exists 2026-08-22T18:25:26.748520744Z [custom-init] No custom files found, skipping... 2026-08-22T18:25:27.776713497Z Connection to localhost (::1) 9091 port [tcp/*] succeeded! 2026-08-22T18:25:27.790266647Z [ls.io-init] done. 2026-08-22T18:26:39.934595268Z 127.0.0.1:9091/transmission/rpc/ acknowledged notification 2026-08-22T18:26:43.457142064Z [migrations] started 2026-08-22T18:26:43.457171065Z [migrations] no migrations found 2026-08-22T18:26:43.468389016Z usermod: no changes 2026-08-22T18:26:43.469927178Z ─────────────────────────────────────── 2026-08-22T18:26:43.469947179Z  2026-08-22T18:26:43.469949479Z       ██╗     ███████╗██╗ ██████╗ 2026-08-22T18:26:43.469960779Z       ██║     ██╔════╝██║██╔═══██╗ 2026-08-22T18:26:43.469962479Z       ██║     ███████╗██║██║   ██║ 2026-08-22T18:26:43.469963879Z       ██║     ╚════██║██║██║   ██║ 2026-08-22T18:26:43.469965379Z       ███████╗███████║██║╚██████╔╝ 2026-08-22T18:26:43.469966879Z       ╚══════╝╚══════╝╚═╝ ╚═════╝ 2026-08-22T18:26:43.469968279Z  2026-08-22T18:26:43.469969679Z    Brought to you by linuxserver.io 2026-08-22T18:26:43.469971080Z ─────────────────────────────────────── 2026-08-22T18:26:43.470202189Z  2026-08-22T18:26:43.470208289Z To support LSIO projects visit: 2026-08-22T18:26:43.470209789Z https://www.linuxserver.io/donate/ 2026-08-22T18:26:43.470211289Z  2026-08-22T18:26:43.470212889Z ─────────────────────────────────────── 2026-08-22T18:26:43.470215189Z GID/UID 2026-08-22T18:26:43.470216589Z ─────────────────────────────────────── 2026-08-22T18:26:43.473189709Z  2026-08-22T18:26:43.473196909Z User UID:    1000 2026-08-22T18:26:43.473198509Z User GID:    1000 2026-08-22T18:26:43.473199809Z ─────────────────────────────────────── 2026-08-22T18:26:43.474206850Z Linuxserver.io version: 4.1.3-r0-ls357 2026-08-22T18:26:43.474436159Z Build-date: 2026-08-04T12:22:56+00:00 2026-08-22T18:26:43.474440359Z ─────────────────────────────────────── 2026-08-22T18:26:43.474442059Z      2026-08-22T18:26:43.517894406Z ln: failed to create symbolic link '/transmissionic/index.html': File exists 2026-08-22T18:26:43.518932448Z ln: failed to create symbolic link '/combustion-release/index.html': File exists 2026-08-22T18:26:43.520244901Z ln: failed to create symbolic link '/flood-for-transmission/index.html': File exists 2026-08-22T18:26:43.521792863Z ln: failed to create symbolic link '/kettu/index.html': File exists 2026-08-22T18:26:43.522925308Z ln: failed to create symbolic link '/transmission-web-control/index.html': File exists 2026-08-22T18:26:43.570936238Z [custom-init] No custom files found, skipping... 2026-08-22T18:26:44.597510508Z Connection to localhost (::1) 9091 port [tcp/*] succeeded! 2026-08-22T18:26:44.608150535Z [ls.io-init] done. 2026-08-22T18:27:56.617199053Z 127.0.0.1:9091/transmission/rpc/ acknowledged notification 2026-08-22T18:28:00.185394869Z [migrations] started 2026-08-22T18:28:00.185435470Z [migrations] no migrations found 2026-08-22T18:28:00.197188736Z usermod: no changes 2026-08-22T18:28:00.199226017Z ─────────────────────────────────────── 2026-08-22T18:28:00.199237817Z  2026-08-22T18:28:00.199239417Z       ██╗     ███████╗██╗ ██████╗ 2026-08-22T18:28:00.199241017Z       ██║     ██╔════╝██║██╔═══██╗ 2026-08-22T18:28:00.199242417Z       ██║     ███████╗██║██║   ██║ 2026-08-22T18:28:00.199244117Z       ██║     ╚════██║██║██║   ██║ 2026-08-22T18:28:00.199246017Z       ███████╗███████║██║╚██████╔╝ 2026-08-22T18:28:00.199247617Z       ╚══════╝╚══════╝╚═╝ ╚═════╝ 2026-08-22T18:28:00.199249017Z  2026-08-22T18:28:00.199253018Z    Brought to you by linuxserver.io 2026-08-22T18:28:00.199254418Z ─────────────────────────────────────── 2026-08-22T18:28:00.199722436Z  2026-08-22T18:28:00.199745537Z To support LSIO projects visit: 2026-08-22T18:28:00.199747137Z https://www.linuxserver.io/donate/ 2026-08-22T18:28:00.199749037Z  2026-08-22T18:28:00.199750437Z ─────────────────────────────────────── 2026-08-22T18:28:00.199752137Z GID/UID 2026-08-22T18:28:00.199753537Z ─────────────────────────────────────── 2026-08-22T18:28:00.203258976Z  2026-08-22T18:28:00.203272277Z User UID:    1000 2026-08-22T18:28:00.203273677Z User GID:    1000 2026-08-22T18:28:00.203275077Z ─────────────────────────────────────── 2026-08-22T18:28:00.204519826Z Linuxserver.io version: 4.1.3-r0-ls357 2026-08-22T18:28:00.205007345Z Build-date: 2026-08-04T12:22:56+00:00 2026-08-22T18:28:00.205011746Z ─────────────────────────────────────── 2026-08-22T18:28:00.205013446Z      2026-08-22T18:28:00.253435063Z ln: failed to create symbolic link '/transmissionic/index.html': File exists 2026-08-22T18:28:00.255295937Z ln: failed to create symbolic link '/combustion-release/index.html': File exists 2026-08-22T18:28:00.256400481Z ln: failed to create symbolic link '/flood-for-transmission/index.html': File exists 2026-08-22T18:28:00.257896640Z ln: failed to create symbolic link '/kettu/index.html': File exists 2026-08-22T18:28:00.259084787Z ln: failed to create symbolic link '/transmission-web-control/index.html': File exists 2026-08-22T18:28:00.310289815Z [custom-init] No custom files found, skipping... 2026-08-22T18:28:01.338902852Z Connection to localhost (::1) 9091 port [tcp/*] succeeded! 2026-08-22T18:28:01.348909049Z [ls.io-init] done.
`

---

## 🐳 Full Docker Inspect

`json
[     {         "Id": "dcf3f6b905034071517f2b555b1121b9ea73ead1be887a7c544b5f5df9ddd370",         "Created": "2026-08-22T16:25:37.12060273Z",         "Path": "/init",         "Args": [],         "State": {             "Status": "running",             "Running": true,             "Paused": false,             "Restarting": false,             "OOMKilled": false,             "Dead": false,             "Pid": 14811,             "ExitCode": 0,             "Error": "",             "StartedAt": "2026-08-22T18:27:59.929605438Z",             "FinishedAt": "2026-08-22T18:27:59.614973678Z"         },         "Image": "sha256:81787bc706d3833d252e6d8b94545fea46bf2156f616320991a395619a477d2c",         "ResolvConfPath": "/var/lib/docker/containers/dcf3f6b905034071517f2b555b1121b9ea73ead1be887a7c544b5f5df9ddd370/resolv.conf",         "HostnamePath": "/var/lib/docker/containers/dcf3f6b905034071517f2b555b1121b9ea73ead1be887a7c544b5f5df9ddd370/hostname",         "HostsPath": "/var/lib/docker/containers/dcf3f6b905034071517f2b555b1121b9ea73ead1be887a7c544b5f5df9ddd370/hosts",         "LogPath": "/var/lib/docker/containers/dcf3f6b905034071517f2b555b1121b9ea73ead1be887a7c544b5f5df9ddd370/dcf3f6b905034071517f2b555b1121b9ea73ead1be887a7c544b5f5df9ddd370-json.log",         "Name": "/transmission",         "RestartCount": 0,         "Driver": "overlayfs",         "Platform": "linux",         "MountLabel": "",         "ProcessLabel": "",         "AppArmorProfile": "",         "ExecIDs": null,         "HostConfig": {             "Binds": [                 "C:\\Users\\Public\\MediaStack\\downloads:/downloads:rw",                 "C:\\Users\\Public\\MediaStack\\downloads\\watch:/watch:rw",                 "C:\\Users\\Public\\MediaStack\\transmission\\config:/config:rw"             ],             "ContainerIDFile": "",             "LogConfig": {                 "Type": "json-file",                 "Config": {}             },             "NetworkMode": "mediastack_default",             "PortBindings": {                 "51413/tcp": [                     {                         "HostIp": "",                         "HostPort": "51413"                     }                 ],                 "51413/udp": [                     {                         "HostIp": "",                         "HostPort": "51413"                     }                 ],                 "9091/tcp": [                     {                         "HostIp": "",                         "HostPort": "9091"                     }                 ]             },             "RestartPolicy": {                 "Name": "unless-stopped",                 "MaximumRetryCount": 0             },             "AutoRemove": false,             "VolumeDriver": "",             "VolumesFrom": null,             "ConsoleSize": [                 0,                 0             ],             "CapAdd": null,             "CapDrop": null,             "CgroupnsMode": "private",             "Dns": null,             "DnsOptions": null,             "DnsSearch": null,             "ExtraHosts": [],             "GroupAdd": null,             "IpcMode": "private",             "Cgroup": "",             "Links": null,             "OomScoreAdj": 0,             "PidMode": "",             "Privileged": false,             "PublishAllPorts": false,             "ReadonlyRootfs": false,             "SecurityOpt": null,             "UTSMode": "",             "UsernsMode": "",             "ShmSize": 67108864,             "Runtime": "runc",             "Isolation": "",             "CpuShares": 0,             "Memory": 0,             "NanoCpus": 0,             "CgroupParent": "",             "BlkioWeight": 0,             "BlkioWeightDevice": null,             "BlkioDeviceReadBps": null,             "BlkioDeviceWriteBps": null,             "BlkioDeviceReadIOps": null,             "BlkioDeviceWriteIOps": null,             "CpuPeriod": 0,             "CpuQuota": 0,             "CpuRealtimePeriod": 0,             "CpuRealtimeRuntime": 0,             "CpusetCpus": "",             "CpusetMems": "",             "Devices": null,             "DeviceCgroupRules": null,             "DeviceRequests": null,             "MemoryReservation": 0,             "MemorySwap": 0,             "MemorySwappiness": null,             "OomKillDisable": null,             "PidsLimit": null,             "Ulimits": null,             "CpuCount": 0,             "CpuPercent": 0,             "IOMaximumIOps": 0,             "IOMaximumBandwidth": 0,             "MaskedPaths": [                 "/proc/acpi",                 "/proc/asound",                 "/proc/interrupts",                 "/proc/kcore",                 "/proc/keys",                 "/proc/latency_stats",                 "/proc/sched_debug",                 "/proc/scsi",                 "/proc/timer_list",                 "/proc/timer_stats",                 "/sys/devices/virtual/powercap",                 "/sys/firmware"             ],             "ReadonlyPaths": [                 "/proc/bus",                 "/proc/fs",                 "/proc/irq",                 "/proc/sys",                 "/proc/sysrq-trigger"             ]         },         "Storage": {             "RootFS": {                 "Snapshot": {                     "Name": "overlayfs"                 }             }         },         "Mounts": [             {                 "Type": "bind",                 "Source": "C:\\Users\\Public\\MediaStack\\transmission\\config",                 "Destination": "/config",                 "Mode": "rw",                 "RW": true,                 "Propagation": "rprivate"             },             {                 "Type": "bind",                 "Source": "C:\\Users\\Public\\MediaStack\\downloads",                 "Destination": "/downloads",                 "Mode": "rw",                 "RW": true,                 "Propagation": "rprivate"             },             {                 "Type": "bind",                 "Source": "C:\\Users\\Public\\MediaStack\\downloads\\watch",                 "Destination": "/watch",                 "Mode": "rw",                 "RW": true,                 "Propagation": "rprivate"             }         ],         "Config": {             "Hostname": "dcf3f6b90503",             "Domainname": "",             "User": "",             "AttachStdin": false,             "AttachStdout": true,             "AttachStderr": true,             "ExposedPorts": {                 "51413/tcp": {},                 "51413/udp": {},                 "9091/tcp": {}             },             "Tty": false,             "OpenStdin": false,             "StdinOnce": false,             "Env": [                 "PUID=1000",                 "PGID=1000",                 "TZ=America/New_York",                 "PATH=/lsiopy/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin",                 "PS1=$(whoami)@$(hostname):$(pwd)\\$ ",                 "HOME=/root",                 "TERM=xterm",                 "S6_CMD_WAIT_FOR_SERVICES_MAXTIME=0",                 "S6_VERBOSITY=1",                 "S6_STAGE2_HOOK=/docker-mods",                 "VIRTUAL_ENV=/lsiopy",                 "LSIO_FIRST_PARTY=true"             ],             "Cmd": null,             "Image": "lscr.io/linuxserver/transmission:latest",             "Volumes": {                 "/config": {}             },             "WorkingDir": "/",             "Entrypoint": [                 "/init"             ],             "Labels": {                 "build_version": "Linuxserver.io version:- 4.1.3-r0-ls357 Build-date:- 2026-08-04T12:22:56+00:00",                 "com.docker.compose.config-hash": "9e3331203f799a891b006d7e7fd32beab8ad4e1ded872c3bf096299a3dd93d00",                 "com.docker.compose.container-number": "1",                 "com.docker.compose.depends_on": "",                 "com.docker.compose.image": "sha256:81787bc706d3833d252e6d8b94545fea46bf2156f616320991a395619a477d2c",                 "com.docker.compose.oneoff": "False",                 "com.docker.compose.project": "mediastack",                 "com.docker.compose.project.config_files": "C:\\Users\\Public\\MediaStack\\docker-compose.yml",                 "com.docker.compose.project.working_dir": "C:\\Users\\Public\\MediaStack",                 "com.docker.compose.service": "transmission",                 "com.docker.compose.version": "5.3.1",                 "maintainer": "aptalca",                 "org.opencontainers.image.authors": "linuxserver.io",                 "org.opencontainers.image.created": "2026-08-04T12:22:56+00:00",                 "org.opencontainers.image.description": "[Transmission](https://www.transmissionbt.com/) is designed for easy, powerful use. Transmission has the features you want from a BitTorrent client: encryption, a web interface, peer exchange, magnet links, DHT, µTP, UPnP and NAT-PMP port forwarding, webseed support, watch directories, tracker editing, global and per-torrent speed limits, and more.",                 "org.opencontainers.image.documentation": "https://docs.linuxserver.io/images/docker-transmission",                 "org.opencontainers.image.licenses": "GPL-3.0-only",                 "org.opencontainers.image.ref.name": "cd648f76f76d0f745b91c295ccf784510774f74c",                 "org.opencontainers.image.revision": "cd648f76f76d0f745b91c295ccf784510774f74c",                 "org.opencontainers.image.source": "https://github.com/linuxserver/docker-transmission",                 "org.opencontainers.image.title": "Transmission",                 "org.opencontainers.image.url": "https://github.com/linuxserver/docker-transmission/packages",                 "org.opencontainers.image.vendor": "linuxserver.io",                 "org.opencontainers.image.version": "4.1.3-r0-ls357"             }         },         "NetworkSettings": {             "SandboxID": "c054896e12f6540b862074fd7dbdd0507df32384d26767c7ea1c088b07781cd8",             "SandboxKey": "/var/run/docker/netns/c054896e12f6",             "Ports": {                 "51413/tcp": [                     {                         "HostIp": "0.0.0.0",                         "HostPort": "51413"                     },                     {                         "HostIp": "::",                         "HostPort": "51413"                     }                 ],                 "51413/udp": [                     {                         "HostIp": "0.0.0.0",                         "HostPort": "51413"                     },                     {                         "HostIp": "::",                         "HostPort": "51413"                     }                 ],                 "9091/tcp": [                     {                         "HostIp": "0.0.0.0",                         "HostPort": "9091"                     },                     {                         "HostIp": "::",                         "HostPort": "9091"                     }                 ]             },             "Networks": {                 "mediastack_default": {                     "IPAMConfig": null,                     "Links": null,                     "Aliases": [                         "transmission",                         "transmission"                     ],                     "DriverOpts": null,                     "GwPriority": 0,                     "NetworkID": "c1e26df2c8f37ebab98723ad4966bf4ccf8003b0e0f126e2b55837866af60ad7",                     "EndpointID": "c8a03b4ded65370b0761cf74d89191e27aa9f7ed88b1bb63a62ab3ac3349f630",                     "Gateway": "172.18.0.1",                     "IPAddress": "172.18.0.10",                     "MacAddress": "0e:00:67:81:14:75",                     "IPPrefixLen": 16,                     "IPv6Gateway": "",                     "GlobalIPv6Address": "",                     "GlobalIPv6PrefixLen": 0,                     "DNSNames": [                         "transmission",                         "dcf3f6b90503"                     ]                 }             }         },         "ImageManifestDescriptor": {             "mediaType": "application/vnd.oci.image.manifest.v1+json",             "digest": "sha256:5a364e7d2bcf35329538664d2595cf505ea97db5ad6240a7de72885b6e3efb10",             "size": 2189,             "platform": {                 "architecture": "arm64",                 "os": "linux"             }         }     } ]
`

---

*This handoff was automatically generated by the MediaStack Autohealer.*
*To assist with this failure, paste this entire file into an AI assistant chat.*
