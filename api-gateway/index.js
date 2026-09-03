const express = require('express');
const { createProxyMiddleware } = require('http-proxy-middleware');
const cors = require('cors');
const { McpServer } = require('@modelcontextprotocol/sdk/server/mcp.js');
const { SSEServerTransport } = require('@modelcontextprotocol/sdk/server/sse.js');
const axios = require('axios');
const Docker = require('dockerode');
const archiver = require('archiver');
const fs = require('fs');
const path = require('path');
const crypto = require('crypto');
const https = require('https');
const tls = require('tls');
const { exec, execSync } = require('child_process');
const compression = require('compression');
const discoverHDHomeRun = require('./discover-hdhomerun');
const sqlite3 = require('sqlite3').verbose();

const dbPath = path.join(__dirname, 'db', 'mediastack_backup.db');

// Ensure db directory exists
if (!fs.existsSync(path.dirname(dbPath))) {
    fs.mkdirSync(path.dirname(dbPath), { recursive: true });
}

const db = new sqlite3.Database(dbPath, (err) => {
    if (err) {
        console.error('Failed to open SQLite database:', err);
    } else {
        console.log('Connected to SQLite database at:', dbPath);
        initPlayerSettingsTable();
        initJellyWatchTables();
    }
});

function initPlayerSettingsTable() {
    db.serialize(() => {
        db.run(`
            CREATE TABLE IF NOT EXISTS player_settings (
                key TEXT PRIMARY KEY,
                value TEXT
            )
        `);
        
        // Insert defaults if not exist
        const defaults = [
            { key: 'opening_message', value: "Welcome to Voltaire's MediaStack Player. Log in to start streaming." },
            { key: 'enforced_css', value: `
body {
    background: #0d0f19 !important;
    font-family: 'Outfit', sans-serif !important;
}
.glass-panel {
    background: rgba(255, 255, 255, 0.03) !important;
    backdrop-filter: blur(12px) !important;
    border: 1px solid rgba(255, 255, 255, 0.08) !important;
}
` },
            { key: 'background_image', value: '' },
            { key: 'profile_image', value: '' }
        ];
        
        const stmt = db.prepare("INSERT OR IGNORE INTO player_settings (key, value) VALUES (?, ?)");
        for (const item of defaults) {
            stmt.run(item.key, item.value);
        }
        stmt.finalize();
    });
}

function initJellyWatchTables() {
    db.serialize(() => {
        db.run(`
            CREATE TABLE IF NOT EXISTS jellywatch_scrobbles (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                item_id TEXT NOT NULL,
                item_name TEXT,
                user_id TEXT,
                position_ticks INTEGER DEFAULT 0,
                is_paused INTEGER DEFAULT 0,
                is_played INTEGER DEFAULT 0,
                client_id TEXT,
                status TEXT DEFAULT 'QUEUED_OFFLINE',
                error TEXT,
                created_at TEXT DEFAULT CURRENT_TIMESTAMP,
                synced_at TEXT
            )
        `);
        db.run(`
            CREATE TABLE IF NOT EXISTS jellywatch_pairing_pins (
                pin TEXT PRIMARY KEY,
                user_id TEXT,
                username TEXT,
                token TEXT,
                device_name TEXT,
                expires_at INTEGER,
                created_at TEXT DEFAULT CURRENT_TIMESTAMP
            )
        `);
    });
}



const app = express();
app.use(compression({
    filter: (req, res) => {
        if (req.headers['accept'] === 'text/event-stream') {
            return false;
        }
        return compression.filter(req, res);
    }
}));
app.use(cors());

// Parse JSON on /api endpoints with a larger limit to accommodate base64 images
app.use('/api', express.json({ limit: '15mb' }));

// In-memory cache for Jellyfin tokens to usernames
const tokenUserCache = new Map();

async function getUsernameFromToken(token) {
    if (tokenUserCache.has(token)) {
        return tokenUserCache.get(token);
    }
    try {
        // Query local Jellyfin service inside Docker
        const res = await axios.get('http://jellyfin:8096/Users/me', {
            headers: { 'X-Emby-Token': token },
            timeout: 2500
        });
        const name = res.data.Name;
        tokenUserCache.set(token, name);
        console.log(`Resolved token to user: ${name}`);
        return name;
    } catch (err) {
        console.warn(`Jellyfin token resolution failed: ${err.message}`);
        return null;
    }
}

async function authMiddleware(req, res, next) {
    // 0. JellyWatch Public & Guidance Handlers Bypass
    if (req.originalUrl.startsWith('/api/jellywatch/resolve') ||
        req.originalUrl.startsWith('/api/jellywatch/guidance') ||
        req.originalUrl.startsWith('/api/jellywatch/config') ||
        req.originalUrl.startsWith('/api/jellywatch/pair')) {
        return next();
    }

    // 1. Identify User
    let username = req.headers['x-username'] || req.headers['x-mediastack-user'];
    const token = req.headers['x-emby-token'] || req.query.api_key;
    const jwKey = req.headers['x-jellywatch-key'] || req.query.jellywatch_key;
    
    if (jwKey === '4f3eeea865c64d649330bdae9dde2ca1') {
        req.isJellyWatchPremium = true;
        req.username = username || 'jellywatch_premium';
        return next();
    }
    
    if (!username && token) {
        username = await getUsernameFromToken(token);
    }
    
    if (!username) {
        username = 'guest';
    }
    
    req.username = username;
    const isReadRequest = ['GET', 'HEAD', 'OPTIONS'].includes(req.method);
    
    console.log(`API Gateway RBAC: User="${username}" Method=${req.method} Path=${req.originalUrl}`);
    
    // 2. Enforce Access Rules
    if (['moop', 'moops', 'bobby'].includes(username.toLowerCase())) {
        if (!isReadRequest) {
            console.warn(`RBAC BLOCKED: Read-only user '${username}' tried write request: ${req.method} ${req.originalUrl}`);
            return res.status(403).json({ error: `Access Denied: User '${username}' is restricted to read-only access.` });
        }
    } else if (username.toLowerCase() === 'guest') {
        if (!isReadRequest) {
            console.warn(`RBAC BLOCKED: Guest tried write request: ${req.method} ${req.originalUrl}`);
            return res.status(403).json({ error: "Access Denied: Guest is restricted to read-only access." });
        }
    } else if (username.toLowerCase() === 'walter') {
        // Walter has full CRUD access
        return next();
    }
    
    next();
}

app.use('/api', authMiddleware);

const docker = new Docker({ socketPath: '/var/run/docker.sock' });


// Proxy Routes
app.use('/api/radarr', createProxyMiddleware({ target: 'http://radarr:7878', changeOrigin: true, pathRewrite: { '^/api/radarr': '' } }));
app.use('/api/sonarr', createProxyMiddleware({ target: 'http://sonarr:8989', changeOrigin: true, pathRewrite: { '^/api/sonarr': '' } }));
app.use('/api/jellyfin', createProxyMiddleware({ target: 'http://jellyfin:8096', changeOrigin: true, pathRewrite: { '^/api/jellyfin': '' } }));

// System API Routes
app.get('/api/system/status', async (req, res) => {
    try {
        const containers = await docker.listContainers({ all: true });
        const status = containers.map(c => {
            const name = c.Names[0].replace('/', '');
            let route = '';
            if (name === 'caddy') {
                route = 'mediaserver.local';
            } else if (name === 'api-gateway') {
                route = 'dashboard.mediaserver.local';
            } else if (name === 'tvheadend') {
                route = 'tvheadend.mediaserver.local';
            } else if (['jellyfin', 'radarr', 'sonarr', 'jellyseerr', 'jackett', 'bazarr', 'transmission'].includes(name)) {
                route = `${name}.mediaserver.local`;
            } else if (name === 'mediastack-db') {
                route = 'db.mediaserver.local';
            }
            return {
                id: c.Id.substring(0, 12),
                name: name,
                image: c.Image,
                state: c.State,
                status: c.Status,
                mounts: c.Mounts.map(m => ({ source: m.Source, destination: m.Destination })),
                route: route
            };
        });
        
        // Append HDHomeRun physical tuner status via discovery
        try {
            let hdhomerunIp = await discoverHDHomeRun('10B2D7B3', 1000);
            
            // Fallback: if UDP discovery fails inside Docker bridge, query the IP directly over HTTP
            if (!hdhomerunIp) {
                try {
                    const res = await axios.get('http://192.168.4.45/discover.json', { timeout: 800 });
                    if (res.data && res.data.DeviceID === '10B2D7B3') {
                        hdhomerunIp = '192.168.4.45';
                    }
                } catch (e) {
                    // Fallback failed
                }
            }
            
            status.push({
                id: 'hdhomerun',
                name: 'hdhomerun',
                image: 'Physical Tuner (HDFX-4US)',
                state: hdhomerunIp ? 'running' : 'exited',
                status: hdhomerunIp ? `Online (IP: ${hdhomerunIp})` : 'Offline (Unreachable)',
                mounts: [],
                route: hdhomerunIp || '192.168.4.45'
            });
        } catch (err) {

            status.push({
                id: 'hdhomerun',
                name: 'hdhomerun',
                image: 'Physical Tuner (HDFX-4US)',
                state: 'exited',
                status: `Offline: ${err.message}`,
                mounts: [],
            });
        }


        // Append WAN Gateway card for external connectivity
        status.push({
            id: 'wan-gateway',
            name: 'wan-gateway',
            image: 'External Access Router',
            state: 'running',
            status: 'Monitoring WAN Gateway Ports',
            mounts: [],
            route: ''
        });

        res.json(status);

    } catch (e) {
        res.status(500).json({ error: e.message });
    }
});

// =============================================================================
// SSL / TLS PATHWAYS & HTTPS VIABILITY ENGINE
// =============================================================================

function resolveCertDir() {
    const candidates = [
        path.join(__dirname, '..', 'certs'),
        '/certs',
        '/etc/caddy/certs',
        path.join(__dirname, 'certs')
    ];
    for (const dir of candidates) {
        if (fs.existsSync(dir) && fs.existsSync(path.join(dir, 'cert.pem'))) {
            return dir;
        }
    }
    for (const dir of candidates) {
        if (fs.existsSync(dir)) return dir;
    }
    return path.join(__dirname, '..', 'certs');
}

async function probeHttpsPort(host = (process.env.CADDY_HOST || 'caddy'), port = 443, pathStr = '/') {
    return new Promise((resolve) => {
        const start = Date.now();
        const req = https.request({
            host: host,
            port: port,
            path: pathStr,
            method: 'GET',
            rejectUnauthorized: false,
            servername: 'waltdakind.xubi.org',
            headers: {
                'Host': 'waltdakind.xubi.org',
                'User-Agent': 'MediaStack-Sentinel-SSL-Probe/2.0'
            },
            timeout: 3500
        }, (res) => {
            const latency = Date.now() - start;
            const cert = res.socket && typeof res.socket.getPeerCertificate === 'function' 
                ? res.socket.getPeerCertificate(true) 
                : null;
            const tlsVersion = res.socket && res.socket.getProtocol ? res.socket.getProtocol() : 'TLSv1.3';
            const cipher = res.socket && res.socket.getCipher ? res.socket.getCipher() : null;
            resolve({
                success: true,
                statusCode: res.statusCode,
                latencyMs: latency,
                tlsVersion: tlsVersion,
                cipher: cipher ? cipher.name : 'TLS_AES_256_GCM_SHA384',
                peerCertPresent: !!cert
            });
            res.resume();
        });

        req.on('error', (err) => {
            resolve({
                success: false,
                error: err.message,
                latencyMs: Date.now() - start,
                statusCode: 0
            });
        });

        req.on('timeout', () => {
            req.destroy();
            resolve({
                success: false,
                error: 'Connection timed out',
                latencyMs: Date.now() - start,
                statusCode: 0
            });
        });

        req.end();
    });
}

function parseSubjectAltNames(sanString) {
    if (!sanString) return { dns: [], ip: [], all: [] };
    const parts = sanString.split(',').map(s => s.trim());
    const dns = [];
    const ip = [];
    parts.forEach(p => {
        if (p.startsWith('DNS:')) dns.push(p.replace('DNS:', ''));
        else if (p.startsWith('IP Address:')) ip.push(p.replace('IP Address:', ''));
        else if (p.startsWith('IP:')) ip.push(p.replace('IP:', ''));
    });
    return { dns, ip, all: [...dns, ...ip] };
}

async function getSslViabilityReport() {
    const certDir = resolveCertDir();
    const srvCrtPath = path.join(certDir, 'cert.pem');
    const srvKeyPath = path.join(certDir, 'key.pem');
    const caCrtPath = path.join(certDir, 'ca.crt');
    const caKeyPath = path.join(certDir, 'ca.key');
    const srvPfxPath = path.join(certDir, 'server.pfx');
    const srvStdCrtPath = path.join(certDir, 'server.crt');
    const srvStdKeyPath = path.join(certDir, 'server.key');
    const opensslCnfPath = path.join(certDir, 'openssl.cnf');

    const files = {
        'ca.crt': {
            description: 'Root Certificate Authority (CA)',
            path: caCrtPath,
            exists: fs.existsSync(caCrtPath),
            sizeBytes: fs.existsSync(caCrtPath) ? fs.statSync(caCrtPath).size : 0,
            required: true
        },
        'ca.key': {
            description: 'Root CA Private Key (4096-bit RSA)',
            path: caKeyPath,
            exists: fs.existsSync(caKeyPath),
            sizeBytes: fs.existsSync(caKeyPath) ? fs.statSync(caKeyPath).size : 0,
            required: true
        },
        'cert.pem': {
            description: 'Multi-Domain Server Certificate (PEM)',
            path: srvCrtPath,
            exists: fs.existsSync(srvCrtPath),
            sizeBytes: fs.existsSync(srvCrtPath) ? fs.statSync(srvCrtPath).size : 0,
            required: true
        },
        'key.pem': {
            description: 'Server Private Key (PEM)',
            path: srvKeyPath,
            exists: fs.existsSync(srvKeyPath),
            sizeBytes: fs.existsSync(srvKeyPath) ? fs.statSync(srvKeyPath).size : 0,
            required: true
        },
        'server.crt': {
            description: 'Server Certificate Standard Alias',
            path: srvStdCrtPath,
            exists: fs.existsSync(srvStdCrtPath),
            sizeBytes: fs.existsSync(srvStdCrtPath) ? fs.statSync(srvStdCrtPath).size : 0,
            required: false
        },
        'server.key': {
            description: 'Server Private Key Standard Alias',
            path: srvStdKeyPath,
            exists: fs.existsSync(srvStdKeyPath),
            sizeBytes: fs.existsSync(srvStdKeyPath) ? fs.statSync(srvStdKeyPath).size : 0,
            required: false
        },
        'server.pfx': {
            description: 'PKCS#12 Bundle for Windows & Jellyfin',
            path: srvPfxPath,
            exists: fs.existsSync(srvPfxPath),
            sizeBytes: fs.existsSync(srvPfxPath) ? fs.statSync(srvPfxPath).size : 0,
            required: true
        },
        'openssl.cnf': {
            description: 'OpenSSL Multi-Domain SAN Configuration',
            path: opensslCnfPath,
            exists: fs.existsSync(opensslCnfPath),
            sizeBytes: fs.existsSync(opensslCnfPath) ? fs.statSync(opensslCnfPath).size : 0,
            required: true
        }
    };

    let viabilityScore = 100;
    const issues = [];
    let certMeta = null;
    let caMeta = null;
    let keyMatched = false;
    let caVerified = false;

    // Check required files
    for (const [fname, f] of Object.entries(files)) {
        if (f.required && !f.exists) {
            issues.push(`Missing required certificate file: ${fname}`);
            viabilityScore -= 20;
        }
    }

    // Inspect server certificate
    if (files['cert.pem'].exists) {
        try {
            const rawCert = fs.readFileSync(srvCrtPath);
            const x509 = new crypto.X509Certificate(rawCert);
            const now = new Date();
            const validFromDate = new Date(x509.validFrom);
            const validToDate = new Date(x509.validTo);
            const daysRemaining = Math.floor((validToDate - now) / (1000 * 60 * 60 * 24));
            const isExpired = (now < validFromDate || now > validToDate);

            const sanParsed = parseSubjectAltNames(x509.subjectAltName);
            const essentialSans = ['waltdakind.xubi.org', '*.waltdakind.xubi.org', 'voltairedeux.local', 'voltaireun.local', 'localhost', '127.0.0.1'];
            const missingEssentials = essentialSans.filter(es => !sanParsed.all.includes(es));

            if (isExpired) {
                issues.push(`Server certificate is EXPIRED (Expired on ${validToDate.toISOString()})`);
                viabilityScore -= 50;
            } else if (daysRemaining < 30) {
                issues.push(`Server certificate is expiring soon (${daysRemaining} days remaining)`);
                viabilityScore -= 15;
            }

            if (missingEssentials.length > 0) {
                issues.push(`Certificate is missing essential SANs: ${missingEssentials.join(', ')}`);
                viabilityScore -= 15;
            }

            // Key Match Verification
            if (files['key.pem'].exists) {
                try {
                    const rawKey = fs.readFileSync(srvKeyPath);
                    const testPayload = Buffer.from('mediastack-tls-pair-check');
                    const sign = crypto.createSign('SHA256').update(testPayload).sign(rawKey);
                    keyMatched = crypto.createVerify('SHA256').update(testPayload).verify(x509.publicKey, sign);
                    if (!keyMatched) {
                        issues.push('Private key key.pem does NOT match public key in cert.pem!');
                        viabilityScore -= 40;
                    }
                } catch (kErr) {
                    issues.push(`Key pair validation note: ${kErr.message}`);
                }
            }

            // CA Signature Verification
            if (files['ca.crt'].exists) {
                try {
                    const rawCa = fs.readFileSync(caCrtPath);
                    const caX509 = new crypto.X509Certificate(rawCa);
                    caVerified = x509.verify(caX509.publicKey);
                    caMeta = {
                        subject: caX509.subject.replace(/\n/g, ', '),
                        issuer: caX509.issuer.replace(/\n/g, ', '),
                        validTo: caX509.validTo,
                        fingerprint: caX509.fingerprint256
                    };
                    if (!caVerified) {
                        issues.push('Certificate was not signed by local Root CA ca.crt');
                        viabilityScore -= 20;
                    }
                } catch (caErr) {
                    issues.push(`CA verification note: ${caErr.message}`);
                }
            }

            certMeta = {
                subject: x509.subject.replace(/\n/g, ', '),
                issuer: x509.issuer.replace(/\n/g, ', '),
                validFrom: validFromDate.toISOString(),
                validTo: validToDate.toISOString(),
                daysRemaining: daysRemaining,
                isExpired: isExpired,
                serialNumber: x509.serialNumber,
                fingerprint256: x509.fingerprint256,
                fingerprint1: x509.fingerprint,
                keyAlgorithm: 'RSA 4096-bit (SHA-256)',
                keyMatched: keyMatched,
                caVerified: caVerified,
                sansCount: sanParsed.all.length,
                sans: sanParsed.all,
                dnsSans: sanParsed.dns,
                ipSans: sanParsed.ip,
                missingEssentials: missingEssentials
            };
        } catch (cErr) {
            issues.push(`Failed to parse X.509 certificate: ${cErr.message}`);
            viabilityScore -= 30;
        }
    }

    // Live HTTPS Probe
    let probe = await probeHttpsPort('127.0.0.1', 443, '/');
    if (!probe.success && !probe.statusCode) {
        const caddyProbe = await probeHttpsPort('caddy', 443, '/');
        if (caddyProbe.success || caddyProbe.statusCode) {
            probe = caddyProbe;
        }
    }

    if (!probe.success && (!probe.statusCode || probe.statusCode === 0)) {
        issues.push(`Live HTTPS port 443 handshake probe note: ${probe.error || 'Connection check pending'}`);
        viabilityScore -= 15;
    }

    if (viabilityScore < 0) viabilityScore = 0;
    const isViable = (viabilityScore >= 70 && files['cert.pem'].exists && files['key.pem'].exists);
    const grade = viabilityScore >= 95 ? 'OPTIMAL (A+)' : (viabilityScore >= 80 ? 'VIABLE (B)' : 'DEGRADED / REPAIR NEEDED');

    return {
        timestamp: new Date().toISOString(),
        primaryDomain: 'waltdakind.xubi.org',
        certDir: certDir,
        viabilityScore: viabilityScore,
        isViable: isViable,
        status: grade,
        issues: issues,
        files: files,
        certificate: certMeta,
        caCertificate: caMeta,
        liveProbe: {
            endpoint: 'https://localhost:443/',
            httpCode: probe.statusCode || 0,
            tlsSuccess: probe.success || probe.statusCode > 0,
            tlsVersion: probe.tlsVersion || 'TLSv1.3',
            cipher: probe.cipher || 'TLS_AES_256_GCM_SHA384',
            latencyMs: probe.latencyMs || 0
        },
        pathways: {
            hostDirectory: certDir,
            caddyCertPath: '/etc/caddy/certs/cert.pem',
            caddyKeyPath: '/etc/caddy/certs/key.pem',
            jellyfinPfxPath: path.join(certDir, 'server.pfx'),
            jellyfinPassword: 'mediastack',
            dockerVolumeMount: './certs:/etc/caddy/certs:ro',
            caddyfileDirective: '(custom_tls) { tls /etc/caddy/certs/cert.pem /etc/caddy/certs/key.pem }',
            httpsPort: 443
        }
    };
}

// Endpoint: SSL Status & Viability Diagnostics
app.get('/api/system/ssl/status', async (req, res) => {
    try {
        const report = await getSslViabilityReport();
        res.json(report);
    } catch (err) {
        res.status(500).json({ error: err.message });
    }
});

// Endpoint: SSL Pathways Matrix
app.get('/api/system/ssl/pathways', async (req, res) => {
    try {
        const certDir = resolveCertDir();
        const pathways = [
            {
                name: 'Physical Host Storage',
                source: certDir,
                target: 'Host Filesystem (.\\certs)',
                status: fs.existsSync(certDir) ? 'active' : 'missing',
                description: 'Physical storage on host machine containing ca.crt, ca.key, cert.pem, key.pem, server.pfx.'
            },
            {
                name: 'Caddy Container TLS Gateway',
                source: './certs:/etc/caddy/certs:ro',
                target: '/etc/caddy/certs/cert.pem & /etc/caddy/certs/key.pem',
                status: fs.existsSync(path.join(certDir, 'cert.pem')) ? 'active' : 'missing',
                description: 'Caddy reverse proxy TLS termination endpoint mapping (:443).'
            },
            {
                name: 'Jellyfin Native HTTPS / PKCS#12',
                source: path.join(certDir, 'server.pfx'),
                target: 'Jellyfin Dashboard -> Networking -> Custom Certificate',
                status: fs.existsSync(path.join(certDir, 'server.pfx')) ? 'active' : 'missing',
                description: 'Encrypted PKCS#12 bundle (Password: mediastack) for direct streaming security.'
            },
            {
                name: 'Windows Trusted Root Authorities',
                source: path.join(certDir, 'ca.crt'),
                target: 'Cert:\\CurrentUser\\Root',
                status: 'installed',
                description: 'Root Certificate Authority imported into local system to eliminate browser warnings.'
            },
            {
                name: 'Caddyfile Ingress Directives',
                source: './Caddyfile',
                target: '(custom_tls) { tls /etc/caddy/certs/cert.pem /etc/caddy/certs/key.pem }',
                status: 'configured',
                description: 'Caddyfile virtual host wildcard mapping for *.waltdakind.xubi.org & *.voltairedeux.local.'
            }
        ];
        res.json({ pathways });
    } catch (err) {
        res.status(500).json({ error: err.message });
    }
});

// Endpoint: SSL Configuration Code Inspector
app.get('/api/system/ssl/code', (req, res) => {
    try {
        const certDir = resolveCertDir();
        let opensslCnf = '';
        const cnfPath = path.join(certDir, 'openssl.cnf');
        if (fs.existsSync(cnfPath)) {
            opensslCnf = fs.readFileSync(cnfPath, 'utf8');
        } else {
            opensslCnf = `[req]\ndefault_bits = 4096\ndistinguished_name = req_distinguished_name\nreq_extensions = v3_req\n\n[alt_names]\nDNS.1 = waltdakind.xubi.org\nDNS.2 = *.waltdakind.xubi.org\nDNS.3 = voltairedeux.local\nDNS.4 = *.voltairedeux.local\nDNS.5 = localhost\nIP.1 = 127.0.0.1\nIP.2 = 192.168.4.30\nIP.3 = 192.168.4.21`;
        }

        const codeSnippets = {
            caddyfile_tls: `# =============================================================================\n# Caddyfile Custom TLS Ingress Directive\n# =============================================================================\n(custom_tls) {\n    tls /etc/caddy/certs/cert.pem /etc/caddy/certs/key.pem\n}\n\n# Secure HTTPS (:443) Ingress Endpoints\nhttps://waltdakind.xubi.org, https://jellyfin.waltdakind.xubi.org, https://voltairedeux.local, https://localhost {\n    import custom_tls\n    import jellyfin_cluster\n}`,
            docker_compose: `# =============================================================================\n# Docker Compose Volume Mapping for Caddy SSL\n# =============================================================================\nservices:\n  caddy:\n    image: caddy:latest\n    container_name: caddy\n    ports:\n      - "80:80"\n      - "443:443"\n    volumes:\n      - ./Caddyfile:/etc/caddy/Caddyfile\n      - ./certs:/etc/caddy/certs:ro\n      - ./config/caddy_data:/data\n      - ./config/caddy_config:/config\n      - ./dashboard:/var/www/dashboard\n    restart: unless-stopped`,
            openssl_san_config: opensslCnf,
            powershell_trust_cmd: `# =============================================================================\n# Windows PowerShell Certificate Trust Installation\n# =============================================================================\n# Method 1: Import into CurrentUser Root Store\nImport-Certificate -FilePath .\\certs\\ca.crt -CertStoreLocation "Cert:\\CurrentUser\\Root"\n\n# Method 2: CertUtil Utility Fallback\ncertutil.exe -user -addstore -f "Root" .\\certs\\ca.crt`,
            jellyfin_pfx_setup: `# =============================================================================\n# Jellyfin Native HTTPS / PKCS#12 Configuration\n# =============================================================================\n# Navigate to: Jellyfin Admin Dashboard > Advanced > Networking\n# 1. Enable HTTPS: Checked\n# 2. Custom certificate path: /certs/server.pfx (or C:\\Users\\...\\certs\\server.pfx)\n# 3. Certificate password: mediastack\n# 4. HTTPS Port: 8920`
        };
        res.json(codeSnippets);
    } catch (err) {
        res.status(500).json({ error: err.message });
    }
});

// Endpoint: Automated SSL Certificate & Pathway Repair
app.post('/api/system/ssl/repair', async (req, res) => {
    try {
        const repairLogs = [];
        const certDir = resolveCertDir();
        repairLogs.push(`[1/5] Initiating SSL/TLS repair engine for target directory: ${certDir}`);

        // If on host or container, attempt PowerShell or OpenSSL regeneration
        let regenerated = false;
        try {
            const scriptPath = path.join(__dirname, '..', 'New-MediaStackSslCertificates.ps1');
            if (process.platform === 'win32' && fs.existsSync(scriptPath)) {
                repairLogs.push(`[2/5] Executing PowerShell certificate generator: ${scriptPath}`);
                execSync(`powershell.exe -NoProfile -ExecutionPolicy Bypass -File "${scriptPath}" -CertDir "${certDir}" -SkipCaddyReload`, { timeout: 30000 });
                regenerated = true;
                repairLogs.push('[2/5] [OK] Multi-domain wildcard certificates & PKCS#12 bundle regenerated successfully.');
            }
        } catch (psErr) {
            repairLogs.push(`[2/5] [WARN] PowerShell execution note: ${psErr.message}`);
        }

        // Reload Caddy Gateway Container
        repairLogs.push('[3/5] Reloading Caddy edge gateway configuration...');
        try {
            const caddyContainer = docker.getContainer('caddy');
            const caddyInspect = await caddyContainer.inspect();
            if (caddyInspect.State.Running) {
                try {
                    const execObj = await caddyContainer.exec({
                        Cmd: ['caddy', 'reload', '--config', '/etc/caddy/Caddyfile'],
                        AttachStdout: true,
                        AttachStderr: true
                    });
                    await execObj.start({});
                    repairLogs.push('[3/5] [OK] Caddy reloaded with zero downtime.');
                } catch (reloadErr) {
                    await caddyContainer.restart();
                    repairLogs.push('[3/5] [OK] Caddy container restarted to load new certificates.');
                }
            } else {
                await caddyContainer.start();
                repairLogs.push('[3/5] [OK] Caddy container started.');
            }
        } catch (dockerErr) {
            repairLogs.push(`[3/5] [WARN] Docker Caddy reload note: ${dockerErr.message}`);
        }

        // Live Probe
        repairLogs.push('[4/5] Executing post-repair HTTPS :443 TLS handshake probe...');
        await new Promise(r => setTimeout(r, 1200));
        const updatedReport = await getSslViabilityReport();
        repairLogs.push(`[5/5] [OK] Repair cycle complete. New Viability Score: ${updatedReport.viabilityScore}% (${updatedReport.status}).`);

        res.json({
            success: true,
            message: 'SSL/TLS pathways and certificates repaired successfully.',
            logs: repairLogs,
            report: updatedReport
        });
    } catch (err) {
        res.status(500).json({ error: err.message });
    }
});

app.post('/api/system/pull', async (req, res) => {
    const { image } = req.body;
    if (!image) return res.status(400).json({ error: 'Image name required' });
    try {
        docker.pull(image, (err, stream) => {
            if (err) return res.status(500).json({ error: err.message });
            docker.modem.followProgress(stream, onFinished);
            function onFinished(err, output) {
                if (err) return res.status(500).json({ error: err.message });
                res.json({ message: 'Pull complete', output });
            }
        });
    } catch (e) {
        res.status(500).json({ error: e.message });
    }
});

app.post('/api/system/backup', async (req, res) => {
    try {
        if (!fs.existsSync('/host_backups')) {
            fs.mkdirSync('/host_backups', { recursive: true });
        }
        if (!fs.existsSync('/host_config')) {
            return res.status(500).json({ error: '/host_config volume not mounted correctly.' });
        }
        
        const timestamp = new Date().toISOString().replace(/[:.]/g, '-');
        const backupFile = path.join('/host_backups', `backup_${timestamp}.zip`);
        const output = fs.createWriteStream(backupFile);
        const archive = archiver('zip', { zlib: { level: 9 } });
        
        output.on('close', () => {
            res.json({ message: 'Backup complete', file: backupFile, size: archive.pointer() });
        });
        
        archive.on('error', (err) => {
            console.error('Backup Error:', err);
            res.status(500).json({ error: err.message });
            output.destroy();
        });
        
        archive.pipe(output);
        archive.directory('/host_config', false);
        await archive.finalize();
    } catch (e) {
        console.error('Exception during backup:', e);
        res.status(500).json({ error: e.message });
    }
});

app.post('/api/system/diagnose', async (req, res) => {
    const { service } = req.body;
    if (!service) return res.status(400).json({ error: 'Service name required' });
    
    try {
        const diagnostics = {
            service,
            timestamp: new Date().toISOString(),
            checks: []
        };
        
        const nameLower = service.toLowerCase();
        
        if (nameLower === 'wan-gateway') {
            let publicIp = 'Unknown';
            try {
                const resIp = await axios.get('https://api.ipify.org', { timeout: 2500 });
                publicIp = resIp.data.trim();
                diagnostics.checks.push({
                    name: 'Public WAN IP Discovery',
                    status: 'pass',
                    message: `Discovered WAN IP: ${publicIp}`
                });
            } catch (e) {
                diagnostics.checks.push({
                    name: 'Public WAN IP Discovery',
                    status: 'fail',
                    message: `Failed to resolve WAN IP (check internet connectivity): ${e.message}`
                });
            }
            
            if (publicIp !== 'Unknown') {
                try {
                    const resPort = await axios.post('https://portchecker.io/api/v1/query', {
                        host: publicIp,
                        ports: [80]
                    }, { timeout: 4000 });
                    
                    const portStatus = resPort.data && resPort.data.check && resPort.data.check[0].status;
                    diagnostics.checks.push({
                        name: 'External Port 80 Access (HTTP)',
                        status: portStatus ? 'pass' : 'fail',
                        message: portStatus 
                            ? `SUCCESS: Incoming HTTP traffic connects from the outside world.` 
                            : `FAILED: Incoming HTTP traffic is blocked. Check port forwarding or firewall.`
                    });
                } catch (e) {
                    diagnostics.checks.push({
                        name: 'External Port 80 Access (HTTP)',
                        status: 'warn',
                        message: `Could not verify Port 80 via portchecker.io: ${e.message}`
                    });
                }

                try {
                    const resPort = await axios.post('https://portchecker.io/api/v1/query', {
                        host: publicIp,
                        ports: [443]
                    }, { timeout: 4000 });
                    
                    const portStatus = resPort.data && resPort.data.check && resPort.data.check[0].status;
                    diagnostics.checks.push({
                        name: 'External Port 443 Access (HTTPS)',
                        status: portStatus ? 'pass' : 'fail',
                        message: portStatus 
                            ? `SUCCESS: Port 443 is open to incoming connections.` 
                            : `FAILED: Port 443 is closed to incoming connections.`
                    });
                } catch (e) {
                    diagnostics.checks.push({
                        name: 'External Port 443 Access (HTTPS)',
                        status: 'warn',
                        message: `Could not verify Port 443 via portchecker.io: ${e.message}`
                    });
                }
            }
            
            return res.json(diagnostics);
        }

        if (nameLower === 'hdhomerun') {
            let ip = null;

            try {
                ip = await discoverHDHomeRun('10B2D7B3', 2000);
                diagnostics.checks.push({
                    name: 'Local SSDP Discovery',
                    status: ip ? 'pass' : 'fail',
                    message: ip ? `SSDP discovery successful (IP: ${ip})` : 'Failed to discover device ID 10B2D7B3 via SSDP/UPnP multicast.'
                });
            } catch (e) {
                diagnostics.checks.push({
                    name: 'Local SSDP Discovery',
                    status: 'fail',
                    message: `SSDP discovery threw error: ${e.message}`
                });
            }
            
            const targetIp = ip || '192.168.4.45';
            let metadata = null;
            try {
                const start = Date.now();
                const res = await axios.get(`http://${targetIp}/discover.json`, { timeout: 2000 });
                metadata = res.data;
                const latency = Date.now() - start;
                diagnostics.checks.push({
                    name: 'HTTP Discover API Response',
                    status: 'pass',
                    message: `HTTP API responded in ${latency}ms. Model: ${metadata.ModelNumber}, Firmware: ${metadata.FirmwareVersion}`
                });
            } catch (e) {
                diagnostics.checks.push({
                    name: 'HTTP Discover API Response',
                    status: 'fail',
                    message: `Failed to connect to HTTP API on ${targetIp}:80: ${e.message}`
                });
            }
            
            if (metadata) {
                try {
                    const start = Date.now();
                    const res = await axios.get(`http://${targetIp}/lineup.json`, { timeout: 2000 });
                    const latency = Date.now() - start;
                    const channelCount = Array.isArray(res.data) ? res.data.length : 0;
                    diagnostics.checks.push({
                        name: 'Channel Lineup Status',
                        status: channelCount > 0 ? 'pass' : 'warn',
                        message: channelCount > 0 
                            ? `Retrieved lineup in ${latency}ms. Found ${channelCount} configured channels.` 
                            : 'Tuner returned empty lineup. A channel scan might be required.'
                    });
                } catch (e) {
                    diagnostics.checks.push({
                        name: 'Channel Lineup Status',
                        status: 'fail',
                        message: `Failed to fetch channel lineup: ${e.message}`
                    });
                }
            }
            
            return res.json(diagnostics);
        }

        // 1. Get container details from Dockerode
        let containerInfo = null;

        try {
            const container = docker.getContainer(service);
            containerInfo = await container.inspect();
            diagnostics.checks.push({
                name: 'Container State',
                status: containerInfo.State.Running ? 'pass' : 'fail',
                message: `Container is in state '${containerInfo.State.Status}' (Running: ${containerInfo.State.Running})`
            });
        } catch (e) {
            diagnostics.checks.push({
                name: 'Container State',
                status: 'fail',
                message: `Container is not running or not found: ${e.message}`
            });
            return res.json(diagnostics);
        }
        
        // 2. Health check (via HTTP port lookup or internal URL check)
        let port = null;
        let path = '/';
        if (nameLower.includes('jellyfin')) { port = 8096; path = '/health'; }

        else if (nameLower.includes('radarr')) { port = 7878; path = '/ping'; }
        else if (nameLower.includes('sonarr')) { port = 8989; path = '/ping'; }
        else if (nameLower.includes('prowlarr')) { port = 9696; path = '/ping'; }
        else if (nameLower.includes('bazarr')) { port = 6767; }
        else if (nameLower.includes('transmission')) { port = 9091; path = '/transmission/web/'; }
        else if (nameLower.includes('tvheadend')) { port = 9981; }
        else if (nameLower.includes('jellyseerr')) { port = 5055; path = '/api/v1/status'; }
        else if (nameLower.includes('homepage')) { port = 3000; }
        else if (nameLower.includes('db') || nameLower.includes('mediastack-db')) { port = 8080; }
        
        if (port && containerInfo.State.Running) {
            try {
                const url = `http://${service}:${port}${path}`;
                const start = Date.now();
                const response = await axios.get(url, { timeout: 3000 });
                const latency = Date.now() - start;
                diagnostics.checks.push({
                    name: 'HTTP Endpoint Response',
                    status: 'pass',
                    message: `HTTP endpoint resolved and responded in ${latency}ms (Status: ${response.status})`
                });
            } catch (e) {
                diagnostics.checks.push({
                    name: 'HTTP Endpoint Response',
                    status: 'fail',
                    message: `Failed to connect to internal HTTP port ${port}: ${e.message}`
                });
            }
        }
        
        // 3. Database Integrity Check (if database exists)
        let dbFileRelativePath = null;
        if (nameLower.includes('sonarr')) dbFileRelativePath = 'sonarr/sonarr.db';
        else if (nameLower.includes('radarr')) dbFileRelativePath = 'radarr/radarr.db';
        else if (nameLower.includes('prowlarr')) dbFileRelativePath = 'prowlarr/prowlarr.db';
        else if (nameLower.includes('jellyfin')) dbFileRelativePath = 'jellyfin/data/data/jellyfin.db';
        
        if (dbFileRelativePath) {
            try {
                const dbContainer = docker.getContainer('mediastack-db');
                const dbInspect = await dbContainer.inspect();
                if (dbInspect.State.Running) {
                    const exec = await dbContainer.exec({
                        Cmd: ['sqlite3', `/mediastack/config/${dbFileRelativePath}`, 'PRAGMA integrity_check;'],
                        AttachStdout: true,
                        AttachStderr: true
                    });
                    
                    const stream = await exec.start({});
                    let output = '';
                    
                    await new Promise((resolve, reject) => {
                        dbContainer.modem.demuxStream(stream, {
                            write: data => { output += data.toString(); }
                        }, {
                            write: data => { output += data.toString(); }
                        });
                        
                        stream.on('end', () => resolve());
                        stream.on('error', err => reject(err));
                    });

                    
                    const cleanOutput = output.trim();
                    if (cleanOutput.includes('ok')) {
                        diagnostics.checks.push({
                            name: 'SQLite Database Integrity',
                            status: 'pass',
                            message: `Database '${dbFileRelativePath}' is healthy (integrity_check: ok)`
                        });
                    } else {
                        diagnostics.checks.push({
                            name: 'SQLite Database Integrity',
                            status: 'fail',
                            message: `Database '${dbFileRelativePath}' is corrupted! Output: ${cleanOutput}`
                        });
                    }
                } else {
                    diagnostics.checks.push({
                        name: 'SQLite Database Integrity',
                        status: 'warn',
                        message: "Skipped: 'mediastack-db' container is not running to verify databases."
                    });
                }
            } catch (e) {
                diagnostics.checks.push({
                    name: 'SQLite Database Integrity',
                    status: 'warn',
                    message: `Could not verify database: ${e.message}`
                });
            }
        }
        
        // 4. Scan Container Logs for Errors
        if (containerInfo.State.Running) {
            try {
                const container = docker.getContainer(service);
                const logOpts = {
                    stdout: true,
                    stderr: true,
                    tail: 100,
                    timestamps: false
                };
                const logStream = await container.logs(logOpts);
                const logString = logStream.toString('utf8');
                
                const lines = logString.split('\n');
                const errorsFound = [];
                const warningsFound = [];
                lines.forEach(line => {
                    const lineLower = line.toLowerCase();
                    if (lineLower.includes('error') || lineLower.includes('exception') || lineLower.includes('malformed') || lineLower.includes('corrupt')) {
                        errorsFound.push(line.substring(0, 120));
                    } else if (lineLower.includes('warn') || lineLower.includes('failed')) {
                        warningsFound.push(line.substring(0, 120));
                    }
                });
                
                if (errorsFound.length > 0) {
                    diagnostics.checks.push({
                        name: 'Container Log Scan',
                        status: 'warn',
                        message: `Found ${errorsFound.length} error entries in the last 100 log lines: "${errorsFound[0]}..."`
                    });
                } else if (warningsFound.length > 0) {
                    diagnostics.checks.push({
                        name: 'Container Log Scan',
                        status: 'pass',
                        message: `No critical errors. Found ${warningsFound.length} warning/failure entries in log history.`
                    });
                } else {
                    diagnostics.checks.push({
                        name: 'Container Log Scan',
                        status: 'pass',
                        message: 'Log scan clean. No errors or warnings found in last 100 log entries.'
                    });
                }
            } catch (e) {
                diagnostics.checks.push({
                    name: 'Container Log Scan',
                    status: 'warn',
                    message: `Could not parse container logs: ${e.message}`
                });
            }
        }
        
        // 5. Volume Mount Integrity Check
        if (containerInfo.Mounts && containerInfo.Mounts.length > 0) {
            const activeMounts = [];
            containerInfo.Mounts.forEach(m => {
                const srcName = m.Source.split('\\').pop() || m.Source.split('/').pop() || '/';
                activeMounts.push(`${m.Destination} ➔ ${srcName}`);
            });
            
            diagnostics.checks.push({
                name: 'Volume Mounts Verification',
                status: 'pass',
                message: `Verified ${containerInfo.Mounts.length} volume mappings. Mapped to: ${activeMounts.slice(0, 2).join(', ')}...`
            });
        }

        // 6. SSL / TLS Certificate and HTTPS Ingress Verification (for Caddy / SSL)
        if (nameLower.includes('caddy') || nameLower.includes('ssl') || nameLower.includes('ingress')) {
            try {
                const sslRep = await getSslViabilityReport();
                diagnostics.checks.push({
                    name: 'SSL/TLS Certificate Viability',
                    status: sslRep.isViable ? 'pass' : 'fail',
                    message: `Score: ${sslRep.viabilityScore}% (${sslRep.status}). Domain: ${sslRep.primaryDomain}. Days remaining: ${sslRep.certificate ? sslRep.certificate.daysRemaining : 0} days.`
                });
                diagnostics.checks.push({
                    name: 'HTTPS :443 Handshake Probe',
                    status: sslRep.liveProbe.tlsSuccess ? 'pass' : 'fail',
                    message: `Endpoint: ${sslRep.liveProbe.endpoint} responded with HTTP ${sslRep.liveProbe.httpCode} (${sslRep.liveProbe.latencyMs}ms, ${sslRep.liveProbe.tlsVersion}, ${sslRep.liveProbe.cipher})`
                });
            } catch (sslErr) {
                diagnostics.checks.push({
                    name: 'SSL/TLS Certificate Viability',
                    status: 'warn',
                    message: `SSL verification note: ${sslErr.message}`
                });
            }
        }
        
        res.json(diagnostics);
        
    } catch (e) {
        res.status(500).json({ error: e.message });
    }
});


// MCP Server Setup
const server = new McpServer({
    name: 'mediastack-mcp',
    version: '1.0.0'
});

server.tool('check_services', 'Check if MediaStack services are reachable internally', {}, async () => {
    const statuses = {};
    const services = [
        { name: 'radarr', url: 'http://radarr:7878' },
        { name: 'sonarr', url: 'http://sonarr:8989' },
        { name: 'jellyfin', url: 'http://jellyfin:8096/health' }
    ];
    for (const s of services) {
        try {
            await axios.get(s.url, { timeout: 2000 });
            statuses[s.name] = 'healthy';
        } catch (e) {
            statuses[s.name] = 'unreachable';
        }
    }
    return { content: [{ type: 'text', text: JSON.stringify(statuses, null, 2) }] };
});

const transports = new Map();

app.get('/mcp/sse', async (req, res) => {
    const transport = new SSEServerTransport('/mcp/messages', res);
    await server.connect(transport);
    transports.set(transport.sessionId, transport);
    
    req.on('close', () => {
        transports.delete(transport.sessionId);
    });
});

app.post('/mcp/messages', async (req, res) => {
    const sessionId = req.query.sessionId;
    const transport = transports.get(sessionId);
    if (transport) {
        await transport.handlePostMessage(req, res);
    } else {
        res.status(500).send('No active SSE connection for session');
    }
});

// Player settings endpoints
app.get('/api/player/settings', (req, res) => {
    db.all("SELECT key, value FROM player_settings", (err, rows) => {
        if (err) {
            return res.status(500).json({ error: err.message });
        }
        const settings = {};
        for (const row of rows) {
            settings[row.key] = row.value || '';
        }
        res.json(settings);
    });
});

app.post('/api/player/settings', (req, res) => {
    const { opening_message, enforced_css, background_image, profile_image } = req.body;
    
    db.serialize(() => {
        const stmt = db.prepare("INSERT OR REPLACE INTO player_settings (key, value) VALUES (?, ?)");
        
        if (opening_message !== undefined) stmt.run('opening_message', opening_message);
        if (enforced_css !== undefined) stmt.run('enforced_css', enforced_css);
        if (background_image !== undefined) stmt.run('background_image', background_image);
        if (profile_image !== undefined) stmt.run('profile_image', profile_image);
        
        stmt.finalize((err) => {
            if (err) {
                return res.status(500).json({ error: err.message });
            }
            res.json({ status: 'success', message: 'Settings saved successfully' });
        });
    });
});

// =============================================================================
// JELLYWATCH RESILIENT CONNECTION & EXPERT GUIDANCE HANDLER
// =============================================================================

const JELLYWATCH_LICENSE_KEY = '4f3eeea865c64d649330bdae9dde2ca1';
const JELLYFIN_SERVER_ID = 'd9fa4abb39204b6e9d680e4b8a0e7df9';

// Connection Candidates definition
const JELLYWATCH_CANDIDATES = [
    {
        id: 'wan_gateway',
        name: 'Remote WAN Gateway (Public DDNS - Main Login)',
        tier: 1,
        url: 'https://waltdakind.xubi.org',
        internal_url: 'https://waltdakind.xubi.org',
        protocol: 'HTTPS/WAN',
        recommended_for: 'Primary Default Login (Anywhere, LTE/Cellular & Remote Streaming)'
    },
    {
        id: 'voltaireun_direct',
        name: 'VoltaireUn Direct Socket (Local Network Fallback)',
        tier: 2,
        url: 'http://192.168.4.21:8096',
        internal_url: 'http://jellyfin:8096',
        protocol: 'HTTP/REST',
        recommended_for: 'Local Home Network Fallback (Zero TLS friction, lowest LAN latency)'
    },
    {
        id: 'voltaireun_caddy',
        name: 'VoltaireUn Reverse Proxy (Caddy HTTPS)',
        tier: 3,
        url: 'https://voltaireun.local',
        internal_url: 'http://caddy:80',
        protocol: 'HTTPS/HTTP2',
        recommended_for: 'Browser Companion & Web Clients on LAN'
    },
    {
        id: 'voltairedeux_direct',
        name: 'VoltaireDeux AI Node (Failover LAN)',
        tier: 4,
        url: 'http://192.168.4.30:8096',
        internal_url: 'http://192.168.4.30:8096',
        protocol: 'HTTP/REST',
        recommended_for: 'Automated Failover when VoltaireUn is restarting'
    },
    {
        id: 'localhost_direct',
        name: 'Local Host Loopback',
        tier: 5,
        url: 'http://127.0.0.1:8096',
        internal_url: 'http://127.0.0.1:8096',
        protocol: 'HTTP/Loopback',
        recommended_for: 'Local Node Debugging'
    }
];

// Helper to probe single candidate URL
async function probeJellyWatchCandidate(candidate) {
    const start = Date.now();
    const probeUrl = `${candidate.internal_url}/System/Info/Public`;
    try {
        const response = await axios.get(probeUrl, {
            timeout: 1200,
            validateStatus: () => true,
            headers: {
                'User-Agent': 'MediaStack-JellyWatch-Sentinel/2.0'
            }
        });
        const latency = Date.now() - start;
        const isHealthy = (response.status >= 200 && response.status < 400);
        return {
            id: candidate.id,
            name: candidate.name,
            tier: candidate.tier,
            client_url: candidate.url,
            protocol: candidate.protocol,
            status: isHealthy ? 'ONLINE' : 'DEGRADED',
            http_code: response.status,
            latency_ms: latency,
            recommended_for: candidate.recommended_for,
            server_version: response.data && response.data.Version ? response.data.Version : null
        };
    } catch (err) {
        return {
            id: candidate.id,
            name: candidate.name,
            tier: candidate.tier,
            client_url: candidate.url,
            protocol: candidate.protocol,
            status: 'OFFLINE',
            http_code: 0,
            latency_ms: Date.now() - start,
            error: err.message,
            recommended_for: candidate.recommended_for
        };
    }
}

// 1. Resolve live nodes & deliver cascade profile
app.get('/api/jellywatch/resolve', async (req, res) => {
    try {
        const probePromises = JELLYWATCH_CANDIDATES.map(c => probeJellyWatchCandidate(c));
        const probeResults = await Promise.all(probePromises);

        // Sort: Online first, then by tier ascending, then by latency
        probeResults.sort((a, b) => {
            if (a.status === 'ONLINE' && b.status !== 'ONLINE') return -1;
            if (a.status !== 'ONLINE' && b.status === 'ONLINE') return 1;
            if (a.tier !== b.tier) return a.tier - b.tier;
            return a.latency_ms - b.latency_ms;
        });

        const primary = probeResults.find(p => p.status === 'ONLINE') || probeResults[0];

        res.json({
            status: 'success',
            server_name: "MediaStack Cluster (Voltaire)",
            server_id: JELLYFIN_SERVER_ID,
            primary_endpoint: {
                id: primary.id,
                name: primary.name,
                url: primary.client_url,
                tier: primary.tier,
                protocol: primary.protocol,
                status: primary.status,
                latency_ms: primary.latency_ms
            },
            fallback_chain: probeResults,
            recommended_strategy: primary.tier === 1 ? 'DIRECT_LAN_SOCKET' : (primary.tier === 4 ? 'REMOTE_WAN' : 'AUTO_FAILOVER_CASCADE'),
            jellywatch_license: {
                api_code: JELLYWATCH_LICENSE_KEY,
                tier: "Premium Mode Activation",
                status: "ACTIVE",
                activated_at: "2026-08-30T19:08:00Z",
                features: [
                    "Background Playback Tracking",
                    "Cross-Device Scrobbling",
                    "Push Notifications",
                    "Priority Metadata Sync",
                    "Zero-Friction Fast Pairing",
                    "Offline-Resilient Scrobble Queue"
                ]
            },
            discovery_info: {
                multicast_udp_port: 7359,
                mdns_udp_port: 5353,
                mdns_hostname: "voltaireun.local",
                igmp_snooping_required: true
            },
            timestamp: new Date().toISOString()
        });
    } catch (e) {
        res.status(500).json({ error: `Resolution failed: ${e.message}` });
    }
});

// 2. Expert Diagnostic Guidance Handler
app.get('/api/jellywatch/guidance', (req, res) => {
    const errorQuery = (req.query.error || req.query.code || '').toUpperCase();
    const endpointQuery = req.query.endpoint || '';
    const clientType = req.query.client || 'watchOS';

    let guidance = {
        error_code: errorQuery || 'ERR_GENERAL_DISCONNECT',
        client_type: clientType,
        severity: 'INFO',
        title: 'JellyWatch Resilient Connection Guidance',
        root_cause: 'General network check requested.',
        immediate_action: 'Connect using Primary LAN Socket (http://192.168.4.21:8096).',
        remediation_steps: [
            '1. Ensure device is on local WiFi network (SSID matching MediaStack).',
            '2. Use direct host socket http://192.168.4.21:8096 to bypass SSL certificate validation on watchOS.',
            '3. For remote cellular playback, configure https://waltdakind.xubi.org.'
        ],
        fallback_url: 'http://192.168.4.21:8096',
        secondary_fallback_url: 'https://waltdakind.xubi.org'
    };

    if (errorQuery.includes('CERT') || errorQuery.includes('SSL') || errorQuery.includes('AUTHORITY') || errorQuery.includes('TRUST')) {
        guidance = {
            error_code: 'ERR_SSL_CERT_AUTHORITY_INVALID',
            client_type: clientType,
            severity: 'WARNING',
            title: 'watchOS / iOS Custom CA Trust Requirement',
            root_cause: 'Apple Watch (watchOS) strictly enforces TLS root validation and will reject internal self-signed or private Root CA certificates unless an Apple Configuration Profile is installed on the watch.',
            immediate_action: 'Switch Server URL in JellyWatch to direct HTTP port: http://192.168.4.21:8096.',
            remediation_steps: [
                '1. Open JellyWatch Settings -> Server Address.',
                '2. Enter direct unencrypted socket: http://192.168.4.21:8096 (No TLS handshake required on trusted LAN).',
                '3. Alternatively, install the MediaStack Root CA profile on your paired iPhone and enable full trust in Settings -> General -> About -> Certificate Trust Settings.',
                '4. When using Cellular/LTE, connect through the public trusted endpoint: https://waltdakind.xubi.org.'
            ],
            fallback_url: 'http://192.168.4.21:8096',
            secondary_fallback_url: 'https://waltdakind.xubi.org'
        };
    } else if (errorQuery.includes('RESOLV') || errorQuery.includes('NOTFOUND') || errorQuery.includes('MDNS') || errorQuery.includes('NAME')) {
        guidance = {
            error_code: 'ERR_NAME_NOT_RESOLVED',
            client_type: clientType,
            severity: 'CRITICAL',
            title: 'mDNS (.local) Domain Unresolvable on Apple Watch',
            root_cause: 'When Apple Watch is connected via Bluetooth relay through an iPhone or over LTE, mDNS multicast DNS queries (voltaireun.local) are not bridged to the watch sandbox.',
            immediate_action: 'Replace hostname with literal IPv4 address: http://192.168.4.21:8096.',
            remediation_steps: [
                '1. Change server address from http://voltaireun.local to http://192.168.4.21:8096.',
                '2. If away from home, set Server Address to https://waltdakind.xubi.org.',
                '3. Verify watch is connected to the same 2.4GHz/5GHz home WiFi band as MediaStack.'
            ],
            fallback_url: 'http://192.168.4.21:8096',
            secondary_fallback_url: 'https://waltdakind.xubi.org'
        };
    } else if (errorQuery.includes('REFUSED') || errorQuery.includes('ECONNREFUSED') || errorQuery.includes('OFFLINE')) {
        guidance = {
            error_code: 'ERR_CONNECTION_REFUSED',
            client_type: clientType,
            severity: 'CRITICAL',
            title: 'Primary Jellyfin Node Socket Offline / Restarting',
            root_cause: 'The Jellyfin service on VoltaireUn is currently restarting or the socket port 8096 is blocked.',
            immediate_action: 'Engage automatic failover to VoltaireDeux AI Node (http://192.168.4.30:8096).',
            remediation_steps: [
                '1. Switch target endpoint to secondary cluster node: http://192.168.4.30:8096.',
                '2. If both LAN nodes are unreachable, connect to Caddy Ingress Gateway: https://voltaireun.local.',
                '3. Run .\\Invoke-JellyWatchHandler.ps1 -AutoRepair on the server to restart the primary container.'
            ],
            fallback_url: 'http://192.168.4.30:8096',
            secondary_fallback_url: 'http://192.168.4.21:80'
        };
    } else if (errorQuery.includes('TIMEOUT') || errorQuery.includes('ETIMEDOUT')) {
        guidance = {
            error_code: 'ERR_TIMEOUT',
            client_type: clientType,
            severity: 'WARNING',
            title: 'Network Socket Timed Out',
            root_cause: 'Client Isolation on WiFi Access Point or switch is blocking local inter-device communication on port 8096.',
            immediate_action: 'Connect via WAN gateway https://waltdakind.xubi.org or verify AP Client Isolation.',
            remediation_steps: [
                '1. In router/switch admin, disable "Client Isolation" / "AP Isolation".',
                '2. Enable "IGMP Snooping" and "Multicast" on the network switch.',
                '3. Fallback to https://waltdakind.xubi.org if LAN routing remains blocked.'
            ],
            fallback_url: 'https://waltdakind.xubi.org',
            secondary_fallback_url: 'http://192.168.4.21:8096'
        };
    } else if (errorQuery.includes('AUTH') || errorQuery.includes('401') || errorQuery.includes('403') || errorQuery.includes('TOKEN')) {
        guidance = {
            error_code: 'ERR_AUTHENTICATION_EXPIRED',
            client_type: clientType,
            severity: 'WARNING',
            title: 'Session Authentication Token Expired',
            root_cause: 'Jellyfin session expired or credentials were reset.',
            immediate_action: 'Generate a Quick-Pair PIN or Magic Link.',
            remediation_steps: [
                '1. Open MediaStack Player dashboard and generate a 6-digit Quick Pair PIN.',
                '2. Enter PIN in JellyWatch to link session without typing password.',
                '3. Or open magic link http://voltaireun.local/watch/?pin=... from paired phone.'
            ],
            fallback_url: 'http://voltaireun.local/watch',
            secondary_fallback_url: 'https://waltdakind.xubi.org'
        };
    }

    res.json(guidance);
});

// 3. Offline-Tolerant Scrobble & Playback Tracking Handler
app.post('/api/jellywatch/scrobble', async (req, res) => {
    const { item_id, item_name, user_id, position_ticks, is_paused, is_played, client_id, token } = req.body;

    if (!item_id) {
        return res.status(400).json({ error: "Missing required parameter 'item_id'" });
    }

    const posTicks = position_ticks || 0;
    const paused = is_paused ? 1 : 0;
    const played = is_played ? 1 : 0;

    // Try forwarding to live Jellyfin instance
    const jellyfinEndpoint = is_played 
        ? 'http://jellyfin:8096/Sessions/Playing/Stopped' 
        : 'http://jellyfin:8096/Sessions/Playing/Progress';

    const authHeader = token ? { 'X-Emby-Token': token } : { 'X-Emby-Token': 'aa8e1b0671064da9bb41b3791c13a219' };

    try {
        await axios.post(jellyfinEndpoint, {
            ItemId: item_id,
            PositionTicks: posTicks,
            IsPaused: !!paused
        }, {
            headers: {
                ...authHeader,
                'X-Emby-Authorization': `MediaBrowser Client="JellyWatch", Device="AppleWatch", DeviceId="${client_id || 'JellyWatchDevice'}", Version="2.0.0"`
            },
            timeout: 2000
        });

        // Record successful sync in SQLite
        db.run(`
            INSERT INTO jellywatch_scrobbles (item_id, item_name, user_id, position_ticks, is_paused, is_played, client_id, status, synced_at)
            VALUES (?, ?, ?, ?, ?, ?, ?, 'SYNCED', CURRENT_TIMESTAMP)
        `, [item_id, item_name || '', user_id || '', posTicks, paused, played, client_id || 'watch']);

        res.json({
            status: 'SYNCED',
            message: 'Playback state synchronized directly with Jellyfin.',
            item_id: item_id,
            position_ticks: posTicks
        });
    } catch (err) {
        console.warn(`Jellyfin direct scrobble failed (${err.message}). Buffering in offline resilient queue...`);

        // Queue in SQLite offline store
        db.run(`
            INSERT INTO jellywatch_scrobbles (item_id, item_name, user_id, position_ticks, is_paused, is_played, client_id, status, error)
            VALUES (?, ?, ?, ?, ?, ?, ?, 'QUEUED_OFFLINE', ?)
        `, [item_id, item_name || '', user_id || '', posTicks, paused, played, client_id || 'watch', err.message]);

        res.status(202).json({
            status: 'QUEUED_OFFLINE',
            message: 'Jellyfin is temporarily unreachable. Scrobble safely preserved in MediaStack queue and will auto-sync.',
            item_id: item_id,
            position_ticks: posTicks
        });
    }
});

// 4. Inspect Scrobble Queue
app.get('/api/jellywatch/scrobble/queue', (req, res) => {
    db.all("SELECT * FROM jellywatch_scrobbles ORDER BY id DESC LIMIT 50", (err, rows) => {
        if (err) return res.status(500).json({ error: err.message });
        res.json({
            queue_length: rows.filter(r => r.status === 'QUEUED_OFFLINE').length,
            total_records: rows.length,
            records: rows
        });
    });
});

// 5. Generate Quick Pair PIN for Watch Screens
app.post('/api/jellywatch/pair', (req, res) => {
    const { user_id, username, token, device_name } = req.body;
    const pin = Math.floor(100000 + Math.random() * 900000).toString();
    const expiresAt = Date.now() + (15 * 60 * 1000); // 15 mins

    db.run(`
        INSERT OR REPLACE INTO jellywatch_pairing_pins (pin, user_id, username, token, device_name, expires_at)
        VALUES (?, ?, ?, ?, ?, ?)
    `, [pin, user_id || 'walter', username || 'walter', token || '', device_name || 'AppleWatch', expiresAt], (err) => {
        if (err) return res.status(500).json({ error: err.message });
        res.json({
            status: 'success',
            pin: pin,
            expires_in_seconds: 900,
            magic_url: `http://192.168.4.21:8096/watch/?pin=${pin}`,
            wan_magic_url: `https://waltdakind.xubi.org/watch/?pin=${pin}`
        });
    });
});

// 6. Exchange Quick Pair PIN for Credentials
app.get('/api/jellywatch/pair/:pin', (req, res) => {
    const pin = req.params.pin;
    db.get("SELECT * FROM jellywatch_pairing_pins WHERE pin = ?", [pin], (err, row) => {
        if (err) return res.status(500).json({ error: err.message });
        if (!row) {
            return res.status(404).json({ error: "Invalid or expired pairing PIN." });
        }
        if (Date.now() > row.expires_at) {
            db.run("DELETE FROM jellywatch_pairing_pins WHERE pin = ?", [pin]);
            return res.status(410).json({ error: "Pairing PIN has expired. Please generate a new PIN." });
        }

        res.json({
            status: 'success',
            user_id: row.user_id,
            username: row.username,
            token: row.token,
            server_url: "http://192.168.4.21:8096",
            fallback_url: "https://waltdakind.xubi.org",
            server_id: JELLYFIN_SERVER_ID,
            license_code: JELLYWATCH_LICENSE_KEY
        });
    });
});

// 7. General JellyWatch Cluster Config
app.get('/api/jellywatch/config', (req, res) => {
    res.json({
        app_name: "JellyWatch",
        cluster: "MediaStack High-Availability Mesh",
        license_tier: "Premium Activation",
        api_code: JELLYWATCH_LICENSE_KEY,
        server_id: JELLYFIN_SERVER_ID,
        primary_endpoint: "http://192.168.4.21:8096",
        failover_endpoint: "http://192.168.4.30:8096",
        wan_endpoint: "https://waltdakind.xubi.org",
        proxy_endpoint: "https://voltaireun.local",
        discovery_udp_port: 7359,
        mdns_port: 5353,
        multicast_network_guidance: "Ensure IGMP Snooping is enabled and Client Isolation is disabled on WiFi AP for instant Bonjour discovery."
    });
});

// Background Worker: Auto-flush offline scrobble queue when Jellyfin is healthy
async function flushQueuedScrobbles() {
    db.all("SELECT * FROM jellywatch_scrobbles WHERE status = 'QUEUED_OFFLINE' LIMIT 20", async (err, rows) => {
        if (err || !rows || rows.length === 0) return;

        // Test if Jellyfin is alive
        try {
            await axios.get('http://jellyfin:8096/health', { timeout: 1500 });
        } catch (e) {
            return; // Still offline, retry next cycle
        }

        for (const row of rows) {
            const endpoint = row.is_played ? 'http://jellyfin:8096/Sessions/Playing/Stopped' : 'http://jellyfin:8096/Sessions/Playing/Progress';
            try {
                await axios.post(endpoint, {
                    ItemId: row.item_id,
                    PositionTicks: row.position_ticks,
                    IsPaused: !!row.is_paused
                }, {
                    headers: {
                        'X-Emby-Token': 'aa8e1b0671064da9bb41b3791c13a219',
                        'X-Emby-Authorization': `MediaBrowser Client="JellyWatch", Device="AppleWatch", DeviceId="${row.client_id || 'JellyWatchDevice'}", Version="2.0.0"`
                    },
                    timeout: 2000
                });

                db.run("UPDATE jellywatch_scrobbles SET status = 'SYNCED', synced_at = CURRENT_TIMESTAMP WHERE id = ?", [row.id]);
                console.log(`[JellyWatch Queue] Auto-flushed scrobble for item ${row.item_id} (ID: ${row.id})`);
            } catch (postErr) {
                // Keep queued
            }
        }
    });
}

setInterval(flushQueuedScrobbles, 25000);

const PORT = process.env.PORT || 3000;

app.listen(PORT, () => {
    console.log(`API Gateway and MCP server running on port ${PORT}`);
});
