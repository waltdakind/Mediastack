# 🤖 AI Autoheal Handoff: `jellyfin`

| Field            | Value |
|------------------|-------|
| **Container**    | `jellyfin` |
| **Timestamp**    | 2026-08-22 14:33:53 (-04:00) |
| **Trigger**      | Proxy returned 503 |
| **Handoff File** | `C:\Users\Public\MediaStack\handoffs\AI_Handoff_jellyfin_20260822_143352.md` |
| **Config Path**  | `C:\Users\Public\MediaStack\config\jellyfin` |

---




---

## 📋 Environment Variables

| Variable | Value |
|----------|-------|
| `PUID` | `1000` |
| `PGID` | `1000` |
| `TZ` | `America/New_York` |
| `PATH` | `/lsiopy/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin` |
| `HOME` | `/root` |
| `LANGUAGE` | `en_US.UTF-8` |
| `LANG` | `en_US.UTF-8` |
| `TERM` | `xterm` |
| `S6_CMD_WAIT_FOR_SERVICES_MAXTIME` | `0` |
| `S6_VERBOSITY` | `1` |
| `S6_STAGE2_HOOK` | `/docker-mods` |
| `VIRTUAL_ENV` | `/lsiopy` |
| `LSIO_FIRST_PARTY` | `true` |
| `NVIDIA_DRIVER_CAPABILITIES` | `compute,video,utility` |
| `MALLOC_TRIM_THRESHOLD_` | `131072` |
| `ATTACHED_DEVICES_PERMS` | `/dev/dri /dev/dvb /dev/vchiq /dev/vc-mem /dev/video1? -type c` |


---

## 🔍 Process Tree at Time of Failure

`	ext
UID                 PID                 PPID                C                   STIME               TTY                 TIME                CMD root                13992               13968               0                   18:27               ?                   00:00:00            /package/admin/s6/command/s6-svscan -d4 -- /run/service root                14040               13992               0                   18:27               ?                   00:00:00            s6-supervise s6-linux-init-shutdownd root                14043               14040               0                   18:27               ?                   00:00:00            /package/admin/s6-linux-init/command/s6-linux-init-shutdownd -d3 -c /run/s6/basedir -g 3000 -C -B root                14059               13992               0                   18:27               ?                   00:00:00            s6-supervise svc-jellyfin root                14060               13992               0                   18:27               ?                   00:00:00            s6-supervise s6rc-fdholder root                14061               13992               0                   18:27               ?                   00:00:00            s6-supervise svc-cron root                14062               13992               0                   18:27               ?                   00:00:00            s6-supervise s6rc-oneshot-runner root                14070               14062               0                   18:27               ?                   00:00:00            /package/admin/s6/command/s6-ipcserverd -1 -- /package/admin/s6/command/s6-ipcserver-access -v0 -E -l0 -i data/rules -- /package/admin/s6/command/s6-sudod -t 30000 -- /package/admin/s6-rc/command/s6-rc-oneshot-run -l ../.. -- 1000                14183               14059               0                   18:27               ?                   00:00:03            /usr/bin/jellyfin --ffmpeg=/usr/lib/jellyfin-ffmpeg/ffmpeg root                14184               14061               0                   18:27               ?                   00:00:00            bash ./run svc-cron root                14195               14184               0                   18:27               ?                   00:00:00            sleep infinity
`

---

## 📁 Volume / Config Directory Tree

> Host path mapped to `/config` inside the container (max 3 levels deep).

`	ext
Path                                                                     Size        
----                                                                     ----        
.aspnet                                                                  <DIR>       
cache                                                                    <DIR>       
data                                                                     <DIR>       
log                                                                      <DIR>       
.jellyfin-config                                                         0 bytes     
database.xml                                                             291 bytes   
encoding.xml                                                             2645 bytes  
logging.default.json                                                     1362 bytes  
mediastack-ops.ps1                                                       23222 bytes 
network.xml                                                              294 bytes   
system.xml                                                               6893 bytes  
.aspnet\DataProtection-Keys                                              <DIR>       
.aspnet\DataProtection-Keys\key-2bbd8510-bf6d-470e-b524-cd88b0618738.xml 1000 bytes  
cache\transcodes                                                         <DIR>       
cache\.jellyfin-cache                                                    0 bytes     
cache\transcodes\.jellyfin-transcode                                     0 bytes     
data\data                                                                <DIR>       
data\metadata                                                            <DIR>       
data\plugins                                                             <DIR>       
data\root                                                                <DIR>       
data\transcodes                                                          <DIR>       
data\.jellyfin-data                                                      0 bytes     
data\data\playlists                                                      <DIR>       
data\data\ScheduledTasks                                                 <DIR>       
data\data\SQLiteBackups                                                  <DIR>       
data\data\.jellyfin-data                                                 0 bytes     
data\data\device.txt                                                     35 bytes    
data\data\jellyfin.db                                                    475136 bytes
data\data\jellyfin.db-shm                                                32768 bytes 
data\data\jellyfin.db-wal                                                0 bytes     
data\data\ScheduledTasks\3a025083-141d-3c17-dd96-d5f9b951287b.js         233 bytes   
data\data\ScheduledTasks\7d8088c1-0902-f1bf-4072-ded42437bcfb.js         216 bytes   
data\data\ScheduledTasks\f9b057c0-54e9-e6da-ee4a-88ffd146a403.js         198 bytes   
data\plugins\configurations                                              <DIR>       
data\plugins\.jellyfin-plugin                                            0 bytes     
data\plugins\configurations\Jellyfin.Plugin.MusicBrainz.xml              299 bytes   
data\plugins\configurations\Jellyfin.Plugin.Tmdb.xml                     565 bytes   
data\root\default                                                        <DIR>       
data\root\.jellyfin-root                                                 0 bytes     
log\.jellyfin-log                                                        0 bytes     
log\log_20260822.log                                                     203344 bytes
`

---

## ⚙️ Configuration Files


### `system.xml`
> Path: `C:\Users\Public\MediaStack\config\jellyfin\system.xml`
> Size: 6893 bytes | Last Modified: 08/22/2026 14:06:50

```xml
<?xml version="1.0" encoding="utf-8"?>
<ServerConfiguration xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema">
  <LogFileRetentionDays>3</LogFileRetentionDays>
  <IsStartupWizardCompleted>false</IsStartupWizardCompleted>
  <EnableMetrics>false</EnableMetrics>
  <EnableNormalizedItemByNameIds>true</EnableNormalizedItemByNameIds>
  <IsPortAuthorized>true</IsPortAuthorized>
  <QuickConnectAvailable>true</QuickConnectAvailable>
  <EnableCaseSensitiveItemIds>true</EnableCaseSensitiveItemIds>
  <DisableLiveTvChannelUserDataName>true</DisableLiveTvChannelUserDataName>
  <MetadataPath />
  <PreferredMetadataLanguage>en</PreferredMetadataLanguage>
  <MetadataCountryCode>US</MetadataCountryCode>
  <SortReplaceCharacters>
    <string>.</string>
    <string>+</string>
    <string>%</string>
  </SortReplaceCharacters>
  <SortRemoveCharacters>
    <string>,</string>
    <string>&amp;</string>
    <string>-</string>
    <string>{</string>
    <string>}</string>
    <string>'</string>
  </SortRemoveCharacters>
  <SortRemoveWords>
    <string>the</string>
    <string>a</string>
    <string>an</string>
  </SortRemoveWords>
  <MinResumePct>5</MinResumePct>
  <MaxResumePct>90</MaxResumePct>
  <MinResumeDurationSeconds>300</MinResumeDurationSeconds>
  <MinAudiobookResume>5</MinAudiobookResume>
  <MaxAudiobookResume>5</MaxAudiobookResume>
  <InactiveSessionThreshold>0</InactiveSessionThreshold>
  <LibraryMonitorDelay>60</LibraryMonitorDelay>
  <LibraryUpdateDuration>30</LibraryUpdateDuration>
  <CacheSize>800</CacheSize>
  <ImageSavingConvention>Legacy</ImageSavingConvention>
  <MetadataOptions>
    <MetadataOptions>
      <ItemType>Book</ItemType>
      <DisabledMetadataSavers />
      <LocalMetadataReaderOrder />
      <DisabledMetadataFetchers />
      <MetadataFetcherOrder />
      <DisabledImageFetchers />
      <ImageFetcherOrder />
    </MetadataOptions>
    <MetadataOptions>
      <ItemType>Movie</ItemType>
      <DisabledMetadataSavers />
      <LocalMetadataReaderOrder />
      <DisabledMetadataFetchers />
      <MetadataFetcherOrder />
      <DisabledImageFetchers />
      <ImageFetcherOrder />
    </MetadataOptions>
    <MetadataOptions>
      <ItemType>MusicVideo</ItemType>
      <DisabledMetadataSavers />
      <LocalMetadataReaderOrder />
      <DisabledMetadataFetchers>
        <string>The Open Movie Database</string>
      </DisabledMetadataFetchers>
      <MetadataFetcherOrder />
      <DisabledImageFetchers>
        <string>The Open Movie Database</string>
      </DisabledImageFetchers>
      <ImageFetcherOrder />
    </MetadataOptions>
    <MetadataOptions>
      <ItemType>Series</ItemType>
      <DisabledMetadataSavers />
      <LocalMetadataReaderOrder />
      <DisabledMetadataFetchers />
      <MetadataFetcherOrder />
      <DisabledImageFetchers />
      <ImageFetcherOrder />
    </MetadataOptions>
    <MetadataOptions>
      <ItemType>MusicAlbum</ItemType>
      <DisabledMetadataSavers />
      <LocalMetadataReaderOrder />
      <DisabledMetadataFetchers>
        <string>TheAudioDB</string>
      </DisabledMetadataFetchers>
      <MetadataFetcherOrder />
      <DisabledImageFetchers />
      <ImageFetcherOrder />
    </MetadataOptions>
    <MetadataOptions>
      <ItemType>MusicArtist</ItemType>
      <DisabledMetadataSavers />
      <LocalMetadataReaderOrder />
      <DisabledMetadataFetchers>
        <string>TheAudioDB</string>
      </DisabledMetadataFetchers>
      <MetadataFetcherOrder />
      <DisabledImageFetchers />
      <ImageFetcherOrder />
    </MetadataOptions>
    <MetadataOptions>
      <ItemType>BoxSet</ItemType>
      <DisabledMetadataSavers />
      <LocalMetadataReaderOrder />
      <DisabledMetadataFetchers />
      <MetadataFetcherOrder />
      <DisabledImageFetchers />
      <ImageFetcherOrder />
    </MetadataOptions>
    <MetadataOptions>
      <ItemType>Season</ItemType>
      <DisabledMetadataSavers />
      <LocalMetadataReaderOrder />
      <DisabledMetadataFetchers />
      <MetadataFetcherOrder />
      <DisabledImageFetchers />
```

### `database.xml`
> Path: `C:\Users\Public\MediaStack\config\jellyfin\database.xml`
> Size: 291 bytes | Last Modified: 08/22/2026 14:06:47

```xml
<?xml version="1.0" encoding="utf-8"?>
<DatabaseConfigurationOptions xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema">
  <DatabaseType>Jellyfin-SQLite</DatabaseType>
  <LockingBehavior>NoLock</LockingBehavior>
</DatabaseConfigurationOptions>
```

### `network.xml`
> Path: `C:\Users\Public\MediaStack\config\jellyfin\network.xml`
> Size: 294 bytes | Last Modified: 08/22/2026 14:06:47

```xml
<?xml version="1.0" encoding="utf-8"?>
<NetworkConfiguration xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema">
  <EnableIPv6>true</EnableIPv6>
  <LocalNetworkAddresses>
    <string>::</string>
  </LocalNetworkAddresses>
</NetworkConfiguration>
```

### `encoding.xml`
> Path: `C:\Users\Public\MediaStack\config\jellyfin\encoding.xml`
> Size: 2645 bytes | Last Modified: 08/22/2026 14:27:37

```xml
<?xml version="1.0" encoding="utf-8"?>
<EncodingOptions xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema">
  <EncodingThreadCount>-1</EncodingThreadCount>
  <EnableFallbackFont>false</EnableFallbackFont>
  <EnableAudioVbr>false</EnableAudioVbr>
  <DownMixAudioBoost>2</DownMixAudioBoost>
  <DownMixStereoAlgorithm>None</DownMixStereoAlgorithm>
  <MaxMuxingQueueSize>2048</MaxMuxingQueueSize>
  <EnableThrottling>false</EnableThrottling>
  <ThrottleDelaySeconds>180</ThrottleDelaySeconds>
  <EnableSegmentDeletion>false</EnableSegmentDeletion>
  <SegmentKeepSeconds>720</SegmentKeepSeconds>
  <HardwareAccelerationType>none</HardwareAccelerationType>
  <EncoderAppPathDisplay>/usr/lib/jellyfin-ffmpeg/ffmpeg</EncoderAppPathDisplay>
  <VaapiDevice>/dev/dri/renderD128</VaapiDevice>
  <QsvDevice />
  <EnableTonemapping>false</EnableTonemapping>
  <EnableVppTonemapping>false</EnableVppTonemapping>
  <EnableVideoToolboxTonemapping>false</EnableVideoToolboxTonemapping>
  <TonemappingAlgorithm>bt2390</TonemappingAlgorithm>
  <TonemappingMode>auto</TonemappingMode>
  <TonemappingRange>auto</TonemappingRange>
  <TonemappingDesat>0</TonemappingDesat>
  <TonemappingPeak>100</TonemappingPeak>
  <TonemappingParam>0</TonemappingParam>
  <VppTonemappingBrightness>16</VppTonemappingBrightness>
  <VppTonemappingContrast>1</VppTonemappingContrast>
  <H264Crf>23</H264Crf>
  <H265Crf>28</H265Crf>
  <EncoderPreset xsi:nil="true" />
  <DeinterlaceDoubleRate>false</DeinterlaceDoubleRate>
  <DeinterlaceMethod>yadif</DeinterlaceMethod>
  <EnableDecodingColorDepth10Hevc>true</EnableDecodingColorDepth10Hevc>
  <EnableDecodingColorDepth10Vp9>true</EnableDecodingColorDepth10Vp9>
  <EnableDecodingColorDepth10HevcRext>false</EnableDecodingColorDepth10HevcRext>
  <EnableDecodingColorDepth12HevcRext>false</EnableDecodingColorDepth12HevcRext>
  <EnableEnhancedNvdecDecoder>true</EnableEnhancedNvdecDecoder>
  <PreferSystemNativeHwDecoder>true</PreferSystemNativeHwDecoder>
  <EnableIntelLowPowerH264HwEncoder>false</EnableIntelLowPowerH264HwEncoder>
  <EnableIntelLowPowerHevcHwEncoder>false</EnableIntelLowPowerHevcHwEncoder>
  <EnableHardwareEncoding>true</EnableHardwareEncoding>
  <AllowHevcEncoding>false</AllowHevcEncoding>
  <AllowAv1Encoding>false</AllowAv1Encoding>
  <EnableSubtitleExtraction>true</EnableSubtitleExtraction>
  <HardwareDecodingCodecs>
    <string>h264</string>
    <string>vc1</string>
  </HardwareDecodingCodecs>
  <AllowOnDemandMetadataBasedKeyframeExtractionForExtensions>
    <string>mkv</string>
  </AllowOnDemandMetadataBasedKeyframeExtractionForExtensions>
</EncodingOptions>
```

### `logging.default.json`
> Path: `C:\Users\Public\MediaStack\config\jellyfin\logging.default.json`
> Size: 1362 bytes | Last Modified: 08/22/2026 14:06:47

```json
{
    "Serilog": {
        "MinimumLevel": {
            "Default": "Information",
            "Override": {
                "Microsoft": "Warning",
                "System": "Warning"
            }
        },
        "WriteTo": [
            {
                "Name": "Console",
                "Args": {
                    "outputTemplate": "[{Timestamp:HH:mm:ss}] [{Level:u3}] [{ThreadId}] {SourceContext}: {Message:lj}{NewLine}{Exception}"
                }
            },
            {
                "Name": "Async",
                "Args": {
                    "configure": [
                        {
                            "Name": "File",
                            "Args": {
                                "path": "%JELLYFIN_LOG_DIR%//log_.log",
                                "rollingInterval": "Day",
                                "retainedFileCountLimit": 3,
                                "rollOnFileSizeLimit": true,
                                "fileSizeLimitBytes": 100000000,
                                "outputTemplate": "[{Timestamp:yyyy-MM-dd HH:mm:ss.fff zzz}] [{Level:u3}] [{ThreadId}] {SourceContext}: {Message}{NewLine}{Exception}"
                            }
                        }
                    ]
                }
            }
        ],
        "Enrich": [ "FromLogContext", "WithThreadId" ]
    }
}
```


---

## 📜 Recent Logs (last 150 lines with timestamps)

`	ext
2026-08-22T18:26:20.129472679Z [14:26:20] [INF] [7] Jellyfin.Database.Implementations.Locking.NoLockBehavior: The database locking mode has been set to: NoLock. 2026-08-22T18:26:20.132241089Z [14:26:20] [INF] [7] Main: Prepare system for possible migrations 2026-08-22T18:26:20.163518336Z [14:26:20] [INF] [7] Jellyfin.Server.Migrations.JellyfinMigrationService: There are 0 migrations for stage CoreInitialisation. 2026-08-22T18:26:20.235035088Z [14:26:20] [INF] [7] Emby.Server.Implementations.Plugins.PluginManager: Loaded plugin: TMDb 10.11.11.0 2026-08-22T18:26:20.235471605Z [14:26:20] [INF] [7] Emby.Server.Implementations.Plugins.PluginManager: Loaded plugin: Studio Images 10.11.11.0 2026-08-22T18:26:20.235800818Z [14:26:20] [INF] [7] Emby.Server.Implementations.Plugins.PluginManager: Loaded plugin: OMDb 10.11.11.0 2026-08-22T18:26:20.244552567Z [14:26:20] [INF] [7] Emby.Server.Implementations.Plugins.PluginManager: Loaded plugin: MusicBrainz 10.11.11.0 2026-08-22T18:26:20.244714773Z [14:26:20] [INF] [7] Emby.Server.Implementations.Plugins.PluginManager: Loaded plugin: AudioDB 10.11.11.0 2026-08-22T18:26:20.271173528Z [14:26:20] [INF] [7] Jellyfin.Server.Migrations.JellyfinMigrationService: There are 0 migrations for stage AppInitialisation. 2026-08-22T18:26:20.388191594Z [14:26:20] [INF] [7] Main: Kestrel is listening on all interfaces 2026-08-22T18:26:20.775936776Z [14:26:20] [WRN] [7] Microsoft.AspNetCore.StaticFiles.StaticFileMiddleware: The WebRootPath was not found: /run/s6-rc:s6-rc-init:BLPjiM/servicedirs/svc-jellyfin/wwwroot. Static files may be unavailable. 2026-08-22T18:26:20.825656758Z [14:26:20] [INF] [7] Emby.Server.Implementations.ApplicationHost: Running startup tasks 2026-08-22T18:26:20.833269862Z [14:26:20] [INF] [7] Emby.Server.Implementations.ScheduledTasks.TaskManager: Daily trigger for Generate Trickplay Images set to fire at 2026-08-23 03:00:00.000 -04:00, which is 12:33:39.1672888 from now. 2026-08-22T18:26:20.838295962Z [14:26:20] [INF] [7] Emby.Server.Implementations.ScheduledTasks.TaskManager: Daily trigger for Extract Chapter Images set to fire at 2026-08-23 02:00:00.000 -04:00, which is 11:33:39.1618602 from now. 2026-08-22T18:26:20.874668012Z [14:26:20] [INF] [7] MediaBrowser.MediaEncoding.Encoder.MediaEncoder: Found ffmpeg version 7.1.4 2026-08-22T18:26:20.899184190Z [14:26:20] [INF] [7] MediaBrowser.MediaEncoding.Encoder.MediaEncoder: Available decoders: ["libdav1d", "av1", "av1_cuvid", "av1_rkmpp", "h264", "h264_rkmpp", "h264_cuvid", "hevc", "hevc_rkmpp", "hevc_cuvid", "mpeg1_rkmpp", "mpeg2video", "mpeg2_rkmpp", "mpeg2_cuvid", "mpeg4", "mpeg4_rkmpp", "mpeg4_cuvid", "msmpeg4", "vc1_cuvid", "vp8", "vp8_rkmpp", "libvpx", "vp8_cuvid", "vp9", "vp9_rkmpp", "libvpx-vp9", "vp9_cuvid", "aac", "ac3", "ac4", "dca", "flac", "mp3", "truehd"] 2026-08-22T18:26:20.912580024Z [14:26:20] [INF] [7] MediaBrowser.MediaEncoding.Encoder.MediaEncoder: Available encoders: ["libsvtav1", "av1_nvenc", "libx264", "h264_nvenc", "h264_v4l2m2m", "h264_rkmpp", "libx265", "hevc_nvenc", "hevc_rkmpp", "mjpeg_rkmpp", "aac", "libfdk_aac", "ac3", "alac", "dca", "flac", "libmp3lame", "libopus", "truehd", "libvorbis", "srt"] 2026-08-22T18:26:20.932377613Z [14:26:20] [INF] [7] MediaBrowser.MediaEncoding.Encoder.MediaEncoder: Available filters: ["bwdif_cuda", "bwdif_opencl", "hwupload_cuda", "overlay_opencl", "overlay_cuda", "overlay_rkrga", "scale_cuda", "scale_opencl", "scale_rkrga", "tonemapx", "tonemap_cuda", "tonemap_opencl", "transpose_cuda", "transpose_opencl", "vpp_rkrga", "yadif_cuda", "yadif_opencl", "zscale", "alphasrc"] 2026-08-22T18:26:20.994929607Z [14:26:20] [WRN] [7] MediaBrowser.MediaEncoding.Encoder.MediaEncoder: Filter: overlay_vaapi with option Action to take when encountering EOF from secondary input is not available 2026-08-22T18:26:21.006980788Z [14:26:21] [WRN] [7] MediaBrowser.MediaEncoding.Encoder.MediaEncoder: Filter: overlay_vulkan with option Action to take when encountering EOF from secondary input is not available 2026-08-22T18:26:21.145719819Z [14:26:21] [INF] [7] MediaBrowser.MediaEncoding.Encoder.MediaEncoder: Available hwaccel types: ["cuda", "drm", "opencl", "rkmpp"] 2026-08-22T18:26:23.854528121Z [14:26:23] [INF] [13] Emby.Server.Implementations.ScheduledTasks.TaskManager: Clean up collections and playlists Completed after 0 minute(s) and 0 seconds 2026-08-22T18:26:23.876531199Z [14:26:23] [INF] [10] Emby.Server.Implementations.ScheduledTasks.TaskManager: Clean Transcode Directory Completed after 0 minute(s) and 0 seconds 2026-08-22T18:26:24.298281714Z [14:26:24] [INF] [13] Emby.Server.Implementations.ScheduledTasks.TaskManager: Update Plugins Completed after 0 minute(s) and 0 seconds 2026-08-22T18:26:33.652248190Z [14:26:33] [INF] [7] MediaBrowser.MediaEncoding.Encoder.MediaEncoder: FFmpeg: /usr/lib/jellyfin-ffmpeg/ffmpeg 2026-08-22T18:26:33.654394777Z [14:26:33] [INF] [7] Emby.Server.Implementations.ApplicationHost: ServerId: d9fa4abb39204b6e9d680e4b8a0e7df9 2026-08-22T18:26:33.654503981Z [14:26:33] [INF] [7] Emby.Server.Implementations.ApplicationHost: Core startup complete 2026-08-22T18:26:33.654728890Z [14:26:33] [INF] [7] Main: Startup complete 0:00:14.6444281 2026-08-22T18:26:34.411965518Z [ls.io-init] done. 2026-08-22T18:27:32.331610800Z [14:27:32] [INF] [3] Emby.Server.Implementations.Session.SessionManager: Sending shutdown notifications 2026-08-22T18:27:32.336686726Z [14:27:32] [INF] [7] Main: Running query planner optimizations in the database... This might take a while 2026-08-22T18:27:32.359876655Z [14:27:32] [INF] [7] Emby.Server.Implementations.ApplicationHost: Disposing CoreAppHost 2026-08-22T18:27:32.359904256Z [14:27:32] [INF] [7] Emby.Server.Implementations.ApplicationHost: Disposing MusicBrainzArtistProvider 2026-08-22T18:27:32.359908956Z [14:27:32] [INF] [7] Emby.Server.Implementations.ApplicationHost: Disposing MusicBrainzAlbumProvider 2026-08-22T18:27:32.360032662Z [14:27:32] [INF] [7] Emby.Server.Implementations.ApplicationHost: Disposing PluginManager 2026-08-22T18:27:35.841106848Z [migrations] started 2026-08-22T18:27:35.841133749Z [migrations] no migrations found 2026-08-22T18:27:35.871285587Z usermod: no changes 2026-08-22T18:27:35.885303009Z ─────────────────────────────────────── 2026-08-22T18:27:35.885328010Z  2026-08-22T18:27:35.885330010Z       ██╗     ███████╗██╗ ██████╗ 2026-08-22T18:27:35.885331610Z       ██║     ██╔════╝██║██╔═══██╗ 2026-08-22T18:27:35.885333110Z       ██║     ███████╗██║██║   ██║ 2026-08-22T18:27:35.885334610Z       ██║     ╚════██║██║██║   ██║ 2026-08-22T18:27:35.885336011Z       ███████╗███████║██║╚██████╔╝ 2026-08-22T18:27:35.885337511Z       ╚══════╝╚══════╝╚═╝ ╚═════╝ 2026-08-22T18:27:35.885338911Z  2026-08-22T18:27:35.885340211Z    Brought to you by linuxserver.io 2026-08-22T18:27:35.885341611Z ─────────────────────────────────────── 2026-08-22T18:27:35.885836133Z  2026-08-22T18:27:35.885843333Z To support the app dev(s) visit: 2026-08-22T18:27:35.887771019Z Jellyfin: https://opencollective.com/jellyfin 2026-08-22T18:27:35.888259240Z  2026-08-22T18:27:35.888265441Z To support LSIO projects visit: 2026-08-22T18:27:35.888267241Z https://www.linuxserver.io/donate/ 2026-08-22T18:27:35.888268741Z  2026-08-22T18:27:35.888270041Z ─────────────────────────────────────── 2026-08-22T18:27:35.888272441Z GID/UID 2026-08-22T18:27:35.888273741Z ─────────────────────────────────────── 2026-08-22T18:27:35.893366167Z  2026-08-22T18:27:35.893385968Z User UID:    1000 2026-08-22T18:27:35.893387868Z User GID:    1000 2026-08-22T18:27:35.893403069Z ─────────────────────────────────────── 2026-08-22T18:27:35.895073943Z Linuxserver.io version: 10.11.11ubu2604-ls44 2026-08-22T18:27:35.895564564Z Build-date: 2026-08-11T13:45:01+00:00 2026-08-22T18:27:35.895582865Z ─────────────────────────────────────── 2026-08-22T18:27:35.895613667Z      2026-08-22T18:27:35.973034703Z [custom-init] No custom files found, skipping... 2026-08-22T18:27:36.234781519Z [14:27:36] [INF] [1] Emby.Server.Implementations.AppBase.BaseConfigurationManager: Setting cache path: /config/cache 2026-08-22T18:27:36.343337436Z [14:27:36] [INF] [10] Jellyfin.Server.ServerSetupApp.SetupServer: Kestrel is listening on all interfaces 2026-08-22T18:27:36.359915072Z [14:27:36] [INF] [10] Main: Jellyfin version: 10.11.11 2026-08-22T18:27:36.362144871Z [14:27:36] [INF] [10] Main: Environment Variables: ["[JELLYFIN_CACHE_DIR, /config/cache]", "[JELLYFIN_CONFIG_DIR, /config]", "[JELLYFIN_WEB_DIR, /usr/share/jellyfin/web]", "[JELLYFIN_LOG_DIR, /config/log]", "[JELLYFIN_DATA_DIR, /config/data]"] 2026-08-22T18:27:36.362181372Z [14:27:36] [INF] [10] Main: Arguments: ["/usr/lib/jellyfin/bin/jellyfin.dll", "--ffmpeg=/usr/lib/jellyfin-ffmpeg/ffmpeg"] 2026-08-22T18:27:36.362183272Z [14:27:36] [INF] [10] Main: Operating system: Ubuntu 26.04 LTS 2026-08-22T18:27:36.362444384Z [14:27:36] [INF] [10] Main: Architecture: Arm64 2026-08-22T18:27:36.362449984Z [14:27:36] [INF] [10] Main: 64-Bit Process: True 2026-08-22T18:27:36.362452084Z [14:27:36] [INF] [10] Main: User Interactive: True 2026-08-22T18:27:36.362453584Z [14:27:36] [INF] [10] Main: Processor count: 8 2026-08-22T18:27:36.362454985Z [14:27:36] [INF] [10] Main: Program data path: /config/data 2026-08-22T18:27:36.362456385Z [14:27:36] [INF] [10] Main: Log directory path: /config/log 2026-08-22T18:27:36.362457785Z [14:27:36] [INF] [10] Main: Config directory path: /config 2026-08-22T18:27:36.362459185Z [14:27:36] [INF] [10] Main: Cache path: /config/cache 2026-08-22T18:27:36.362507887Z [14:27:36] [INF] [10] Main: Temp directory path: /tmp/jellyfin 2026-08-22T18:27:36.362510987Z [14:27:36] [INF] [10] Main: Web resources path: /usr/share/jellyfin/web 2026-08-22T18:27:36.362554089Z [14:27:36] [INF] [10] Main: Application directory: /usr/lib/jellyfin/bin/ 2026-08-22T18:27:36.374591123Z [14:27:36] [INF] [10] Jellyfin.Server.Startup: Storage path `/config/data/data` (Fixed) successfully checked with 401.8GiB free which is over the minimum of 2GiB. 2026-08-22T18:27:36.377708461Z [14:27:36] [INF] [10] Jellyfin.Server.Startup: Storage path `/config/cache` (Fixed) successfully checked with 401.8GiB free which is over the minimum of 2GiB. 2026-08-22T18:27:36.380443383Z [14:27:36] [INF] [10] Jellyfin.Server.Startup: Storage path `/config/data` (Fixed) successfully checked with 401.8GiB free which is over the minimum of 2GiB. 2026-08-22T18:27:36.384141947Z [14:27:36] [INF] [10] Emby.Server.Implementations.AppBase.BaseConfigurationManager: Setting cache path: /config/cache 2026-08-22T18:27:36.420379755Z [14:27:36] [INF] [10] Jellyfin.Database.Providers.Sqlite.SqliteDatabaseProvider: SQLite connection string: Data Source=/config/data/data/jellyfin.db;Cache=Default;Default Timeout=30;Pooling=True 2026-08-22T18:27:36.422776662Z [14:27:36] [INF] [10] Jellyfin.Database.Providers.Sqlite.SqliteDatabaseProvider: SQLITE connection pragma command set to:  2026-08-22T18:27:36.422805963Z PRAGMA locking_mode=NORMAL; 2026-08-22T18:27:36.422807563Z PRAGMA journal_size_limit=134217728; 2026-08-22T18:27:36.422809063Z PRAGMA synchronous=1; 2026-08-22T18:27:36.422810363Z PRAGMA temp_store=2; 2026-08-22T18:27:36.422811663Z  2026-08-22T18:27:36.423543696Z [14:27:36] [INF] [10] Jellyfin.Database.Implementations.Locking.NoLockBehavior: The database locking mode has been set to: NoLock. 2026-08-22T18:27:36.437996737Z [14:27:36] [INF] [10] Jellyfin.Server.Migrations.JellyfinMigrationService: Initialise Migration service. 2026-08-22T18:27:36.441351586Z [14:27:36] [INF] [10] Jellyfin.Server.Migrations.JellyfinMigrationService: System initialisation detected. Seed data. 2026-08-22T18:27:36.979414764Z [14:27:36] [INF] [10] Jellyfin.Server.Migrations.JellyfinMigrationService: Migration system initialisation completed. 2026-08-22T18:27:36.989442109Z [14:27:36] [INF] [10] Jellyfin.Server.Migrations.JellyfinMigrationService: There are 0 migrations for stage PreInitialisation. 2026-08-22T18:27:36.994845549Z [14:27:36] [INF] [10] Emby.Server.Implementations.AppBase.BaseConfigurationManager: Setting cache path: /config/cache 2026-08-22T18:27:37.036444495Z [14:27:37] [WRN] [7] Microsoft.Extensions.Diagnostics.HealthChecks.DefaultHealthCheckService: Health check StartupCheck with status Degraded completed after 0.4251ms with message 'Server is still starting up.' 2026-08-22T18:27:37.050703428Z [14:27:37] [INF] [10] Emby.Server.Implementations.ApplicationHost: Loading assemblies 2026-08-22T18:27:37.073163825Z [14:27:37] [INF] [10] Jellyfin.Networking.Manager.NetworkManager: Defined LAN subnets: ["::1/128", "fe80::/10", "fc00::/7", "127.0.0.1/8", "10.0.0.0/8", "172.16.0.0/12", "192.168.0.0/16"] 2026-08-22T18:27:37.073190926Z [14:27:37] [INF] [10] Jellyfin.Networking.Manager.NetworkManager: Defined LAN exclusions: [] 2026-08-22T18:27:37.073311231Z [14:27:37] [INF] [10] Jellyfin.Networking.Manager.NetworkManager: Used LAN subnets: ["::1/128", "fe80::/10", "fc00::/7", "127.0.0.1/8", "10.0.0.0/8", "172.16.0.0/12", "192.168.0.0/16"] 2026-08-22T18:27:37.073515941Z [14:27:37] [INF] [10] Jellyfin.Networking.Manager.NetworkManager: Filtered interface addresses: [] 2026-08-22T18:27:37.074211571Z [14:27:37] [INF] [10] Jellyfin.Networking.Manager.NetworkManager: Bind Addresses ["::"] 2026-08-22T18:27:37.074526085Z [14:27:37] [INF] [10] Jellyfin.Networking.Manager.NetworkManager: Remote IP filter is Allowlist 2026-08-22T18:27:37.074530186Z [14:27:37] [INF] [10] Jellyfin.Networking.Manager.NetworkManager: Filtered subnets: [] 2026-08-22T18:27:37.127237525Z [14:27:37] [INF] [10] Jellyfin.Database.Providers.Sqlite.SqliteDatabaseProvider: SQLite connection string: Data Source=/config/data/data/jellyfin.db;Cache=Default;Default Timeout=30;Pooling=True 2026-08-22T18:27:37.127333129Z [14:27:37] [INF] [10] Jellyfin.Database.Providers.Sqlite.SqliteDatabaseProvider: SQLITE connection pragma command set to:  2026-08-22T18:27:37.127337229Z PRAGMA locking_mode=NORMAL; 2026-08-22T18:27:37.127338629Z PRAGMA journal_size_limit=134217728; 2026-08-22T18:27:37.127340029Z PRAGMA synchronous=1; 2026-08-22T18:27:37.127341429Z PRAGMA temp_store=2; 2026-08-22T18:27:37.127342829Z  2026-08-22T18:27:37.127516137Z [14:27:37] [INF] [10] Jellyfin.Database.Implementations.Locking.NoLockBehavior: The database locking mode has been set to: NoLock. 2026-08-22T18:27:37.129915844Z [14:27:37] [INF] [10] Main: Prepare system for possible migrations 2026-08-22T18:27:37.160320693Z [14:27:37] [INF] [10] Jellyfin.Server.Migrations.JellyfinMigrationService: There are 0 migrations for stage CoreInitialisation. 2026-08-22T18:27:37.236089755Z [14:27:37] [INF] [10] Emby.Server.Implementations.Plugins.PluginManager: Loaded plugin: TMDb 10.11.11.0 2026-08-22T18:27:37.236624379Z [14:27:37] [INF] [10] Emby.Server.Implementations.Plugins.PluginManager: Loaded plugin: Studio Images 10.11.11.0 2026-08-22T18:27:37.236948794Z [14:27:37] [INF] [10] Emby.Server.Implementations.Plugins.PluginManager: Loaded plugin: OMDb 10.11.11.0 2026-08-22T18:27:37.246599422Z [14:27:37] [INF] [10] Emby.Server.Implementations.Plugins.PluginManager: Loaded plugin: MusicBrainz 10.11.11.0 2026-08-22T18:27:37.246728328Z [14:27:37] [INF] [10] Emby.Server.Implementations.Plugins.PluginManager: Loaded plugin: AudioDB 10.11.11.0 2026-08-22T18:27:37.273372510Z [14:27:37] [INF] [10] Jellyfin.Server.Migrations.JellyfinMigrationService: There are 0 migrations for stage AppInitialisation. 2026-08-22T18:27:37.387477174Z [14:27:37] [INF] [13] Main: Kestrel is listening on all interfaces 2026-08-22T18:27:37.721837812Z [14:27:37] [WRN] [13] Microsoft.AspNetCore.StaticFiles.StaticFileMiddleware: The WebRootPath was not found: /run/s6-rc:s6-rc-init:eaDliN/servicedirs/svc-jellyfin/wwwroot. Static files may be unavailable. 2026-08-22T18:27:37.763320653Z [14:27:37] [INF] [13] Emby.Server.Implementations.ApplicationHost: Running startup tasks 2026-08-22T18:27:37.769275718Z [14:27:37] [INF] [13] Emby.Server.Implementations.ScheduledTasks.TaskManager: Daily trigger for Generate Trickplay Images set to fire at 2026-08-23 03:00:00.000 -04:00, which is 12:32:22.2312290 from now. 2026-08-22T18:27:37.774007728Z [14:27:37] [INF] [13] Emby.Server.Implementations.ScheduledTasks.TaskManager: Daily trigger for Extract Chapter Images set to fire at 2026-08-23 02:00:00.000 -04:00, which is 11:32:22.2262227 from now. 2026-08-22T18:27:37.808986980Z [14:27:37] [INF] [13] MediaBrowser.MediaEncoding.Encoder.MediaEncoder: Found ffmpeg version 7.1.4 2026-08-22T18:27:37.830339828Z [14:27:37] [INF] [13] MediaBrowser.MediaEncoding.Encoder.MediaEncoder: Available decoders: ["libdav1d", "av1", "av1_cuvid", "av1_rkmpp", "h264", "h264_rkmpp", "h264_cuvid", "hevc", "hevc_rkmpp", "hevc_cuvid", "mpeg1_rkmpp", "mpeg2video", "mpeg2_rkmpp", "mpeg2_cuvid", "mpeg4", "mpeg4_rkmpp", "mpeg4_cuvid", "msmpeg4", "vc1_cuvid", "vp8", "vp8_rkmpp", "libvpx", "vp8_cuvid", "vp9", "vp9_rkmpp", "libvpx-vp9", "vp9_cuvid", "aac", "ac3", "ac4", "dca", "flac", "mp3", "truehd"] 2026-08-22T18:27:37.841496623Z [14:27:37] [INF] [13] MediaBrowser.MediaEncoding.Encoder.MediaEncoder: Available encoders: ["libsvtav1", "av1_nvenc", "libx264", "h264_nvenc", "h264_v4l2m2m", "h264_rkmpp", "libx265", "hevc_nvenc", "hevc_rkmpp", "mjpeg_rkmpp", "aac", "libfdk_aac", "ac3", "alac", "dca", "flac", "libmp3lame", "libopus", "truehd", "libvorbis", "srt"] 2026-08-22T18:27:37.853156040Z [14:27:37] [INF] [13] MediaBrowser.MediaEncoding.Encoder.MediaEncoder: Available filters: ["bwdif_cuda", "bwdif_opencl", "hwupload_cuda", "overlay_opencl", "overlay_cuda", "overlay_rkrga", "scale_cuda", "scale_opencl", "scale_rkrga", "tonemapx", "tonemap_cuda", "tonemap_opencl", "transpose_cuda", "transpose_opencl", "vpp_rkrga", "yadif_cuda", "yadif_opencl", "zscale", "alphasrc"] 2026-08-22T18:27:37.901144070Z [14:27:37] [WRN] [13] MediaBrowser.MediaEncoding.Encoder.MediaEncoder: Filter: overlay_vaapi with option Action to take when encountering EOF from secondary input is not available 2026-08-22T18:27:37.909881257Z [14:27:37] [WRN] [13] MediaBrowser.MediaEncoding.Encoder.MediaEncoder: Filter: overlay_vulkan with option Action to take when encountering EOF from secondary input is not available 2026-08-22T18:27:38.011804535Z [14:27:38] [INF] [13] MediaBrowser.MediaEncoding.Encoder.MediaEncoder: Available hwaccel types: ["cuda", "drm", "opencl", "rkmpp"] 2026-08-22T18:27:40.791103388Z [14:27:40] [INF] [9] Emby.Server.Implementations.ScheduledTasks.TaskManager: Clean up collections and playlists Completed after 0 minute(s) and 0 seconds 2026-08-22T18:27:40.814571268Z [14:27:40] [INF] [16] Emby.Server.Implementations.ScheduledTasks.TaskManager: Clean Transcode Directory Completed after 0 minute(s) and 0 seconds 2026-08-22T18:27:41.201335560Z [14:27:41] [INF] [15] Emby.Server.Implementations.ScheduledTasks.TaskManager: Update Plugins Completed after 0 minute(s) and 0 seconds 2026-08-22T18:27:50.323520167Z [14:27:50] [INF] [13] MediaBrowser.MediaEncoding.Encoder.MediaEncoder: FFmpeg: /usr/lib/jellyfin-ffmpeg/ffmpeg 2026-08-22T18:27:50.325159434Z [14:27:50] [INF] [13] Emby.Server.Implementations.ApplicationHost: ServerId: d9fa4abb39204b6e9d680e4b8a0e7df9 2026-08-22T18:27:50.325256738Z [14:27:50] [INF] [13] Emby.Server.Implementations.ApplicationHost: Core startup complete 2026-08-22T18:27:50.325638454Z [14:27:50] [INF] [13] Main: Startup complete 0:00:14.2850029 2026-08-22T18:27:50.399056940Z [ls.io-init] done. 2026-08-22T18:30:00.056881789Z [14:30:00] [INF] [26] Jellyfin.Api.Auth.CustomAuthenticationHandler: CustomAuthentication was not authenticated. Failure message: Invalid token. 2026-08-22T18:30:00.058702463Z [14:30:00] [INF] [26] Jellyfin.Api.Auth.CustomAuthenticationHandler: CustomAuthentication was not authenticated. Failure message: Invalid token. 2026-08-22T18:30:00.061160664Z [14:30:00] [INF] [26] Jellyfin.Api.Auth.CustomAuthenticationHandler: AuthenticationScheme: CustomAuthentication was challenged.
`

---

## 🐳 Full Docker Inspect

`json
[     {         "Id": "4a0680865a297a93d65e0348fbc28c9d3684dc467dd355291c752af768d06e52",         "Created": "2026-08-22T18:06:46.944595775Z",         "Path": "/init",         "Args": [],         "State": {             "Status": "running",             "Running": true,             "Paused": false,             "Restarting": false,             "OOMKilled": false,             "Dead": false,             "Pid": 13992,             "ExitCode": 0,             "Error": "",             "StartedAt": "2026-08-22T18:27:35.630736112Z",             "FinishedAt": "2026-08-22T18:27:35.344868825Z",             "Health": {                 "Status": "healthy",                 "FailingStreak": 0,                 "Log": [                     {                         "Start": "2026-08-22T18:31:36.193611476Z",                         "End": "2026-08-22T18:31:36.242613484Z",                         "ExitCode": 0,                         "Output": "  % Total    % Received % Xferd  Average Speed  Time    Time    Time   Current\n                                 Dload  Upload  Total   Spent   Left   Speed\n\r  0      0   0      0   0      0      0      0                              0Healthy\r100      7   0      7   0      0    745      0                              0\r100      7   0      7   0      0    741      0                              0\r100      7   0      7   0      0    739      0                              0\n"                     },                     {                         "Start": "2026-08-22T18:32:06.242964703Z",                         "End": "2026-08-22T18:32:06.30345431Z",                         "ExitCode": 0,                         "Output": "  % Total    % Received % Xferd  Average Speed  Time    Time    Time   Current\n                                 Dload  Upload  Total   Spent   Left   Speed\n\r  0      0   0      0   0      0      0      0                              0\r100      7   0      7   0      0    645      0                              0\r100      7   0      7   0      0    641      0                              0\r100      7   0      7   0      0    640      0                              0\nHealthy"                     },                     {                         "Start": "2026-08-22T18:32:36.303575809Z",                         "End": "2026-08-22T18:32:36.356483262Z",                         "ExitCode": 0,                         "Output": "  % Total    % Received % Xferd  Average Speed  Time    Time    Time   Current\n                                 Dload  Upload  Total   Spent   Left   Speed\n\r  0      0   0      0   0      0      0      0                              0\r100      7   0      7   0      0    779      0                              0\r100      7   0      7   0      0    774      0                              0\r100      7   0      7   0      0    772      0                              0\nHealthy"                     },                     {                         "Start": "2026-08-22T18:33:06.35652226Z",                         "End": "2026-08-22T18:33:06.407022009Z",                         "ExitCode": 0,                         "Output": "  % Total    % Received % Xferd  Average Speed  Time    Time    Time   Current\n                                 Dload  Upload  Total   Spent   Left   Speed\n\r  0      0   0      0   0      0      0      0                              0\r100      7   0      7   0      0    712      0                              0\r100      7   0      7   0      0    709      0                              0\r100      7   0      7   0      0    707      0                              0\nHealthy"                     },                     {                         "Start": "2026-08-22T18:33:36.406146391Z",                         "End": "2026-08-22T18:33:36.45392404Z",                         "ExitCode": 0,                         "Output": "  % Total    % Received % Xferd  Average Speed  Time    Time    Time   Current\n                                 Dload  Upload  Total   Spent   Left   Speed\n\r  0      0   0      0   0      0      0      0                              0\r100      7   0      7   0      0    842      0                              0\r100      7   0      7   0      0    837      0                              0\r100      7   0      7   0      0    828      0                              0\nHealthy"                     }                 ]             }         },         "Image": "sha256:0dd18f8de37c7cfbe76877a8b928943b3588beb9678fb223121914ec9a3cdf7c",         "ResolvConfPath": "/var/lib/docker/containers/4a0680865a297a93d65e0348fbc28c9d3684dc467dd355291c752af768d06e52/resolv.conf",         "HostnamePath": "/var/lib/docker/containers/4a0680865a297a93d65e0348fbc28c9d3684dc467dd355291c752af768d06e52/hostname",         "HostsPath": "/var/lib/docker/containers/4a0680865a297a93d65e0348fbc28c9d3684dc467dd355291c752af768d06e52/hosts",         "LogPath": "/var/lib/docker/containers/4a0680865a297a93d65e0348fbc28c9d3684dc467dd355291c752af768d06e52/4a0680865a297a93d65e0348fbc28c9d3684dc467dd355291c752af768d06e52-json.log",         "Name": "/jellyfin",         "RestartCount": 0,         "Driver": "overlayfs",         "Platform": "linux",         "MountLabel": "",         "ProcessLabel": "",         "AppArmorProfile": "",         "ExecIDs": null,         "HostConfig": {             "Binds": [                 "C:\\Users\\Public\\MediaStack\\config\\jellyfin:/config:rw",                 "C:\\Users\\Public\\MediaStack\\media:/media:rw"             ],             "ContainerIDFile": "",             "LogConfig": {                 "Type": "json-file",                 "Config": {}             },             "NetworkMode": "mediastack_default",             "PortBindings": {                 "8096/tcp": [                     {                         "HostIp": "",                         "HostPort": "8097"                     }                 ],                 "8920/tcp": [                     {                         "HostIp": "",                         "HostPort": "8920"                     }                 ]             },             "RestartPolicy": {                 "Name": "unless-stopped",                 "MaximumRetryCount": 0             },             "AutoRemove": false,             "VolumeDriver": "",             "VolumesFrom": null,             "ConsoleSize": [                 0,                 0             ],             "CapAdd": null,             "CapDrop": null,             "CgroupnsMode": "private",             "Dns": null,             "DnsOptions": null,             "DnsSearch": null,             "ExtraHosts": [],             "GroupAdd": null,             "IpcMode": "private",             "Cgroup": "",             "Links": null,             "OomScoreAdj": 0,             "PidMode": "",             "Privileged": false,             "PublishAllPorts": false,             "ReadonlyRootfs": false,             "SecurityOpt": null,             "UTSMode": "",             "UsernsMode": "",             "ShmSize": 67108864,             "Runtime": "runc",             "Isolation": "",             "CpuShares": 0,             "Memory": 0,             "NanoCpus": 0,             "CgroupParent": "",             "BlkioWeight": 0,             "BlkioWeightDevice": null,             "BlkioDeviceReadBps": null,             "BlkioDeviceWriteBps": null,             "BlkioDeviceReadIOps": null,             "BlkioDeviceWriteIOps": null,             "CpuPeriod": 0,             "CpuQuota": 0,             "CpuRealtimePeriod": 0,             "CpuRealtimeRuntime": 0,             "CpusetCpus": "",             "CpusetMems": "",             "Devices": null,             "DeviceCgroupRules": null,             "DeviceRequests": null,             "MemoryReservation": 0,             "MemorySwap": 0,             "MemorySwappiness": null,             "OomKillDisable": null,             "PidsLimit": null,             "Ulimits": null,             "CpuCount": 0,             "CpuPercent": 0,             "IOMaximumIOps": 0,             "IOMaximumBandwidth": 0,             "MaskedPaths": [                 "/proc/acpi",                 "/proc/asound",                 "/proc/interrupts",                 "/proc/kcore",                 "/proc/keys",                 "/proc/latency_stats",                 "/proc/sched_debug",                 "/proc/scsi",                 "/proc/timer_list",                 "/proc/timer_stats",                 "/sys/devices/virtual/powercap",                 "/sys/firmware"             ],             "ReadonlyPaths": [                 "/proc/bus",                 "/proc/fs",                 "/proc/irq",                 "/proc/sys",                 "/proc/sysrq-trigger"             ]         },         "Storage": {             "RootFS": {                 "Snapshot": {                     "Name": "overlayfs"                 }             }         },         "Mounts": [             {                 "Type": "bind",                 "Source": "C:\\Users\\Public\\MediaStack\\media",                 "Destination": "/media",                 "Mode": "rw",                 "RW": true,                 "Propagation": "rprivate"             },             {                 "Type": "bind",                 "Source": "C:\\Users\\Public\\MediaStack\\config\\jellyfin",                 "Destination": "/config",                 "Mode": "rw",                 "RW": true,                 "Propagation": "rprivate"             }         ],         "Config": {             "Hostname": "4a0680865a29",             "Domainname": "",             "User": "",             "AttachStdin": false,             "AttachStdout": true,             "AttachStderr": true,             "ExposedPorts": {                 "8096/tcp": {},                 "8920/tcp": {}             },             "Tty": false,             "OpenStdin": false,             "StdinOnce": false,             "Env": [                 "PUID=1000",                 "PGID=1000",                 "TZ=America/New_York",                 "PATH=/lsiopy/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin",                 "HOME=/root",                 "LANGUAGE=en_US.UTF-8",                 "LANG=en_US.UTF-8",                 "TERM=xterm",                 "S6_CMD_WAIT_FOR_SERVICES_MAXTIME=0",                 "S6_VERBOSITY=1",                 "S6_STAGE2_HOOK=/docker-mods",                 "VIRTUAL_ENV=/lsiopy",                 "LSIO_FIRST_PARTY=true",                 "NVIDIA_DRIVER_CAPABILITIES=compute,video,utility",                 "MALLOC_TRIM_THRESHOLD_=131072",                 "ATTACHED_DEVICES_PERMS=/dev/dri /dev/dvb /dev/vchiq /dev/vc-mem /dev/video1? -type c"             ],             "Cmd": null,             "Healthcheck": {                 "Test": [                     "CMD",                     "curl",                     "-f",                     "http://localhost:8096/health"                 ],                 "Interval": 30000000000,                 "Timeout": 10000000000,                 "Retries": 3             },             "Image": "lscr.io/linuxserver/jellyfin:latest",             "Volumes": {                 "/config": {}             },             "WorkingDir": "/",             "Entrypoint": [                 "/init"             ],             "Labels": {                 "autoheal": "true",                 "build_version": "Linuxserver.io version:- 10.11.11ubu2604-ls44 Build-date:- 2026-08-11T13:45:01+00:00",                 "com.docker.compose.config-hash": "9b60cc98658387defa0adf0ee59a7faa9e8c7132a1d6ba8ac01866cb493492b2",                 "com.docker.compose.container-number": "1",                 "com.docker.compose.depends_on": "",                 "com.docker.compose.image": "sha256:0dd18f8de37c7cfbe76877a8b928943b3588beb9678fb223121914ec9a3cdf7c",                 "com.docker.compose.oneoff": "False",                 "com.docker.compose.project": "mediastack",                 "com.docker.compose.project.config_files": "C:\\Users\\Public\\MediaStack\\docker-compose.yml",                 "com.docker.compose.project.working_dir": "C:\\Users\\Public\\MediaStack",                 "com.docker.compose.service": "jellyfin",                 "com.docker.compose.version": "5.3.1",                 "maintainer": "thelamer",                 "org.opencontainers.image.authors": "linuxserver.io",                 "org.opencontainers.image.created": "2026-08-11T13:45:01+00:00",                 "org.opencontainers.image.description": "[Jellyfin](https://github.com/jellyfin/jellyfin) is a Free Software Media System that puts you in control of managing and streaming your media. It is an alternative to the proprietary Emby and Plex, to provide media from a dedicated server to end-user devices via multiple apps. Jellyfin is descended from Emby's 3.5.2 release and ported to the .NET Core framework to enable full cross-platform support. There are no strings attached, no premium licenses or features, and no hidden agendas: just a team who want to build something better and work together to achieve it.",                 "org.opencontainers.image.documentation": "https://docs.linuxserver.io/images/docker-jellyfin",                 "org.opencontainers.image.licenses": "GPL-3.0-only",                 "org.opencontainers.image.ref.name": "65a35ed5d927d6707eb8b3b53f740c604308045f",                 "org.opencontainers.image.revision": "65a35ed5d927d6707eb8b3b53f740c604308045f",                 "org.opencontainers.image.source": "https://github.com/linuxserver/docker-jellyfin",                 "org.opencontainers.image.title": "Jellyfin",                 "org.opencontainers.image.url": "https://github.com/linuxserver/docker-jellyfin/packages",                 "org.opencontainers.image.vendor": "linuxserver.io",                 "org.opencontainers.image.version": "10.11.11ubu2604-ls44"             }         },         "NetworkSettings": {             "SandboxID": "ff32a861bca0efdf739ce80f527cc51adb55f81cdb742d3b59e30a65f4fe9e61",             "SandboxKey": "/var/run/docker/netns/ff32a861bca0",             "Ports": {                 "8096/tcp": [                     {                         "HostIp": "0.0.0.0",                         "HostPort": "8097"                     },                     {                         "HostIp": "::",                         "HostPort": "8097"                     }                 ],                 "8920/tcp": [                     {                         "HostIp": "0.0.0.0",                         "HostPort": "8920"                     },                     {                         "HostIp": "::",                         "HostPort": "8920"                     }                 ]             },             "Networks": {                 "mediastack_default": {                     "IPAMConfig": null,                     "Links": null,                     "Aliases": [                         "jellyfin",                         "jellyfin"                     ],                     "DriverOpts": null,                     "GwPriority": 0,                     "NetworkID": "c1e26df2c8f37ebab98723ad4966bf4ccf8003b0e0f126e2b55837866af60ad7",                     "EndpointID": "08aed207941e362c89137c23cbf02ee2a2e961bdd2c5048f54ecf053db0c14f7",                     "Gateway": "172.18.0.1",                     "IPAddress": "172.18.0.3",                     "MacAddress": "0e:d6:e8:5f:10:ae",                     "IPPrefixLen": 16,                     "IPv6Gateway": "",                     "GlobalIPv6Address": "",                     "GlobalIPv6PrefixLen": 0,                     "DNSNames": [                         "jellyfin",                         "4a0680865a29"                     ]                 }             }         },         "ImageManifestDescriptor": {             "mediaType": "application/vnd.oci.image.manifest.v1+json",             "digest": "sha256:0ae1c3c4dd32103795193f11bc70e082bf7af41da4a113fd8d0c9003a7e2bef5",             "size": 2190,             "platform": {                 "architecture": "arm64",                 "os": "linux"             }         }     } ]
`

---

*This handoff was automatically generated by the MediaStack Autohealer.*
*To assist with this failure, paste this entire file into an AI assistant chat.*
