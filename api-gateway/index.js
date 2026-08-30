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
    // 1. Identify User
    let username = req.headers['x-username'] || req.headers['x-mediastack-user'];
    
    const token = req.headers['x-emby-token'] || req.query.api_key;
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

const PORT = process.env.PORT || 3000;

app.listen(PORT, () => {
    console.log(`API Gateway and MCP server running on port ${PORT}`);
});
