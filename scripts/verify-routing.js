const net = require('net');
const exec = require('child_process').exec;
const axios = require('c:/Users/waltd/OneDrive/Mediastack/api-gateway/node_modules/axios');

function testTcpPort(host, port, timeout = 1000) {
    return new Promise((resolve) => {
        const socket = new net.Socket();
        let status = 'closed';
        
        socket.setTimeout(timeout);
        
        socket.connect(port, host, () => {
            status = 'open';
            socket.destroy();
        });
        
        socket.on('error', () => {
            status = 'closed';
        });
        
        socket.on('timeout', () => {
            status = 'closed';
            socket.destroy();
        });
        
        socket.on('close', () => {
            resolve(status);
        });
    });
}

function runCmd(cmd) {
    return new Promise((resolve) => {
        exec(cmd, (error, stdout, stderr) => {
            resolve({ error, stdout, stderr });
        });
    });
}

async function startTests() {
    console.log('====================================================');
    console.log('         MEDIASTACK ROUTING VERIFICATION            ');
    console.log('====================================================\n');

    // 1. Check Running Docker Containers
    console.log('[1/3] Checking Docker Container Fleet status...');
    const dockerRes = await runCmd('docker ps --format "{{.Names}}: {{.Status}}"');
    const containers = dockerRes.stdout.split('\n');
    const required = [
        'caddy', 'api-gateway', 'jellyfin', 'radarr', 'sonarr', 
        'prowlarr', 'bazarr', 'tvheadend', 'transmission', 
        'jellyseerr', 'mediastack-db'
    ];

    for (const service of required) {
        const line = containers.find(c => c.startsWith(service + ':'));
        if (line) {
            console.log(`  ✔  ${service.padEnd(15)} : ONLINE (${line.split(': ')[1].trim()})`);
        } else {
            console.log(`  ✖  ${service.padEnd(15)} : OFFLINE`);
        }
    }
    console.log('');

    // 2. Check Host Port Exposures
    console.log('[2/3] Verifying host TCP port bindings (direct IP:port routing)...');
    const ports = {
        80: 'Caddy HTTP (Dashboard)',
        443: 'Caddy HTTPS (Dashboard)',
        3000: 'API Gateway and MCP',
        8096: 'Jellyfin Server',
        7878: 'Radarr Movie Manager',
        8989: 'Sonarr TV Manager',
        9696: 'Prowlarr Indexer',
        6767: 'Bazarr Subtitle Manager',
        5055: 'Jellyseerr Requests',
        9091: 'Transmission Web UI',
        9981: 'TVHeadend Web UI',
        9982: 'TVHeadend Stream Server'
    };

    for (const port of Object.keys(ports).map(Number).sort((a,b)=>a-b)) {
        const res = await testTcpPort('127.0.0.1', port);
        if (res === 'open') {
            console.log(`  ✔  Port ${port.toString().padEnd(5)} : OPEN (${ports[port]})`);
        } else {
            console.log(`  ✖  Port ${port.toString().padEnd(5)} : CLOSED/BLOCKED (${ports[port]})`);
        }
    }
    console.log('');

    // 3. Verify API Gateway RBAC Rules
    console.log('[3/3] Testing API Gateway Role-Based Access Control (RBAC)...');
    const apiBase = 'http://localhost:3000/api';

    // Test 3a: Read request as user 'moop'
    try {
        const resMoopGet = await axios.get(`${apiBase}/player/settings`, {
            headers: { 'X-Username': 'moop' },
            timeout: 2000
        });
        if (resMoopGet.status === 200) {
            console.log('  ✔  Test 3a : PASS (User "moop" can READ player settings)');
        } else {
            console.log(`  ✖  Test 3a : FAIL (User "moop" READ failed: ${resMoopGet.status})`);
        }
    } catch (e) {
        console.log(`  ✖  Test 3a : FAIL (User "moop" READ error: ${e.message})`);
    }

    // Test 3b: Write request as user 'moop' (Should fail with 403)
    try {
        await axios.post(`${apiBase}/player/settings`, 
            { opening_message: 'hack' }, 
            { headers: { 'X-Username': 'moop' }, timeout: 2000 }
        );
        console.log('  ✖  Test 3b : FAIL (User "moop" was allowed to WRITE settings)');
    } catch (e) {
        if (e.response && e.response.status === 403) {
            console.log('  ✔  Test 3b : PASS (User "moop" was BLOCKED from WRITE settings: 403 Forbidden)');
        } else {
            console.log(`  ✖  Test 3b : FAIL (User "moop" WRITE block failed: Expected 403, got ${e.response ? e.response.status : e.message})`);
        }
    }

    // Test 3c: Write request as user 'walter' (Should succeed)
    try {
        const resWalterPost = await axios.post(`${apiBase}/player/settings`, 
            { opening_message: 'Welcome_back_walter' }, 
            { headers: { 'X-Username': 'walter' }, timeout: 2000 }
        );
        if (resWalterPost.status === 200) {
            console.log('  ✔  Test 3c : PASS (User "walter" can WRITE player settings: 200 OK)');
        } else {
            console.log(`  ✖  Test 3c : FAIL (User "walter" WRITE failed: status ${resWalterPost.status})`);
        }
    } catch (e) {
        console.log(`  ✖  Test 3c : FAIL (User "walter" WRITE failed: ${e.message})`);
    }

    console.log('\n====================================================');
    console.log('             VERIFICATION RUN COMPLETE              ');
    console.log('====================================================');
}

startTests();
