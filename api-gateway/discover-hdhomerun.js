const dgram = require('dgram');
const axios = require('axios');

function discoverHDHomeRun(targetDeviceId = '10B2D7B3', timeoutMs = 3000) {
    return new Promise((resolve, reject) => {
        const client = dgram.createSocket('udp4');
        const discoveredIps = new Set();
        let foundIp = null;
        
        const msearch = 
            "M-SEARCH * HTTP/1.1\r\n" +
            "HOST: 239.255.255.250:1900\r\n" +
            "MAN: \"ssdp:discover\"\r\n" +
            "MX: 2\r\n" +
            "ST: upnp:rootdevice\r\n\r\n";
            
        const message = Buffer.from(msearch);
        
        client.on('error', (err) => {
            client.close();
            reject(err);
        });
        
        client.on('message', async (msg, rinfo) => {
            const ip = rinfo.address;
            if (discoveredIps.has(ip)) return;
            discoveredIps.add(ip);
            
            try {
                // Fetch discover.json from the responding IP
                const res = await axios.get(`http://${ip}/discover.json`, { timeout: 1000 });
                if (res.data && res.data.DeviceID === targetDeviceId) {
                    foundIp = ip;
                    client.close();
                    resolve(ip);
                }
            } catch (e) {
                // Ignore failures from non-HDHomeRun or offline UPnP devices
            }
        });
        
        // Bind and send SSDP M-SEARCH
        client.bind(() => {
            client.setBroadcast(true);
            client.send(message, 0, message.length, 1900, '239.255.255.250', (err) => {
                if (err) {
                    client.close();
                    reject(err);
                }
            });
        });
        
        // Setup timeout
        setTimeout(() => {
            if (!foundIp) {
                client.close();
                resolve(null); // Resolve with null if not found within timeout
            }
        }, timeoutMs);
    });
}

// If run directly
if (require.main === module) {
    const target = process.argv[2] || '10B2D7B3';
    console.log(`Starting local discovery for HDHomeRun Device ID: ${target}...`);
    discoverHDHomeRun(target)
        .then(ip => {
            if (ip) {
                console.log(`SUCCESS: Found HDHomeRun IP: ${ip}`);
                process.exit(0);
            } else {
                console.log(`FAILED: Device ID ${target} was not found on the local network.`);
                process.exit(1);
            }
        })
        .catch(err => {
            console.error('Discovery error:', err);
            process.exit(1);
        });
}

module.exports = discoverHDHomeRun;
