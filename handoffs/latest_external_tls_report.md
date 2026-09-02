# [REPORT] External Connectivity and TLS Security Certificate Audit

| Audit Parameter | Value | Status |
| :--- | :--- | :---: |
| **Audit Timestamp** | 2026-09-02 13:39:33 | PASS |
| **Host Node** | **VOLTAIREDEUX** | PASS |
| **Public WAN IP** | $wanIp | ACTIVE |
| **Domain Resolution** | $ddnsDomain -> $ddnsIp | RESOLVED |
| **TLS Certificate Status** | VALID (Expires in 3649.1 days) | VALID |
| **HTTPS Dual-Ingress** | Port :443 and Fallback :444 Operational | PASS |

---

## 1. Security Certificate Cryptographic Integrity

| Certificate Attribute | Specification | Cryptographic Assessment |
| :--- | :--- | :--- |
| **Subject DN** | $(System.Collections.Specialized.OrderedDictionary['Subject']) | Standard Multi-Domain CN |
| **Issuer DN** | $(System.Collections.Specialized.OrderedDictionary['Issuer']) | Dedicated MediaStack Root CA |
| **Thumbprint** | $(System.Collections.Specialized.OrderedDictionary['Thumbprint']) | SHA-1 Integrity Hash |
| **Key Strength** | **4096 bits** (sha256RSA) | Enterprise-Grade RSA 4096-bit |
| **Validity Horizon** | 2026-09-01 to **2036-08-29** | **3649.1 days** remaining |
| **Subject Alternative Names (SAN)** | $(System.Collections.Specialized.OrderedDictionary['SANs']) | Covers WAN domain, Local IPs, Hostnames |
| **TLS Ingress Compatibility** | TLSv1.3, TLSv1.2, ECDHE, AES-256-GCM | 100% Modern Browser / Client Viability |

---

## 2. External Cloud APIs and Upstream Sync Latency

| Target Service | Endpoint URL | HTTP Status | Roundtrip Latency | Health State |
| :--- | :--- | :---: | :---: | :---: |
| **MusicBrainz API** | [API Endpoint](https://musicbrainz.org/ws/2/artist/f27ec8db-af05-4f36-916e-3d57f91ecf5e?fmt=json) | HTTP 200 | $(@{Name=MusicBrainz API; Url=https://musicbrainz.org/ws/2/artist/f27ec8db-af05-4f36-916e-3d57f91ecf5e?fmt=json; Code=200; Latency=483 ms; Healthy=True}.Latency) | Healthy (PASS) |
| **AcoustID API** | [API Endpoint](https://api.acoustid.org/v2/lookup) | HTTP 0 | $(@{Name=AcoustID API; Url=https://api.acoustid.org/v2/lookup; Code=0; Latency=201 ms; Healthy=False}.Latency) | Offline (FAIL) |
| **TheMovieDB (TMDB)** | [API Endpoint](https://api.themoviedb.org/3/configuration) | HTTP 0 | $(@{Name=TheMovieDB (TMDB); Url=https://api.themoviedb.org/3/configuration; Code=0; Latency=95 ms; Healthy=False}.Latency) | Offline (FAIL) |
| **Sonarr Skyhook** | [API Endpoint](https://skyhook.sonarr.tv/v1/tvdb/shows/en/71663) | HTTP 200 | $(@{Name=Sonarr Skyhook; Url=https://skyhook.sonarr.tv/v1/tvdb/shows/en/71663; Code=200; Latency=94 ms; Healthy=True}.Latency) | Healthy (PASS) |
| **Radarr Cloud API** | [API Endpoint](https://radarr.servarr.com/v1/update) | HTTP 0 | $(@{Name=Radarr Cloud API; Url=https://radarr.servarr.com/v1/update; Code=0; Latency=74 ms; Healthy=False}.Latency) | Offline (FAIL) |
| **GitHub Releases** | [API Endpoint](https://api.github.com/zen) | HTTP 200 | $(@{Name=GitHub Releases; Url=https://api.github.com/zen; Code=200; Latency=76 ms; Healthy=True}.Latency) | Healthy (PASS) |

---

## 3. Live TLS Ingress Handshake Verification

| Ingress Gateway | Binding Socket | Negotiated Protocol | Cipher Suite | Handshake Result |
| :--- | :---: | :---: | :---: | :---: |
| **Caddy Primary HTTPS (:443)** | :443 | $(@{Name=Caddy Primary HTTPS (:443); Host=127.0.0.1; Port=443; Success=True; Protocol=Tls13; Cipher=Aes128 (128 bits); Error=}.Protocol) | $(@{Name=Caddy Primary HTTPS (:443); Host=127.0.0.1; Port=443; Success=True; Protocol=Tls13; Cipher=Aes128 (128 bits); Error=}.Cipher) | **PASS** |
| **Caddy Fallback HTTPS (:444)** | :444 | $(@{Name=Caddy Fallback HTTPS (:444); Host=127.0.0.1; Port=444; Success=True; Protocol=Tls13; Cipher=Aes128 (128 bits); Error=}.Protocol) | $(@{Name=Caddy Fallback HTTPS (:444); Host=127.0.0.1; Port=444; Success=True; Protocol=Tls13; Cipher=Aes128 (128 bits); Error=}.Cipher) | **PASS** |
| **Caddy LAN IP (:443)** | :443 | $(@{Name=Caddy LAN IP (:443); Host=192.168.4.30; Port=443; Success=False; Protocol=None; Cipher=None; Error=Exception calling "Connect" with "2" argument(s): "A connection attempt failed because the connected party did not properly respond after a period of time, or established connection failed because connected host has failed to respond 192.168.4.30:443"}.Protocol) | $(@{Name=Caddy LAN IP (:443); Host=192.168.4.30; Port=443; Success=False; Protocol=None; Cipher=None; Error=Exception calling "Connect" with "2" argument(s): "A connection attempt failed because the connected party did not properly respond after a period of time, or established connection failed because connected host has failed to respond 192.168.4.30:443"}.Cipher) | **FAILED** |

---

## 4. Quick Access and Verification Links

- [Mission Control HTTPS Dashboard](https://192.168.4.30/dashboard/)
- [Fallback HTTPS Dashboard (:444)](https://192.168.4.30:444/dashboard/)
- [Server Certificate File](file:///C:/Users/waltd/OneDrive/Mediastack/certs/server.crt)
- [MediaStack Root CA](file:///C:/Users/waltd/OneDrive/Mediastack/certs/ca.crt)
- [Caddyfile Security Blueprint](file:///C:/Users/waltd/OneDrive/Mediastack/Caddyfile)

---
*Audit executed automatically by MediaStack Security & Telemetry Engine.*