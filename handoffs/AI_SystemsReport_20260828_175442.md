# ÃƒÂ°Ã…Â¸Ã‚Â¤Ã¢â‚¬â€œ AI Systems Report Handoff

| Field | Value |
|-------|-------|
| **Timestamp** | 2026-08-28 17:55:09 (-04:00) |
| **System** | Windows MediaStack HA |

---

## ÃƒÂ°Ã…Â¸ Ã‚Â³ Docker Containers
`	ext
CONTAINER ID   IMAGE                                     COMMAND                  CREATED          STATUS                             PORTS                                                                                                                                                                    NAMES d7c3105f9b76   caddy:latest                              "caddy run --config …"   31 seconds ago   Up 23 seconds (health: starting)   0.0.0.0:80->80/tcp, [::]:80->80/tcp, 0.0.0.0:443->443/tcp, [::]:443->443/tcp, 0.0.0.0:8080->8080/tcp, [::]:8080->8080/tcp, 0.0.0.0:8096->8096/tcp, [::]:8096->8096/tcp   caddy 6447cb4c687b   lscr.io/linuxserver/tvheadend:latest      "/init"                  31 seconds ago   Up 24 seconds                      9981-9982/tcp                                                                                                                                                            tvheadend b53832e8a12d   crazymax/diun:latest                      "diun serve"             31 seconds ago   Up 23 seconds                                                                                                                                                                                               diun 55da8c307b80   lscr.io/linuxserver/transmission:latest   "/init"                  31 seconds ago   Up 23 seconds                      0.0.0.0:51413->51413/tcp, 0.0.0.0:51413->51413/udp, [::]:51413->51413/tcp, [::]:51413->51413/udp                                                                         transmission 3ecade040f34   lscr.io/linuxserver/radarr:latest         "/init"                  31 seconds ago   Up 24 seconds (health: starting)   7878/tcp                                                                                                                                                                 radarr 2426a495b05f   lscr.io/linuxserver/sonarr:latest         "/init"                  31 seconds ago   Up 24 seconds (health: starting)   8989/tcp                                                                                                                                                                 sonarr 023712d96f5a   lscr.io/linuxserver/bazarr:latest         "/init"                  31 seconds ago   Up 24 seconds                      6767/tcp                                                                                                                                                                 bazarr 24a5418bd049   lscr.io/linuxserver/jellyfin:latest       "/init"                  31 seconds ago   Up 23 seconds (health: starting)   8096/tcp, 8920/tcp                                                                                                                                                       jellyfin 83cd3aec9f62   lscr.io/linuxserver/prowlarr:latest       "/init"                  31 seconds ago   Up 24 seconds                      9696/tcp                                                                                                                                                                 prowlarr 4a876180c81a   ghcr.io/seerr-team/seerr:v3.4.1           "docker-entrypoint.s…"   31 seconds ago   Up 24 seconds                      5055/tcp                                                                                                                                                                 jellyseerr 69144d22d5f2   mediastack-api-gateway                    "docker-entrypoint.s…"   31 seconds ago   Up 24 seconds                      0.0.0.0:3000->3000/tcp, [::]:3000->3000/tcp                                                                                                                              api-gateway 17301aba8862   ghcr.io/gethomepage/homepage:latest       "docker-entrypoint.s…"   31 seconds ago   Up 23 seconds (health: starting)   3000/tcp                                                                                                                                                                 homepage f56a41ac05c7   coleifer/sqlite-web                       "/bin/ash -c 'sqlite…"   31 seconds ago   Up 23 seconds                      8080/tcp                                                                                                                                                                 mediastack-db
`

---

## ÃƒÂ°Ã…Â¸Ã¢â‚¬Å“Ã…Â  Resource Usage (Docker Stats)
`	ext
CONTAINER ID   NAME            CPU %     MEM USAGE / LIMIT     MEM %     NET I/O           BLOCK I/O        PIDS d7c3105f9b76   caddy           0.00%     10.11MiB / 7.234GiB   0.14%     1.72kB / 126B     1.25MB / 0B      9 6447cb4c687b   tvheadend       53.43%    6.332MiB / 7.234GiB   0.09%     2.68kB / 126B     16.4kB / 487kB   16 b53832e8a12d   diun            0.21%     9.781MiB / 7.234GiB   0.13%     1.85kB / 126B     1.4MB / 0B       8 55da8c307b80   transmission    11.17%    5.641MiB / 7.234GiB   0.08%     7.92kB / 2.96kB   28.7kB / 512kB   14 3ecade040f34   radarr          74.68%    29.77MiB / 7.234GiB   0.40%     2.94kB / 126B     8.19kB / 270kB   25 2426a495b05f   sonarr          25.31%    18.01MiB / 7.234GiB   0.24%     2.11kB / 126B     4.1kB / 279kB    27 023712d96f5a   bazarr          57.61%    30.32MiB / 7.234GiB   0.41%     3.79kB / 126B     24.6kB / 512kB   17 24a5418bd049   jellyfin        18.63%    15.6MiB / 7.234GiB    0.21%     2.13kB / 126B     152kB / 270kB    23 83cd3aec9f62   prowlarr        0.29%     3.254MiB / 7.234GiB   0.04%     3.22kB / 126B     20.5kB / 492kB   15 4a876180c81a   jellyseerr      41.91%    46.93MiB / 7.234GiB   0.63%     6.64kB / 3.13kB   3.24MB / 4.1kB   18 69144d22d5f2   api-gateway     61.93%    39.9MiB / 7.234GiB    0.54%     2.39kB / 126B     4.1kB / 0B       7 17301aba8862   homepage        42.66%    46.08MiB / 7.234GiB   0.62%     2.4kB / 126B      0B / 0B          12 f56a41ac05c7   mediastack-db   0.04%     21.92MiB / 7.234GiB   0.30%     2.96kB / 126B     193kB / 127kB    2
`

---

## ÃƒÂ°Ã…Â¸Ã¢â‚¬â„¢Ã‚Â¾ Disk Space
`	ext

DriveLetter FileSystemLabel SizeGB FreeGB
----------- --------------- ------ ------
          C Windows         952.58 169.22
            SYSTEM            0.09   0.03
            Recovery          1.17   0.28



`

---

## ÃƒÂ°Ã…Â¸Ã…â€™  Routes Test
`	ext

`
