# ÃƒÂ°Ã…Â¸Ã‚Â¤Ã¢â‚¬â€œ AI Systems Report Handoff

| Field | Value |
|-------|-------|
| **Timestamp** | 2026-08-28 17:57:12 (-04:00) |
| **System** | Windows MediaStack HA |

---

## ÃƒÂ°Ã…Â¸ Ã‚Â³ Docker Containers
`	ext
CONTAINER ID   IMAGE                                     COMMAND                  CREATED       STATUS                          PORTS                                                                          NAMES f1c85bfccb91   lscr.io/linuxserver/radarr:latest         "/init"                  4 hours ago   Exited (137) 4 hours ago                                                                                       radarr 9fc1cf5c4367   coleifer/sqlite-web                       "/bin/ash -c 'sqlite…"   4 hours ago   Up 4 hours                      0.0.0.0:8080->8080/tcp, [::]:8080->8080/tcp                                    mediastack-db afebfc099e42   lscr.io/linuxserver/bazarr:latest         "/init"                  4 hours ago   Exited (137) 4 hours ago                                                                                       bazarr 34e6037e463b   caddy:latest                              "caddy run --config …"   4 hours ago   Up 4 hours                      0.0.0.0:80->80/tcp, [::]:80->80/tcp, 0.0.0.0:443->443/tcp, [::]:443->443/tcp   caddy 6f1747bda004   ghcr.io/seerr-team/seerr:v3.4.1           "docker-entrypoint.s…"   4 hours ago   Exited (1) 4 hours ago                                                                                         jellyseerr bb3e28f422a2   lscr.io/linuxserver/transmission:latest   "/init"                  4 hours ago   Exited (137) 4 hours ago                                                                                       transmission ecbafae35bae   lscr.io/linuxserver/tvheadend:latest      "/init"                  4 hours ago   Up 4 hours                      0.0.0.0:9981-9982->9981-9982/tcp, [::]:9981-9982->9981-9982/tcp                tvheadend 077b0a8d8e0a   lscr.io/linuxserver/sonarr:latest         "/init"                  4 hours ago   Exited (137) 4 hours ago                                                                                       sonarr d967f84e389d   willfarrell/autoheal                      "/docker-entrypoint …"   4 hours ago   Up 4 hours (healthy)                                                                                           autoheal c808cc5324a2   lscr.io/linuxserver/jellyfin:latest       "/init"                  4 hours ago   Exited (137) 4 hours ago                                                                                       jellyfin 51d1c35ff727   lscr.io/linuxserver/jackett:latest        "/init"                  4 hours ago   Up 4 hours                      0.0.0.0:9117->9117/tcp, [::]:9117->9117/tcp                                    jackett 8f868048590d   containrrr/watchtower                     "/watchtower"            4 hours ago   Restarting (1) 48 seconds ago                                                                                  watchtower
`

---

## ÃƒÂ°Ã…Â¸Ã¢â‚¬Å“Ã…Â  Resource Usage (Docker Stats)
`	ext
CONTAINER ID   NAME            CPU %     MEM USAGE / LIMIT     MEM %     NET I/O           BLOCK I/O        PIDS 9fc1cf5c4367   mediastack-db   12.29%    54MiB / 7.541GiB      0.70%     49.2kB / 5.24kB   0B / 131kB       6 34e6037e463b   caddy           0.00%     11.29MiB / 7.541GiB   0.15%     61.4kB / 33.3kB   0B / 0B          13 ecbafae35bae   tvheadend       0.03%     14.43MiB / 7.541GiB   0.19%     49.4kB / 39.5kB   12.3kB / 520kB   36 d967f84e389d   autoheal        1.04%     1.215MiB / 7.541GiB   0.02%     48.9kB / 126B     0B / 0B          2 51d1c35ff727   jackett         0.01%     89.92MiB / 7.541GiB   1.16%     119kB / 5.46kB    12.3kB / 131MB   23 8f868048590d   watchtower      0.00%     0B / 0B               0.00%     0B / 0B           0B / 0B          0
`

---

## ÃƒÂ°Ã…Â¸Ã¢â‚¬â„¢Ã‚Â¾ Disk Space
`	ext

DriveLetter FileSystemLabel  SizeGB FreeGB
----------- ---------------  ------ ------
          C Windows          952.52 153.75
            Windows RE tools   0.83   0.11
            SYSTEM              0.5   0.39



`

---

## ÃƒÂ°Ã…Â¸Ã…â€™  Routes Test
`	ext

`
