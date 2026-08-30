# 🤖 AI Autoheal Handoff: `jellyseerr`

| Field            | Value |
|------------------|-------|
| **Container**    | `jellyseerr` |
| **Timestamp**    | 2026-08-22 14:31:57 (-04:00) |
| **Trigger**      | Deep context handoff test - verifying new format |
| **Handoff File** | `C:\Users\Public\MediaStack\handoffs\AI_Handoff_jellyseerr_20260822_143157.md` |
| **Config Path**  | `C:\Users\Public\MediaStack\jellyseerr\config` |

---

## 🚨 DATA CORRUPTION DETECTED

> [!CAUTION]
> The following files are **0 bytes** and are likely corrupt. This is the most common cause of startup failures (e.g., SQLite migration errors). **DO NOT restart without addressing these first.**
- `C:\Users\Public\MediaStack\jellyseerr\config\logs\.machinelogs.json`

### Recommended Fix
`powershell
# Stop the container, delete the corrupt file(s), then restart.
# The app will regenerate a fresh database on next boot.
docker stop jellyseerr
Remove-Item "<path_to_corrupt_file>" -Force
docker start jellyseerr
`
## [WARN] Best Practice Violations

- [WARN] **PUID not set** - container may run as root, causing permission issues on host volumes.
- [WARN] **PGID not set** - container may run as root, causing permission issues on host volumes.


---

## 📋 Environment Variables

| Variable | Value |
|----------|-------|
| `LOG_LEVEL` | `debug` |
| `TZ` | `America/New_York` |
| `PATH` | `/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin` |
| `NODE_VERSION` | `22.18.0` |
| `YARN_VERSION` | `1.22.22` |


---

## 🔍 Process Tree at Time of Failure

`	ext
UID                 PID                 PPID                C                   STIME               TTY                 TIME                CMD root                15186               15163               0                   18:28               ?                   00:00:00            /sbin/tini -- pnpm start root                15217               15186               0                   18:28               ?                   00:00:00            node /usr/local/bin/pnpm start root                15228               15217               1                   18:28               ?                   00:00:03            node dist/index.js
`

---

## 📁 Volume / Config Directory Tree

> Host path mapped to `/config` inside the container (max 3 levels deep).

`	ext
Path                                                             Size        
----                                                             ----        
cache                                                            <DIR>       
db                                                               <DIR>       
logs                                                             <DIR>       
settings.json                                                    7397 bytes  
settings.json.bak                                                8316 bytes  
settings.old.json                                                6160 bytes  
cache\images                                                     <DIR>       
cache\images\avatar                                              <DIR>       
cache\images\avatar\SCFggR8dpOD3KmQB9LpP40WxYrcs9na7D1mwu5DvF9s= <DIR>       
cache\images\avatar\SyKrgulIVe11YS3R1uS5ulIB1EGv1RmO+VPa-3n9g0w= <DIR>       
db\db.sqlite3                                                    143360 bytes
db\db.sqlite3-shm                                                32768 bytes 
db\db.sqlite3-wal                                                0 bytes     
logs\.20136e5b8544ec13f7fc29ce3d35150d597108bb-audit.json        625 bytes   
logs\.4295fcfc416647ffc3751a1d488b45a096cf2d4f-audit.json        1037 bytes  
logs\.machinelogs-2026-08-21.json                                445010 bytes
logs\.machinelogs-2026-08-22.json                                43395 bytes 
logs\.machinelogs.json                                           0 bytes     
logs\jellyseerr-2026-08-18.log                                   42818 bytes 
logs\jellyseerr-2026-08-20.log                                   10701 bytes 
logs\jellyseerr-2026-08-21.log                                   312043 bytes
logs\jellyseerr-2026-08-22.log                                   30116 bytes 
logs\jellyseerr.log                                              0 bytes
`

---

## ⚙️ Configuration Files


### `settings.json`
> Path: `C:\Users\Public\MediaStack\jellyseerr\config\settings.json`
> Size: 7397 bytes | Last Modified: 08/21/2026 17:54:09

```json
{
 "clientId": "6d5e4eab-7450-4c7d-a241-de988de56805",
 "vapidPrivate": "UVjGp_-VrhEfx1mPhEtNc6evoZQDtP0YNDFm4ahK0HI",
 "vapidPublic": "BNWdC5wysTdxFCW4s4Lu8sRCqrmK0RDMJPMUbXghhR4gKCspXjuXnGveAW4II47Eg8YsNqOq380DEGzCYjnVtro",
 "main": {
  "apiKey": "MTc4NzM0MzY4NzcwNWU5MTkyYmRlLWJiZjItNGY2My04ZGI3LTVkOTI2NTk0M2U5Zg==",
  "applicationTitle": "Jellyseerr",
  "applicationUrl": "",
  "cacheImages": false,
  "defaultPermissions": 1048736,
  "defaultQuotas": {
   "movie": {
    "quotaLimit": 0,
    "quotaDays": 7
   },
   "tv": {
    "quotaLimit": 0,
    "quotaDays": 7
   }
  },
  "hideAvailable": false,
  "hideBlacklisted": false,
  "localLogin": true,
  "mediaServerLogin": true,
  "newPlexLogin": true,
  "discoverRegion": "",
  "streamingRegion": "",
  "originalLanguage": "",
  "blacklistedTags": "",
  "blacklistedTagsLimit": 50,
  "mediaServerType": 2,
  "partialRequestsEnabled": true,
  "enableSpecialEpisodes": false,
  "locale": "en",
  "youtubeUrl": ""
 },
 "plex": {
  "name": "",
  "ip": "",
  "port": 32400,
  "useSsl": false,
  "libraries": []
 },
 "jellyfin": {
  "name": "jellyfinlaptop",
  "ip": "jellyfin",
  "port": 8096,
  "useSsl": false,
  "urlBase": "",
  "externalHostname": "http://waltdakind.xubi.org",
  "jellyfinForgotPasswordUrl": "",
  "libraries": [
   {
    "id": "f137a2dd21bbc1b99aa5c0f6bf02a805",
    "name": "Movies",
    "enabled": true,
    "type": "movie"
   },
   {
    "id": "a656b907eb3a73532e40e44b968d0225",
    "name": "Shows",
    "enabled": true,
    "type": "show"
   }
  ],
  "serverId": "32879ade42004efbb817f13b8f18c1ab",
  "apiKey": "5db2ed00f7a84a42b40ce4d38c2fffe5"
 },
 "tautulli": {},
 "radarr": [
  {
   "id": 0,
   "name": "Radarr",
   "hostname": "radarr",
   "port": 7878,
   "apiKey": "b6e94c74e76b4c7086ee5f5753ac630d",
   "useSsl": false,
   "baseUrl": "",
   "activeProfileId": 1,
   "activeProfileName": "Any",
   "activeDirectory": "/media/videos",
   "is4k": false,
   "isDefault": true,
   "externalUrl": "",
   "syncEnabled": false,
   "preventSearch": false
  }
 ],
 "sonarr": [
  {
   "id": 0,
   "name": "Sonarr",
   "hostname": "sonarr",
   "port": 8989,
   "apiKey": "77b018f4679a46989265dc569c61216b",
   "useSsl": false,
   "baseUrl": "",
   "activeProfileId": 1,
   "activeProfileName": "Any",
   "activeDirectory": "/media/videos",
   "is4k": false,
   "enableSeasonFolders": false,
   "isDefault": true,
   "externalUrl": "",
   "syncEnabled": false,
   "preventSearch": false
  }
 ],
 "public": {
  "initialized": true
 },
 "notifications": {
  "agents": {
   "email": {
    "enabled": false,
    "options": {
     "userEmailRequired": false,
     "emailFrom": "",
     "smtpHost": "",
     "smtpPort": 587,
```


---

## 📜 Recent Logs (last 150 lines with timestamps)

`	ext
2026-08-22T17:33:00.017050055Z 2026-08-22T17:33:00.014Z [[34mdebug[39m][Jobs]: Starting scheduled job: Download Sync  2026-08-22T17:34:00.018290520Z 2026-08-22T17:34:00.017Z [[34mdebug[39m][Jobs]: Starting scheduled job: Download Sync  2026-08-22T17:35:00.012301195Z 2026-08-22T17:35:00.011Z [[34mdebug[39m][Jobs]: Starting scheduled job: Download Sync  2026-08-22T17:35:00.012834519Z 2026-08-22T17:35:00.012Z [[32minfo[39m][Jobs]: Starting scheduled job: Jellyfin Recently Added Scan  2026-08-22T17:35:00.012958325Z 2026-08-22T17:35:00.012Z [[32minfo[39m][Jellyfin Sync]: Jellyfin Sync Starting {"sessionId":"8dc5676f-fdc5-4545-88ef-57edb04f5ce2"} 2026-08-22T17:35:00.022587664Z 2026-08-22T17:35:00.022Z [[32minfo[39m][Jellyfin Sync]: Beginning to process recently added for library: Movies  2026-08-22T17:35:00.509151552Z 2026-08-22T17:35:00.508Z [[31merror[39m][Jellyfin API]: Something went wrong while getting library content from the Jellyfin server: read ECONNRESET {} 2026-08-22T17:35:00.509185753Z 2026-08-22T17:35:00.508Z [[31merror[39m][Jellyfin Sync]: Sync interrupted {"errorMessage":""} 2026-08-22T17:36:00.013956651Z 2026-08-22T17:36:00.012Z [[34mdebug[39m][Jobs]: Starting scheduled job: Download Sync  2026-08-22T17:37:00.015474496Z 2026-08-22T17:37:00.014Z [[34mdebug[39m][Jobs]: Starting scheduled job: Download Sync  2026-08-22T17:38:00.015478691Z 2026-08-22T17:38:00.015Z [[34mdebug[39m][Jobs]: Starting scheduled job: Download Sync  2026-08-22T17:39:00.012706924Z 2026-08-22T17:39:00.012Z [[34mdebug[39m][Jobs]: Starting scheduled job: Download Sync  2026-08-22T17:40:00.018889131Z 2026-08-22T17:40:00.018Z [[34mdebug[39m][Jobs]: Starting scheduled job: Download Sync  2026-08-22T17:40:00.020185694Z 2026-08-22T17:40:00.020Z [[32minfo[39m][Jobs]: Starting scheduled job: Jellyfin Recently Added Scan  2026-08-22T17:40:00.020395104Z 2026-08-22T17:40:00.020Z [[32minfo[39m][Jellyfin Sync]: Jellyfin Sync Starting {"sessionId":"0d971319-0cd1-4c30-b139-1374e6f1c688"} 2026-08-22T17:40:00.027033823Z 2026-08-22T17:40:00.026Z [[32minfo[39m][Jellyfin Sync]: Beginning to process recently added for library: Movies  2026-08-22T17:40:00.086993106Z 2026-08-22T17:40:00.086Z [[31merror[39m][Jellyfin API]: Something went wrong while getting library content from the Jellyfin server: read ECONNRESET {} 2026-08-22T17:40:00.087147613Z 2026-08-22T17:40:00.087Z [[31merror[39m][Jellyfin Sync]: Sync interrupted {"errorMessage":""} 2026-08-22T17:41:00.015726469Z 2026-08-22T17:41:00.015Z [[34mdebug[39m][Jobs]: Starting scheduled job: Download Sync  2026-08-22T17:42:00.012040985Z 2026-08-22T17:42:00.011Z [[34mdebug[39m][Jobs]: Starting scheduled job: Download Sync  2026-08-22T17:43:00.016489560Z 2026-08-22T17:43:00.016Z [[34mdebug[39m][Jobs]: Starting scheduled job: Download Sync  2026-08-22T17:44:00.021315468Z 2026-08-22T17:44:00.020Z [[34mdebug[39m][Jobs]: Starting scheduled job: Download Sync  2026-08-22T17:45:00.010246077Z 2026-08-22T17:45:00.009Z [[34mdebug[39m][Jobs]: Starting scheduled job: Download Sync  2026-08-22T17:45:00.011771293Z 2026-08-22T17:45:00.011Z [[32minfo[39m][Jobs]: Starting scheduled job: Jellyfin Recently Added Scan  2026-08-22T17:45:00.011798097Z 2026-08-22T17:45:00.011Z [[32minfo[39m][Jellyfin Sync]: Jellyfin Sync Starting {"sessionId":"e73f2937-13ce-4719-9425-8c7d0fe01331"} 2026-08-22T17:45:00.019008717Z 2026-08-22T17:45:00.018Z [[32minfo[39m][Jellyfin Sync]: Beginning to process recently added for library: Movies  2026-08-22T17:45:00.186575431Z 2026-08-22T17:45:00.186Z [[31merror[39m][Jellyfin API]: Something went wrong while getting library content from the Jellyfin server: read ECONNRESET {} 2026-08-22T17:45:00.186911378Z 2026-08-22T17:45:00.186Z [[31merror[39m][Jellyfin Sync]: Sync interrupted {"errorMessage":""} 2026-08-22T17:46:00.017012452Z 2026-08-22T17:46:00.013Z [[34mdebug[39m][Jobs]: Starting scheduled job: Download Sync  2026-08-22T17:47:00.018224770Z 2026-08-22T17:47:00.017Z [[34mdebug[39m][Jobs]: Starting scheduled job: Download Sync  2026-08-22T17:48:00.013217979Z 2026-08-22T17:48:00.012Z [[34mdebug[39m][Jobs]: Starting scheduled job: Download Sync  2026-08-22T17:49:00.002982581Z 2026-08-22T17:49:00.002Z [[34mdebug[39m][Jobs]: Starting scheduled job: Download Sync  2026-08-22T17:50:00.003561209Z 2026-08-22T17:50:00.003Z [[34mdebug[39m][Jobs]: Starting scheduled job: Download Sync  2026-08-22T17:50:00.004291336Z 2026-08-22T17:50:00.004Z [[32minfo[39m][Jobs]: Starting scheduled job: Jellyfin Recently Added Scan  2026-08-22T17:50:00.004440942Z 2026-08-22T17:50:00.004Z [[32minfo[39m][Jellyfin Sync]: Jellyfin Sync Starting {"sessionId":"eaee3bae-36de-482c-a01d-533fae38c2bd"} 2026-08-22T17:50:00.015256148Z 2026-08-22T17:50:00.014Z [[32minfo[39m][Jellyfin Sync]: Beginning to process recently added for library: Movies  2026-08-22T17:50:00.388023256Z 2026-08-22T17:50:00.385Z [[31merror[39m][Jellyfin API]: Something went wrong while getting library content from the Jellyfin server: read ECONNRESET {} 2026-08-22T17:50:00.388058257Z 2026-08-22T17:50:00.385Z [[31merror[39m][Jellyfin Sync]: Sync interrupted {"errorMessage":""} 2026-08-22T17:51:00.003231062Z 2026-08-22T17:51:00.002Z [[34mdebug[39m][Jobs]: Starting scheduled job: Download Sync  2026-08-22T17:52:00.002353380Z 2026-08-22T17:52:00.002Z [[34mdebug[39m][Jobs]: Starting scheduled job: Download Sync  2026-08-22T17:53:00.003701832Z 2026-08-22T17:53:00.003Z [[34mdebug[39m][Jobs]: Starting scheduled job: Download Sync  2026-08-22T17:54:00.015876935Z 2026-08-22T17:54:00.015Z [[34mdebug[39m][Jobs]: Starting scheduled job: Download Sync  2026-08-22T17:55:00.016342043Z 2026-08-22T17:55:00.015Z [[34mdebug[39m][Jobs]: Starting scheduled job: Download Sync  2026-08-22T17:55:00.018331118Z 2026-08-22T17:55:00.018Z [[32minfo[39m][Jobs]: Starting scheduled job: Jellyfin Recently Added Scan  2026-08-22T17:55:00.018534826Z 2026-08-22T17:55:00.018Z [[32minfo[39m][Jellyfin Sync]: Jellyfin Sync Starting {"sessionId":"a871e8ba-6ba7-4305-bbf2-27ff785d3820"} 2026-08-22T17:55:00.026268217Z 2026-08-22T17:55:00.025Z [[32minfo[39m][Jellyfin Sync]: Beginning to process recently added for library: Movies  2026-08-22T17:55:00.855580193Z 2026-08-22T17:55:00.855Z [[31merror[39m][Jellyfin API]: Something went wrong while getting library content from the Jellyfin server: read ECONNRESET {} 2026-08-22T17:55:00.856439326Z 2026-08-22T17:55:00.856Z [[31merror[39m][Jellyfin Sync]: Sync interrupted {"errorMessage":""} 2026-08-22T17:56:00.013711276Z 2026-08-22T17:56:00.013Z [[34mdebug[39m][Jobs]: Starting scheduled job: Download Sync  2026-08-22T17:57:00.015967530Z 2026-08-22T17:57:00.015Z [[34mdebug[39m][Jobs]: Starting scheduled job: Download Sync  2026-08-22T17:58:00.008390932Z 2026-08-22T17:58:00.008Z [[34mdebug[39m][Jobs]: Starting scheduled job: Download Sync  2026-08-22T17:59:00.011136666Z 2026-08-22T17:59:00.010Z [[34mdebug[39m][Jobs]: Starting scheduled job: Download Sync  2026-08-22T18:00:00.019599794Z 2026-08-22T18:00:00.017Z [[34mdebug[39m][Jobs]: Starting scheduled job: Download Sync  2026-08-22T18:00:00.020220916Z 2026-08-22T18:00:00.020Z [[32minfo[39m][Jobs]: Starting scheduled job: Jellyfin Recently Added Scan  2026-08-22T18:00:00.020414154Z 2026-08-22T18:00:00.020Z [[32minfo[39m][Jellyfin Sync]: Jellyfin Sync Starting {"sessionId":"1071365d-801e-4c66-a26f-5281d9a01e92"} 2026-08-22T18:00:00.026048968Z 2026-08-22T18:00:00.025Z [[32minfo[39m][Jellyfin Sync]: Beginning to process recently added for library: Movies  2026-08-22T18:00:00.028165286Z 2026-08-22T18:00:00.027Z [[31merror[39m][Jellyfin API]: Something went wrong while getting library content from the Jellyfin server: connect ECONNREFUSED 172.18.0.3:8096 {} 2026-08-22T18:00:00.028426737Z 2026-08-22T18:00:00.028Z [[31merror[39m][Jellyfin Sync]: Sync interrupted {"errorMessage":""} 2026-08-22T18:01:00.017811903Z 2026-08-22T18:01:00.017Z [[34mdebug[39m][Jobs]: Starting scheduled job: Download Sync  2026-08-22T18:02:00.018266251Z 2026-08-22T18:02:00.016Z [[34mdebug[39m][Jobs]: Starting scheduled job: Download Sync  2026-08-22T18:03:00.016347283Z 2026-08-22T18:03:00.015Z [[34mdebug[39m][Jobs]: Starting scheduled job: Download Sync  2026-08-22T18:04:00.014095240Z 2026-08-22T18:04:00.013Z [[34mdebug[39m][Jobs]: Starting scheduled job: Download Sync  2026-08-22T18:05:00.016965690Z 2026-08-22T18:05:00.016Z [[34mdebug[39m][Jobs]: Starting scheduled job: Download Sync  2026-08-22T18:05:00.017678718Z 2026-08-22T18:05:00.017Z [[32minfo[39m][Jobs]: Starting scheduled job: Jellyfin Recently Added Scan  2026-08-22T18:05:00.018675857Z 2026-08-22T18:05:00.017Z [[32minfo[39m][Jellyfin Sync]: Jellyfin Sync Starting {"sessionId":"d42a19c5-131a-48d7-9e46-0f8189f1e3aa"} 2026-08-22T18:05:00.024079868Z 2026-08-22T18:05:00.023Z [[32minfo[39m][Jellyfin Sync]: Beginning to process recently added for library: Movies  2026-08-22T18:05:00.026747573Z 2026-08-22T18:05:00.026Z [[31merror[39m][Jellyfin API]: Something went wrong while getting library content from the Jellyfin server: connect ECONNREFUSED 172.18.0.3:8096 {} 2026-08-22T18:05:00.026784874Z 2026-08-22T18:05:00.026Z [[31merror[39m][Jellyfin Sync]: Sync interrupted {"errorMessage":""} 2026-08-22T18:06:00.015088613Z 2026-08-22T18:06:00.014Z [[34mdebug[39m][Jobs]: Starting scheduled job: Download Sync  2026-08-22T18:07:00.013673239Z 2026-08-22T18:07:00.013Z [[34mdebug[39m][Jobs]: Starting scheduled job: Download Sync  2026-08-22T18:08:00.002095627Z 2026-08-22T18:08:00.001Z [[34mdebug[39m][Jobs]: Starting scheduled job: Download Sync  2026-08-22T18:09:00.002309358Z 2026-08-22T18:09:00.002Z [[34mdebug[39m][Jobs]: Starting scheduled job: Download Sync  2026-08-22T18:10:00.003580352Z 2026-08-22T18:10:00.002Z [[34mdebug[39m][Jobs]: Starting scheduled job: Download Sync  2026-08-22T18:10:00.003617654Z 2026-08-22T18:10:00.003Z [[32minfo[39m][Jobs]: Starting scheduled job: Jellyfin Recently Added Scan  2026-08-22T18:10:00.003620054Z 2026-08-22T18:10:00.003Z [[32minfo[39m][Jellyfin Sync]: Jellyfin Sync Starting {"sessionId":"26f4f3e6-3aa2-49d4-8ebe-dc924826c54f"} 2026-08-22T18:10:00.009998510Z 2026-08-22T18:10:00.009Z [[32minfo[39m][Jellyfin Sync]: Beginning to process recently added for library: Movies  2026-08-22T18:10:00.036312768Z 2026-08-22T18:10:00.036Z [[31merror[39m][Jellyfin API]: Something went wrong while getting library content from the Jellyfin server: Request failed with status code 401 {"error":401} 2026-08-22T18:10:00.036500975Z 2026-08-22T18:10:00.036Z [[31merror[39m][Jellyfin Sync]: Sync interrupted {"errorMessage":""} 2026-08-22T18:11:00.002309592Z 2026-08-22T18:11:00.002Z [[34mdebug[39m][Jobs]: Starting scheduled job: Download Sync  2026-08-22T18:12:00.002899055Z 2026-08-22T18:12:00.002Z [[34mdebug[39m][Jobs]: Starting scheduled job: Download Sync  2026-08-22T18:13:00.002206776Z 2026-08-22T18:13:00.001Z [[34mdebug[39m][Jobs]: Starting scheduled job: Download Sync  2026-08-22T18:14:00.003511440Z 2026-08-22T18:14:00.003Z [[34mdebug[39m][Jobs]: Starting scheduled job: Download Sync  2026-08-22T18:15:00.003264148Z 2026-08-22T18:15:00.003Z [[34mdebug[39m][Jobs]: Starting scheduled job: Download Sync  2026-08-22T18:15:00.004512998Z 2026-08-22T18:15:00.004Z [[32minfo[39m][Jobs]: Starting scheduled job: Jellyfin Recently Added Scan  2026-08-22T18:15:00.005254227Z 2026-08-22T18:15:00.004Z [[32minfo[39m][Jellyfin Sync]: Jellyfin Sync Starting {"sessionId":"631e7c95-924b-431c-9736-bdc0da7fa036"} 2026-08-22T18:15:00.014388388Z 2026-08-22T18:15:00.014Z [[32minfo[39m][Jellyfin Sync]: Beginning to process recently added for library: Movies  2026-08-22T18:15:00.048173322Z 2026-08-22T18:15:00.047Z [[31merror[39m][Jellyfin API]: Something went wrong while getting library content from the Jellyfin server: Request failed with status code 401 {"error":401} 2026-08-22T18:15:00.048559038Z 2026-08-22T18:15:00.048Z [[31merror[39m][Jellyfin Sync]: Sync interrupted {"errorMessage":""} 2026-08-22T18:16:00.017227655Z 2026-08-22T18:16:00.015Z [[34mdebug[39m][Jobs]: Starting scheduled job: Download Sync  2026-08-22T18:17:00.016153000Z 2026-08-22T18:17:00.015Z [[34mdebug[39m][Jobs]: Starting scheduled job: Download Sync  2026-08-22T18:18:00.004071052Z 2026-08-22T18:18:00.003Z [[34mdebug[39m][Jobs]: Starting scheduled job: Download Sync  2026-08-22T18:19:00.002434981Z 2026-08-22T18:19:00.002Z [[34mdebug[39m][Jobs]: Starting scheduled job: Download Sync  2026-08-22T18:20:00.002865402Z 2026-08-22T18:20:00.002Z [[34mdebug[39m][Jobs]: Starting scheduled job: Download Sync  2026-08-22T18:20:00.004073949Z 2026-08-22T18:20:00.003Z [[32minfo[39m][Jobs]: Starting scheduled job: Jellyfin Recently Added Scan  2026-08-22T18:20:00.004101150Z 2026-08-22T18:20:00.004Z [[32minfo[39m][Jellyfin Sync]: Jellyfin Sync Starting {"sessionId":"9f1be661-e61b-448e-bfd3-9cb9c4e9014c"} 2026-08-22T18:20:00.013092699Z 2026-08-22T18:20:00.012Z [[32minfo[39m][Jellyfin Sync]: Beginning to process recently added for library: Movies  2026-08-22T18:20:00.020417984Z 2026-08-22T18:20:00.020Z [[31merror[39m][Jellyfin API]: Something went wrong while getting library content from the Jellyfin server: connect ECONNREFUSED 172.18.0.3:8096 {} 2026-08-22T18:20:00.020638292Z 2026-08-22T18:20:00.020Z [[31merror[39m][Jellyfin Sync]: Sync interrupted {"errorMessage":""} 2026-08-22T18:21:00.003084790Z 2026-08-22T18:21:00.002Z [[34mdebug[39m][Jobs]: Starting scheduled job: Download Sync  2026-08-22T18:22:00.001086614Z 2026-08-22T18:22:00.000Z [[34mdebug[39m][Jobs]: Starting scheduled job: Download Sync  2026-08-22T18:23:00.003272658Z 2026-08-22T18:23:00.002Z [[34mdebug[39m][Jobs]: Starting scheduled job: Download Sync  2026-08-22T18:24:00.002921965Z 2026-08-22T18:24:00.002Z [[34mdebug[39m][Jobs]: Starting scheduled job: Download Sync  2026-08-22T18:25:00.003450795Z 2026-08-22T18:25:00.002Z [[34mdebug[39m][Jobs]: Starting scheduled job: Download Sync  2026-08-22T18:25:00.004550340Z 2026-08-22T18:25:00.004Z [[32minfo[39m][Jobs]: Starting scheduled job: Jellyfin Recently Added Scan  2026-08-22T18:25:00.007442458Z 2026-08-22T18:25:00.007Z [[32minfo[39m][Jellyfin Sync]: Jellyfin Sync Starting {"sessionId":"4f8cdb33-8ce9-4447-a393-e10233ca019e"} 2026-08-22T18:25:00.026078519Z 2026-08-22T18:25:00.024Z [[32minfo[39m][Jellyfin Sync]: Beginning to process recently added for library: Movies  2026-08-22T18:25:00.049276667Z 2026-08-22T18:25:00.049Z [[31merror[39m][Jellyfin API]: Something went wrong while getting library content from the Jellyfin server: Request failed with status code 401 {"error":401} 2026-08-22T18:25:00.049510577Z 2026-08-22T18:25:00.049Z [[31merror[39m][Jellyfin Sync]: Sync interrupted {"errorMessage":""} 2026-08-22T18:26:00.002171388Z 2026-08-22T18:26:00.001Z [[34mdebug[39m][Jobs]: Starting scheduled job: Download Sync  2026-08-22T18:26:59.059111201Z  ELIFECYCLE  Command failed. 2026-08-22T18:26:59.979799221Z  2026-08-22T18:26:59.979854223Z > jellyseerr@2.7.3 start /app 2026-08-22T18:26:59.979857323Z > NODE_ENV=production node dist/index.js 2026-08-22T18:26:59.979859323Z  2026-08-22T18:27:01.275815855Z 2026-08-22T18:27:01.273Z [[32minfo[39m]: Commit Tag: $GIT_SHA  2026-08-22T18:27:01.554549053Z 2026-08-22T18:27:01.554Z [[32minfo[39m]: Starting Jellyseerr version 2.7.3  2026-08-22T18:27:02.056042381Z 2026-08-22T18:27:02.055Z [[34mdebug[39m][Settings Migrator]: Checking migration '0001_migrate_hostname.js'...  2026-08-22T18:27:02.058489180Z 2026-08-22T18:27:02.058Z [[34mdebug[39m][Settings Migrator]: Checking migration '0002_migrate_apitokens.js'...  2026-08-22T18:27:02.059629426Z 2026-08-22T18:27:02.059Z [[34mdebug[39m][Settings Migrator]: Checking migration '0003_emby_media_server_type.js'...  2026-08-22T18:27:02.060123546Z 2026-08-22T18:27:02.060Z [[34mdebug[39m][Settings Migrator]: Checking migration '0004_migrate_region_setting.js'...  2026-08-22T18:27:02.060424559Z 2026-08-22T18:27:02.060Z [[34mdebug[39m][Settings Migrator]: Checking migration '0005_migrate_network_settings.js'...  2026-08-22T18:27:02.060728371Z 2026-08-22T18:27:02.060Z [[34mdebug[39m][Settings Migrator]: Checking migration '0006_remove_lunasea.js'...  2026-08-22T18:27:02.064617928Z 2026-08-22T18:27:02.064Z [[32minfo[39m][Notifications]: Registered notification agents  2026-08-22T18:27:02.097747971Z 2026-08-22T18:27:02.097Z [[32minfo[39m][Jobs]: Scheduled jobs loaded  2026-08-22T18:27:02.188627955Z 2026-08-22T18:27:02.188Z [[32minfo[39m][Server]: Server ready on port 5055  2026-08-22T18:28:00.005748854Z 2026-08-22T18:28:00.005Z [[34mdebug[39m][Jobs]: Starting scheduled job: Download Sync  2026-08-22T18:28:08.911462166Z  ELIFECYCLE  Command failed. 2026-08-22T18:28:09.623183108Z  2026-08-22T18:28:09.623230410Z > jellyseerr@2.7.3 start /app 2026-08-22T18:28:09.623233010Z > NODE_ENV=production node dist/index.js 2026-08-22T18:28:09.623235011Z  2026-08-22T18:28:10.421461011Z 2026-08-22T18:28:10.420Z [[32minfo[39m]: Commit Tag: $GIT_SHA  2026-08-22T18:28:10.656063209Z 2026-08-22T18:28:10.655Z [[32minfo[39m]: Starting Jellyseerr version 2.7.3  2026-08-22T18:28:11.081527078Z 2026-08-22T18:28:11.081Z [[34mdebug[39m][Settings Migrator]: Checking migration '0001_migrate_hostname.js'...  2026-08-22T18:28:11.082800331Z 2026-08-22T18:28:11.082Z [[34mdebug[39m][Settings Migrator]: Checking migration '0002_migrate_apitokens.js'...  2026-08-22T18:28:11.083934378Z 2026-08-22T18:28:11.083Z [[34mdebug[39m][Settings Migrator]: Checking migration '0003_emby_media_server_type.js'...  2026-08-22T18:28:11.084347196Z 2026-08-22T18:28:11.084Z [[34mdebug[39m][Settings Migrator]: Checking migration '0004_migrate_region_setting.js'...  2026-08-22T18:28:11.084684210Z 2026-08-22T18:28:11.084Z [[34mdebug[39m][Settings Migrator]: Checking migration '0005_migrate_network_settings.js'...  2026-08-22T18:28:11.085482143Z 2026-08-22T18:28:11.084Z [[34mdebug[39m][Settings Migrator]: Checking migration '0006_remove_lunasea.js'...  2026-08-22T18:28:11.088867284Z 2026-08-22T18:28:11.088Z [[32minfo[39m][Notifications]: Registered notification agents  2026-08-22T18:28:11.111092813Z 2026-08-22T18:28:11.110Z [[32minfo[39m][Jobs]: Scheduled jobs loaded  2026-08-22T18:28:11.202577833Z 2026-08-22T18:28:11.202Z [[32minfo[39m][Server]: Server ready on port 5055  2026-08-22T18:29:00.016854237Z 2026-08-22T18:29:00.016Z [[34mdebug[39m][Jobs]: Starting scheduled job: Download Sync  2026-08-22T18:30:00.020663600Z 2026-08-22T18:30:00.020Z [[34mdebug[39m][Jobs]: Starting scheduled job: Download Sync  2026-08-22T18:30:00.025329592Z 2026-08-22T18:30:00.024Z [[32minfo[39m][Jobs]: Starting scheduled job: Jellyfin Recently Added Scan  2026-08-22T18:30:00.026060122Z 2026-08-22T18:30:00.025Z [[32minfo[39m][Jellyfin Sync]: Jellyfin Sync Starting {"sessionId":"82c0cc81-5f59-42bc-bce5-15e9b353be97"} 2026-08-22T18:30:00.034376764Z 2026-08-22T18:30:00.034Z [[32minfo[39m][Jellyfin Sync]: Beginning to process recently added for library: Movies  2026-08-22T18:30:00.063722370Z 2026-08-22T18:30:00.063Z [[31merror[39m][Jellyfin API]: Something went wrong while getting library content from the Jellyfin server: Request failed with status code 401 {"error":401} 2026-08-22T18:30:00.064503502Z 2026-08-22T18:30:00.063Z [[31merror[39m][Jellyfin Sync]: Sync interrupted {"errorMessage":""} 2026-08-22T18:31:00.016185800Z 2026-08-22T18:31:00.015Z [[34mdebug[39m][Jobs]: Starting scheduled job: Download Sync 
`

---

## 🐳 Full Docker Inspect

`json
[     {         "Id": "71d71f85d038f558da6118d79efa7f31feea2bbddf73d207b08dbbb03951e075",         "Created": "2026-08-22T16:25:37.111492394Z",         "Path": "/sbin/tini",         "Args": [             "--",             "pnpm",             "start"         ],         "State": {             "Status": "running",             "Running": true,             "Paused": false,             "Restarting": false,             "OOMKilled": false,             "Dead": false,             "Pid": 15186,             "ExitCode": 0,             "Error": "",             "StartedAt": "2026-08-22T18:28:09.144611545Z",             "FinishedAt": "2026-08-22T18:28:08.920388633Z"         },         "Image": "sha256:4538137bc5af902dece165f2bf73776d9cf4eafb6dd714670724af8f3eb77764",         "ResolvConfPath": "/var/lib/docker/containers/71d71f85d038f558da6118d79efa7f31feea2bbddf73d207b08dbbb03951e075/resolv.conf",         "HostnamePath": "/var/lib/docker/containers/71d71f85d038f558da6118d79efa7f31feea2bbddf73d207b08dbbb03951e075/hostname",         "HostsPath": "/var/lib/docker/containers/71d71f85d038f558da6118d79efa7f31feea2bbddf73d207b08dbbb03951e075/hosts",         "LogPath": "/var/lib/docker/containers/71d71f85d038f558da6118d79efa7f31feea2bbddf73d207b08dbbb03951e075/71d71f85d038f558da6118d79efa7f31feea2bbddf73d207b08dbbb03951e075-json.log",         "Name": "/jellyseerr",         "RestartCount": 0,         "Driver": "overlayfs",         "Platform": "linux",         "MountLabel": "",         "ProcessLabel": "",         "AppArmorProfile": "",         "ExecIDs": null,         "HostConfig": {             "Binds": [                 "C:\\Users\\Public\\MediaStack\\jellyseerr\\config:/app/config:rw"             ],             "ContainerIDFile": "",             "LogConfig": {                 "Type": "json-file",                 "Config": {}             },             "NetworkMode": "mediastack_default",             "PortBindings": {                 "5055/tcp": [                     {                         "HostIp": "",                         "HostPort": "5055"                     }                 ]             },             "RestartPolicy": {                 "Name": "unless-stopped",                 "MaximumRetryCount": 0             },             "AutoRemove": false,             "VolumeDriver": "",             "VolumesFrom": null,             "ConsoleSize": [                 0,                 0             ],             "CapAdd": null,             "CapDrop": null,             "CgroupnsMode": "private",             "Dns": null,             "DnsOptions": null,             "DnsSearch": null,             "ExtraHosts": [],             "GroupAdd": null,             "IpcMode": "private",             "Cgroup": "",             "Links": null,             "OomScoreAdj": 0,             "PidMode": "",             "Privileged": false,             "PublishAllPorts": false,             "ReadonlyRootfs": false,             "SecurityOpt": null,             "UTSMode": "",             "UsernsMode": "",             "ShmSize": 67108864,             "Runtime": "runc",             "Isolation": "",             "CpuShares": 0,             "Memory": 0,             "NanoCpus": 0,             "CgroupParent": "",             "BlkioWeight": 0,             "BlkioWeightDevice": null,             "BlkioDeviceReadBps": null,             "BlkioDeviceWriteBps": null,             "BlkioDeviceReadIOps": null,             "BlkioDeviceWriteIOps": null,             "CpuPeriod": 0,             "CpuQuota": 0,             "CpuRealtimePeriod": 0,             "CpuRealtimeRuntime": 0,             "CpusetCpus": "",             "CpusetMems": "",             "Devices": null,             "DeviceCgroupRules": null,             "DeviceRequests": null,             "MemoryReservation": 0,             "MemorySwap": 0,             "MemorySwappiness": null,             "OomKillDisable": null,             "PidsLimit": null,             "Ulimits": null,             "CpuCount": 0,             "CpuPercent": 0,             "IOMaximumIOps": 0,             "IOMaximumBandwidth": 0,             "MaskedPaths": [                 "/proc/acpi",                 "/proc/asound",                 "/proc/interrupts",                 "/proc/kcore",                 "/proc/keys",                 "/proc/latency_stats",                 "/proc/sched_debug",                 "/proc/scsi",                 "/proc/timer_list",                 "/proc/timer_stats",                 "/sys/devices/virtual/powercap",                 "/sys/firmware"             ],             "ReadonlyPaths": [                 "/proc/bus",                 "/proc/fs",                 "/proc/irq",                 "/proc/sys",                 "/proc/sysrq-trigger"             ]         },         "Storage": {             "RootFS": {                 "Snapshot": {                     "Name": "overlayfs"                 }             }         },         "Mounts": [             {                 "Type": "bind",                 "Source": "C:\\Users\\Public\\MediaStack\\jellyseerr\\config",                 "Destination": "/app/config",                 "Mode": "rw",                 "RW": true,                 "Propagation": "rprivate"             }         ],         "Config": {             "Hostname": "71d71f85d038",             "Domainname": "",             "User": "",             "AttachStdin": false,             "AttachStdout": true,             "AttachStderr": true,             "ExposedPorts": {                 "5055/tcp": {}             },             "Tty": false,             "OpenStdin": false,             "StdinOnce": false,             "Env": [                 "LOG_LEVEL=debug",                 "TZ=America/New_York",                 "PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin",                 "NODE_VERSION=22.18.0",                 "YARN_VERSION=1.22.22"             ],             "Cmd": [                 "pnpm",                 "start"             ],             "Image": "fallenbagel/jellyseerr:latest",             "Volumes": null,             "WorkingDir": "/app",             "Entrypoint": [                 "/sbin/tini",                 "--"             ],             "Labels": {                 "com.docker.compose.config-hash": "ee7c036db85ffa45e4360e60a69d11e3e67d44ac22a26560db165cf7d24785ce",                 "com.docker.compose.container-number": "1",                 "com.docker.compose.depends_on": "",                 "com.docker.compose.image": "sha256:4538137bc5af902dece165f2bf73776d9cf4eafb6dd714670724af8f3eb77764",                 "com.docker.compose.oneoff": "False",                 "com.docker.compose.project": "mediastack",                 "com.docker.compose.project.config_files": "C:\\Users\\Public\\MediaStack\\docker-compose.yml",                 "com.docker.compose.project.working_dir": "C:\\Users\\Public\\MediaStack",                 "com.docker.compose.service": "jellyseerr",                 "com.docker.compose.version": "5.3.1",                 "org.opencontainers.image.authors": "Fallenbagel",                 "org.opencontainers.image.created": "",                 "org.opencontainers.image.description": "Open-source media request and discovery manager for Jellyfin, Plex, and Emby.",                 "org.opencontainers.image.licenses": "MIT",                 "org.opencontainers.image.source": "https://github.com/fallenbagel/jellyseerr",                 "org.opencontainers.image.title": "Jellyseerr",                 "org.opencontainers.image.version": ""             }         },         "NetworkSettings": {             "SandboxID": "b54db4db57fc28b17586d9da9226a92e14b4e336880734278f81727f5635c93a",             "SandboxKey": "/var/run/docker/netns/b54db4db57fc",             "Ports": {                 "5055/tcp": [                     {                         "HostIp": "0.0.0.0",                         "HostPort": "5055"                     },                     {                         "HostIp": "::",                         "HostPort": "5055"                     }                 ]             },             "Networks": {                 "mediastack_default": {                     "IPAMConfig": null,                     "Links": null,                     "Aliases": [                         "jellyseerr",                         "jellyseerr"                     ],                     "DriverOpts": null,                     "GwPriority": 0,                     "NetworkID": "c1e26df2c8f37ebab98723ad4966bf4ccf8003b0e0f126e2b55837866af60ad7",                     "EndpointID": "45c95fa7f8fd708470cbaac04e1de1c2a7cd453060add4d9c7f5844fd23a36b9",                     "Gateway": "172.18.0.1",                     "IPAddress": "172.18.0.5",                     "MacAddress": "12:7b:cd:9c:c3:bf",                     "IPPrefixLen": 16,                     "IPv6Gateway": "",                     "GlobalIPv6Address": "",                     "GlobalIPv6PrefixLen": 0,                     "DNSNames": [                         "jellyseerr",                         "71d71f85d038"                     ]                 }             }         },         "ImageManifestDescriptor": {             "mediaType": "application/vnd.oci.image.manifest.v1+json",             "digest": "sha256:5d79101f54301b1483e5a97130424a8bb281d290a9b8168c59015744e6c0114d",             "size": 1818,             "platform": {                 "architecture": "arm64",                 "os": "linux"             }         }     } ]
`

---

*This handoff was automatically generated by the MediaStack Autohealer.*
*To assist with this failure, paste this entire file into an AI assistant chat.*
