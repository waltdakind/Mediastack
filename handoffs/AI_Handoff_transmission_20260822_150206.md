# ðŸ¤– AI Autoheal Handoff: `transmission`

| Field            | Value |
|------------------|-------|
| **Container**    | `transmission` |
| **Timestamp**    | 2026-08-22 15:02:07 (-04:00) |
| **Trigger**      | Proxy returned 501 |
| **Handoff File** | `C:\Users\Public\MediaStack\handoffs\AI_Handoff_transmission_20260822_150206.md` |
| **Config Path**  | `C:\Users\Public\MediaStack\transmission\config` |

---




---

## ðŸ“‹ Environment Variables

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

## ðŸ” Process Tree at Time of Failure

`	ext
UID                 PID                 PPID                C                   STIME               TTY                 TIME                CMD root                22337               22230               0                   18:51               ?                   00:00:00            /package/admin/s6/command/s6-svscan -d4 -- /run/service root                22786               22337               0                   18:51               ?                   00:00:00            s6-supervise s6-linux-init-shutdownd root                22789               22786               0                   18:51               ?                   00:00:00            /package/admin/s6-linux-init/command/s6-linux-init-shutdownd -d3 -c /run/s6/basedir -g 3000 -C -B root                22828               22337               0                   18:51               ?                   00:00:00            s6-supervise svc-transmission root                22829               22337               0                   18:51               ?                   00:00:00            s6-supervise s6rc-fdholder root                22830               22337               0                   18:51               ?                   00:00:00            s6-supervise svc-cron root                22831               22337               0                   18:51               ?                   00:00:00            s6-supervise s6rc-oneshot-runner root                22845               22831               0                   18:51               ?                   00:00:00            /package/admin/s6/command/s6-ipcserverd -1 -- /package/admin/s6/command/s6-ipcserver-access -v0 -E -l0 -i data/rules -- /package/admin/s6/command/s6-sudod -t 30000 -- /package/admin/s6-rc/command/s6-rc-oneshot-run -l ../.. -- root                23296               22828               0                   18:51               ?                   00:00:00            bash ./run svc-transmission root                23298               22830               0                   18:51               ?                   00:00:00            busybox crond -f -S -l 5 1000                23312               23296               0                   18:51               ?                   00:00:01            /usr/bin/transmission-daemon -g /config -f
`

---

## ðŸ“ Volume / Config Directory Tree

> Host path mapped to `/config` inside the container (max 3 levels deep).

`	ext
Path                                                      Size        
----                                                      ----        
blocklists                                                <DIR>       
resume                                                    <DIR>       
torrents                                                  <DIR>       
bandwidth-groups.json                                     2 bytes     
dht.dat                                                   631 bytes   
queue.json                                                282 bytes   
settings.json                                             3000 bytes  
stats.json                                                149 bytes   
resume\17e6807250b8932e5f30c0086dd398edb9630138.resume    189282 bytes
resume\355271a91d3f6b969d938298326c3e0b50a73df7.resume    3291 bytes  
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

## âš™ï¸ Configuration Files


### `settings.json`
> Path: `C:\Users\Public\MediaStack\transmission\config\settings.json`
> Size: 3000 bytes | Last Modified: 08/22/2026 14:51:13

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

## ðŸ“œ Recent Logs (last 150 lines with timestamps)

`	ext
2026-08-22T18:51:12.789721236Z [migrations] started 2026-08-22T18:51:12.789739437Z [migrations] no migrations found 2026-08-22T18:51:12.881655976Z ─────────────────────────────────────── 2026-08-22T18:51:12.881684077Z  2026-08-22T18:51:12.881685777Z       ██╗     ███████╗██╗ ██████╗ 2026-08-22T18:51:12.881687378Z       ██║     ██╔════╝██║██╔═══██╗ 2026-08-22T18:51:12.881696878Z       ██║     ███████╗██║██║   ██║ 2026-08-22T18:51:12.881698378Z       ██║     ╚════██║██║██║   ██║ 2026-08-22T18:51:12.881699678Z       ███████╗███████║██║╚██████╔╝ 2026-08-22T18:51:12.881701178Z       ╚══════╝╚══════╝╚═╝ ╚═════╝ 2026-08-22T18:51:12.881702678Z  2026-08-22T18:51:12.881704378Z    Brought to you by linuxserver.io 2026-08-22T18:51:12.881705779Z ─────────────────────────────────────── 2026-08-22T18:51:12.881951391Z  2026-08-22T18:51:12.881958192Z To support LSIO projects visit: 2026-08-22T18:51:12.881959892Z https://www.linuxserver.io/donate/ 2026-08-22T18:51:12.881961392Z  2026-08-22T18:51:12.881962692Z ─────────────────────────────────────── 2026-08-22T18:51:12.881964492Z GID/UID 2026-08-22T18:51:12.881965792Z ─────────────────────────────────────── 2026-08-22T18:51:12.892499135Z  2026-08-22T18:51:12.892530537Z User UID:    1000 2026-08-22T18:51:12.892532237Z User GID:    1000 2026-08-22T18:51:12.892533637Z ─────────────────────────────────────── 2026-08-22T18:51:12.895511390Z Linuxserver.io version: 4.1.3-r0-ls357 2026-08-22T18:51:12.896028917Z Build-date: 2026-08-04T12:22:56+00:00 2026-08-22T18:51:12.896048118Z ─────────────────────────────────────── 2026-08-22T18:51:12.896050218Z      2026-08-22T18:51:13.190407993Z [custom-init] No custom files found, skipping... 2026-08-22T18:51:14.226952231Z Connection to localhost (::1) 9091 port [tcp/*] succeeded! 2026-08-22T18:51:14.258109138Z [ls.io-init] done.
`

---

## ðŸ³ Full Docker Inspect

`json
[     {         "Id": "0590e07884defde6df3a43a86e86e70280895485babb0c89de45b1216c47038c",         "Created": "2026-08-22T18:51:08.204499296Z",         "Path": "/init",         "Args": [],         "State": {             "Status": "running",             "Running": true,             "Paused": false,             "Restarting": false,             "OOMKilled": false,             "Dead": false,             "Pid": 22337,             "ExitCode": 0,             "Error": "",             "StartedAt": "2026-08-22T18:51:12.359225943Z",             "FinishedAt": "0001-01-01T00:00:00Z"         },         "Image": "sha256:81787bc706d3833d252e6d8b94545fea46bf2156f616320991a395619a477d2c",         "ResolvConfPath": "/var/lib/docker/containers/0590e07884defde6df3a43a86e86e70280895485babb0c89de45b1216c47038c/resolv.conf",         "HostnamePath": "/var/lib/docker/containers/0590e07884defde6df3a43a86e86e70280895485babb0c89de45b1216c47038c/hostname",         "HostsPath": "/var/lib/docker/containers/0590e07884defde6df3a43a86e86e70280895485babb0c89de45b1216c47038c/hosts",         "LogPath": "/var/lib/docker/containers/0590e07884defde6df3a43a86e86e70280895485babb0c89de45b1216c47038c/0590e07884defde6df3a43a86e86e70280895485babb0c89de45b1216c47038c-json.log",         "Name": "/transmission",         "RestartCount": 0,         "Driver": "overlayfs",         "Platform": "linux",         "MountLabel": "",         "ProcessLabel": "",         "AppArmorProfile": "",         "ExecIDs": null,         "HostConfig": {             "Binds": [                 "C:\\Users\\Public\\MediaStack\\transmission\\config:/config:rw",                 "C:\\Users\\Public\\MediaStack\\downloads:/downloads:rw",                 "C:\\Users\\Public\\MediaStack\\transmission\\watch:/watch:rw"             ],             "ContainerIDFile": "",             "LogConfig": {                 "Type": "json-file",                 "Config": {}             },             "NetworkMode": "mediastack_default",             "PortBindings": {                 "51413/tcp": [                     {                         "HostIp": "",                         "HostPort": "51413"                     }                 ],                 "51413/udp": [                     {                         "HostIp": "",                         "HostPort": "51413"                     }                 ],                 "9091/tcp": [                     {                         "HostIp": "",                         "HostPort": "9091"                     }                 ]             },             "RestartPolicy": {                 "Name": "unless-stopped",                 "MaximumRetryCount": 0             },             "AutoRemove": false,             "VolumeDriver": "",             "VolumesFrom": null,             "ConsoleSize": [                 0,                 0             ],             "CapAdd": null,             "CapDrop": null,             "CgroupnsMode": "private",             "Dns": null,             "DnsOptions": null,             "DnsSearch": null,             "ExtraHosts": [],             "GroupAdd": null,             "IpcMode": "private",             "Cgroup": "",             "Links": null,             "OomScoreAdj": 0,             "PidMode": "",             "Privileged": false,             "PublishAllPorts": false,             "ReadonlyRootfs": false,             "SecurityOpt": null,             "UTSMode": "",             "UsernsMode": "",             "ShmSize": 67108864,             "Runtime": "runc",             "Isolation": "",             "CpuShares": 0,             "Memory": 0,             "NanoCpus": 0,             "CgroupParent": "",             "BlkioWeight": 0,             "BlkioWeightDevice": null,             "BlkioDeviceReadBps": null,             "BlkioDeviceWriteBps": null,             "BlkioDeviceReadIOps": null,             "BlkioDeviceWriteIOps": null,             "CpuPeriod": 0,             "CpuQuota": 0,             "CpuRealtimePeriod": 0,             "CpuRealtimeRuntime": 0,             "CpusetCpus": "",             "CpusetMems": "",             "Devices": null,             "DeviceCgroupRules": null,             "DeviceRequests": null,             "MemoryReservation": 0,             "MemorySwap": 0,             "MemorySwappiness": null,             "OomKillDisable": null,             "PidsLimit": null,             "Ulimits": null,             "CpuCount": 0,             "CpuPercent": 0,             "IOMaximumIOps": 0,             "IOMaximumBandwidth": 0,             "MaskedPaths": [                 "/proc/acpi",                 "/proc/asound",                 "/proc/interrupts",                 "/proc/kcore",                 "/proc/keys",                 "/proc/latency_stats",                 "/proc/sched_debug",                 "/proc/scsi",                 "/proc/timer_list",                 "/proc/timer_stats",                 "/sys/devices/virtual/powercap",                 "/sys/firmware"             ],             "ReadonlyPaths": [                 "/proc/bus",                 "/proc/fs",                 "/proc/irq",                 "/proc/sys",                 "/proc/sysrq-trigger"             ]         },         "Storage": {             "RootFS": {                 "Snapshot": {                     "Name": "overlayfs"                 }             }         },         "Mounts": [             {                 "Type": "bind",                 "Source": "C:\\Users\\Public\\MediaStack\\transmission\\config",                 "Destination": "/config",                 "Mode": "rw",                 "RW": true,                 "Propagation": "rprivate"             },             {                 "Type": "bind",                 "Source": "C:\\Users\\Public\\MediaStack\\downloads",                 "Destination": "/downloads",                 "Mode": "rw",                 "RW": true,                 "Propagation": "rprivate"             },             {                 "Type": "bind",                 "Source": "C:\\Users\\Public\\MediaStack\\transmission\\watch",                 "Destination": "/watch",                 "Mode": "rw",                 "RW": true,                 "Propagation": "rprivate"             }         ],         "Config": {             "Hostname": "0590e07884de",             "Domainname": "",             "User": "",             "AttachStdin": false,             "AttachStdout": true,             "AttachStderr": true,             "ExposedPorts": {                 "51413/tcp": {},                 "51413/udp": {},                 "9091/tcp": {}             },             "Tty": false,             "OpenStdin": false,             "StdinOnce": false,             "Env": [                 "PUID=1000",                 "PGID=1000",                 "TZ=America/New_York",                 "PATH=/lsiopy/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin",                 "PS1=$(whoami)@$(hostname):$(pwd)\\$ ",                 "HOME=/root",                 "TERM=xterm",                 "S6_CMD_WAIT_FOR_SERVICES_MAXTIME=0",                 "S6_VERBOSITY=1",                 "S6_STAGE2_HOOK=/docker-mods",                 "VIRTUAL_ENV=/lsiopy",                 "LSIO_FIRST_PARTY=true"             ],             "Cmd": null,             "Image": "lscr.io/linuxserver/transmission:latest",             "Volumes": {                 "/config": {}             },             "WorkingDir": "/",             "Entrypoint": [                 "/init"             ],             "Labels": {                 "autoheal": "true",                 "build_version": "Linuxserver.io version:- 4.1.3-r0-ls357 Build-date:- 2026-08-04T12:22:56+00:00",                 "com.docker.compose.config-hash": "97417746fa3c746b4aac76692afabd126072e797c506216d4eeda769e587d1c0",                 "com.docker.compose.container-number": "1",                 "com.docker.compose.depends_on": "",                 "com.docker.compose.image": "sha256:81787bc706d3833d252e6d8b94545fea46bf2156f616320991a395619a477d2c",                 "com.docker.compose.oneoff": "False",                 "com.docker.compose.project": "mediastack",                 "com.docker.compose.project.config_files": "C:\\Users\\Public\\MediaStack\\docker-compose.yml",                 "com.docker.compose.project.working_dir": "C:\\Users\\Public\\MediaStack",                 "com.docker.compose.replace": "transmission",                 "com.docker.compose.service": "transmission",                 "com.docker.compose.version": "5.3.1",                 "maintainer": "aptalca",                 "org.opencontainers.image.authors": "linuxserver.io",                 "org.opencontainers.image.created": "2026-08-04T12:22:56+00:00",                 "org.opencontainers.image.description": "[Transmission](https://www.transmissionbt.com/) is designed for easy, powerful use. Transmission has the features you want from a BitTorrent client: encryption, a web interface, peer exchange, magnet links, DHT, µTP, UPnP and NAT-PMP port forwarding, webseed support, watch directories, tracker editing, global and per-torrent speed limits, and more.",                 "org.opencontainers.image.documentation": "https://docs.linuxserver.io/images/docker-transmission",                 "org.opencontainers.image.licenses": "GPL-3.0-only",                 "org.opencontainers.image.ref.name": "cd648f76f76d0f745b91c295ccf784510774f74c",                 "org.opencontainers.image.revision": "cd648f76f76d0f745b91c295ccf784510774f74c",                 "org.opencontainers.image.source": "https://github.com/linuxserver/docker-transmission",                 "org.opencontainers.image.title": "Transmission",                 "org.opencontainers.image.url": "https://github.com/linuxserver/docker-transmission/packages",                 "org.opencontainers.image.vendor": "linuxserver.io",                 "org.opencontainers.image.version": "4.1.3-r0-ls357"             }         },         "NetworkSettings": {             "SandboxID": "d23138af844eafec903c4cb4b96dfb4edabe7eb7bf1f1b28b9f5077639ab7426",             "SandboxKey": "/var/run/docker/netns/d23138af844e",             "Ports": {                 "51413/tcp": [                     {                         "HostIp": "0.0.0.0",                         "HostPort": "51413"                     },                     {                         "HostIp": "::",                         "HostPort": "51413"                     }                 ],                 "51413/udp": [                     {                         "HostIp": "0.0.0.0",                         "HostPort": "51413"                     },                     {                         "HostIp": "::",                         "HostPort": "51413"                     }                 ],                 "9091/tcp": [                     {                         "HostIp": "0.0.0.0",                         "HostPort": "9091"                     },                     {                         "HostIp": "::",                         "HostPort": "9091"                     }                 ]             },             "Networks": {                 "mediastack_default": {                     "IPAMConfig": null,                     "Links": null,                     "Aliases": [                         "transmission",                         "transmission"                     ],                     "DriverOpts": null,                     "GwPriority": 0,                     "NetworkID": "c1e26df2c8f37ebab98723ad4966bf4ccf8003b0e0f126e2b55837866af60ad7",                     "EndpointID": "534a4bb4b5b6f66e9b76685a67f78c07071f8a96873bf4dbfaaf6a2f462cd387",                     "Gateway": "172.18.0.1",                     "IPAddress": "172.18.0.8",                     "MacAddress": "62:ba:9a:e4:48:a6",                     "IPPrefixLen": 16,                     "IPv6Gateway": "",                     "GlobalIPv6Address": "",                     "GlobalIPv6PrefixLen": 0,                     "DNSNames": [                         "transmission",                         "0590e07884de"                     ]                 }             }         },         "ImageManifestDescriptor": {             "mediaType": "application/vnd.oci.image.manifest.v1+json",             "digest": "sha256:5a364e7d2bcf35329538664d2595cf505ea97db5ad6240a7de72885b6e3efb10",             "size": 2189,             "platform": {                 "architecture": "arm64",                 "os": "linux"             }         }     } ]
`

---

*This handoff was automatically generated by the MediaStack Autohealer.*
*To assist with this failure, paste this entire file into an AI assistant chat.*
