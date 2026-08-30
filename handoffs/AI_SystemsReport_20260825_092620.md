# Ã°Å¸Â¤â€“ AI Systems Report Handoff

| Field | Value |
|-------|-------|
| **Timestamp** | 2026-08-25 09:26:27 (-04:00) |
| **System** | Windows MediaStack HA |

---

## Ã°Å¸ Â³ Docker Containers
`	ext
CONTAINER ID   IMAGE                                     COMMAND                  CREATED          STATUS                                 PORTS                                                                                                                                                                                            NAMES 2f279f7478ef   lscr.io/linuxserver/sonarr:latest         "/init"                  15 minutes ago   Up 14 minutes (healthy)                0.0.0.0:8989->8989/tcp, [::]:8989->8989/tcp                                                                                                                                                      sonarr 2c93d43aa3f5   lscr.io/linuxserver/radarr:latest         "/init"                  15 minutes ago   Up 14 minutes (healthy)                0.0.0.0:7878->7878/tcp, [::]:7878->7878/tcp                                                                                                                                                      radarr bf1342a652df   caddy:2-alpine                            "caddy run --config …"   15 minutes ago   Up 14 minutes (healthy)                0.0.0.0:80->80/tcp, [::]:80->80/tcp, 0.0.0.0:443->443/tcp, [::]:443->443/tcp, 0.0.0.0:443->443/udp, [::]:443->443/udp                                                                            caddy b305f2dd709e   lscr.io/linuxserver/prowlarr:latest       "/init"                  15 minutes ago   Up 14 minutes (healthy)                0.0.0.0:9696->9696/tcp, [::]:9696->9696/tcp                                                                                                                                                      prowlarr a0a1f903861b   lscr.io/linuxserver/jellyfin:latest       "/init"                  15 minutes ago   Up 37 seconds (healthy)                0.0.0.0:8096->8096/tcp, [::]:8096->8096/tcp                                                                                                                                                      jellyfin 471d018a5501   lscr.io/linuxserver/transmission:latest   "/init"                  15 minutes ago   Up About a minute (health: starting)   0.0.0.0:9091->9091/tcp, [::]:9091->9091/tcp, 0.0.0.0:51413->51413/tcp, [::]:51413->51413/tcp, 0.0.0.0:51413->51413/udp, [::]:51413->51413/udp                                                    transmission 3ace472802f1   docker:cli                                "docker-entrypoint.s…"   15 minutes ago   Up 14 minutes                                                                                                                                                                                                                           healthguard d238aee31ed1   syncthing/syncthing:latest                "/bin/entrypoint.sh …"   15 minutes ago   Up 14 minutes (healthy)                0.0.0.0:8384->8384/tcp, 0.0.0.0:21027->21027/udp, [::]:8384->8384/tcp, [::]:21027->21027/udp, 0.0.0.0:22000->22000/tcp, [::]:22000->22000/tcp, 0.0.0.0:22000->22000/udp, [::]:22000->22000/udp   syncthing 548199d1fc56   containrrr/watchtower:latest              "/watchtower"            15 minutes ago   Restarting (1) 9 seconds ago                                                                                                                                                                                                            watchtower 933e79fb2641   alpine:latest                             "sh /scripts/db-init…"   15 minutes ago   Exited (0) 7 minutes ago                                                                                                                                                                                                                db-init ff31f22c1448   lscr.io/linuxserver/tvheadend:latest      "/init"                  15 minutes ago   Up 15 minutes (healthy)                0.0.0.0:9981-9982->9981-9982/tcp, [::]:9981-9982->9981-9982/tcp                                                                                                                                  tvheadend
`

---

## Ã°Å¸â€œÅ  Resource Usage (Docker Stats)
`	ext
CONTAINER ID   NAME           CPU %     MEM USAGE / LIMIT     MEM %     NET I/O           BLOCK I/O        PIDS 2f279f7478ef   sonarr         0.11%     70.41MiB / 7.234GiB   0.95%     96.8kB / 5.23kB   0B / 557kB       25 2c93d43aa3f5   radarr         1.72%     93.39MiB / 7.234GiB   1.26%     97kB / 5.35kB     0B / 549kB       24 bf1342a652df   caddy          0.05%     11.84MiB / 7.234GiB   0.16%     138kB / 18.5kB    184kB / 188kB    9 b305f2dd709e   prowlarr       0.09%     90.28MiB / 7.234GiB   1.22%     1.69MB / 46.8kB   0B / 561kB       25 a0a1f903861b   jellyfin       46.64%    15.11MiB / 7.234GiB   0.20%     4.79kB / 126B     0B / 471kB       23 471d018a5501   transmission   1.46%     5.66MiB / 7.234GiB    0.08%     22.5kB / 15kB     0B / 438kB       20 3ace472802f1   healthguard    0.00%     580KiB / 7.234GiB     0.01%     93.1kB / 126B     131kB / 65.5kB   2 d238aee31ed1   syncthing      0.12%     14.74MiB / 7.234GiB   0.20%     158kB / 63.1kB    0B / 0B          21 548199d1fc56   watchtower     0.00%     0B / 0B               0.00%     0B / 0B           0B / 0B          0 ff31f22c1448   tvheadend      0.05%     14.66MiB / 7.234GiB   0.20%     98kB / 11.7kB     0B / 504kB       36
`

---

## Ã°Å¸â€™Â¾ Disk Space
`	ext

DriveLetter FileSystemLabel SizeGB FreeGB
----------- --------------- ------ ------
          C Windows         952.58 146.35
            Recovery          1.17   0.28



`

---

## Ã°Å¸Å’  Routes Test
`	ext

`
