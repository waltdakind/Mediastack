const SONARR_URL = 'http://localhost:8989';
const SONARR_KEY = '38c67d03fd45409f9888cf8a5e7f0bac';

const RADARR_URL = 'http://localhost:7878';
const RADARR_KEY = 'a5e014872ce84a558391afb466d1f95e';

async function configureSonarr() {
    console.log('\n--- Configuring Sonarr ---');
    try {
        const rootRes = await fetch(`${SONARR_URL}/api/v3/rootfolder`, {
            headers: { 'X-Api-Key': SONARR_KEY }
        });
        const rootData = await rootRes.json();
        const existingPaths = (Array.isArray(rootData) ? rootData : []).map(r => r.path);
        console.log('Existing Sonarr root folders:', existingPaths);

        for (const p of ['/data/Shows', '/data/TV']) {
            if (!existingPaths.includes(p)) {
                try {
                    const addRes = await fetch(`${SONARR_URL}/api/v3/rootfolder`, {
                        method: 'POST',
                        headers: { 'Content-Type': 'application/json', 'X-Api-Key': SONARR_KEY },
                        body: JSON.stringify({ path: p })
                    });
                    const addData = await addRes.json();
                    console.log(`Added Sonarr root folder: ${p}`, addData.id ? `(ID: ${addData.id})` : addData);
                } catch (e) {
                    console.log(`Note on Sonarr root folder ${p}:`, e.message);
                }
            }
        }

        // Add Transmission download client to Sonarr
        try {
            const dlRes = await fetch(`${SONARR_URL}/api/v3/downloadclient`, {
                method: 'POST',
                headers: { 'Content-Type': 'application/json', 'X-Api-Key': SONARR_KEY },
                body: JSON.stringify({
                    name: 'Transmission',
                    enable: true,
                    protocol: 'torrent',
                    priority: 1,
                    removeCompletedDownloads: true,
                    removeFailedDownloads: true,
                    implementation: 'Transmission',
                    configContract: 'TransmissionSettings',
                    fields: [
                        { name: 'host', value: 'transmission' },
                        { name: 'port', value: 9091 },
                        { name: 'urlBase', value: '/transmission/' },
                        { name: 'username', value: '' },
                        { name: 'password', value: '' },
                        { name: 'category', value: 'tv-sonarr' },
                        { name: 'useSsl', value: false }
                    ]
                })
            });
            console.log('Sonarr Transmission client configured. HTTP Status:', dlRes.status);
        } catch (e) {
            console.log('Note on Sonarr Transmission client:', e.message);
        }

    } catch (err) {
        console.error('Sonarr config error:', err.message);
    }
}

async function configureRadarr() {
    console.log('\n--- Configuring Radarr ---');
    try {
        const rootRes = await fetch(`${RADARR_URL}/api/v3/rootfolder`, {
            headers: { 'X-Api-Key': RADARR_KEY }
        });
        const rootData = await rootRes.json();
        const existingPaths = (Array.isArray(rootData) ? rootData : []).map(r => r.path);
        console.log('Existing Radarr root folders:', existingPaths);

        for (const p of ['/data/movies', '/data/Movies']) {
            if (!existingPaths.includes(p)) {
                try {
                    const addRes = await fetch(`${RADARR_URL}/api/v3/rootfolder`, {
                        method: 'POST',
                        headers: { 'Content-Type': 'application/json', 'X-Api-Key': RADARR_KEY },
                        body: JSON.stringify({ path: p })
                    });
                    const addData = await addRes.json();
                    console.log(`Added Radarr root folder: ${p}`, addData.id ? `(ID: ${addData.id})` : addData);
                } catch (e) {
                    console.log(`Note on Radarr root folder ${p}:`, e.message);
                }
            }
        }

        // Add Transmission download client to Radarr
        try {
            const dlRes = await fetch(`${RADARR_URL}/api/v3/downloadclient`, {
                method: 'POST',
                headers: { 'Content-Type': 'application/json', 'X-Api-Key': RADARR_KEY },
                body: JSON.stringify({
                    name: 'Transmission',
                    enable: true,
                    protocol: 'torrent',
                    priority: 1,
                    removeCompletedDownloads: true,
                    removeFailedDownloads: true,
                    implementation: 'Transmission',
                    configContract: 'TransmissionSettings',
                    fields: [
                        { name: 'host', value: 'transmission' },
                        { name: 'port', value: 9091 },
                        { name: 'urlBase', value: '/transmission/' },
                        { name: 'username', value: '' },
                        { name: 'password', value: '' },
                        { name: 'category', value: 'radarr' },
                        { name: 'useSsl', value: false }
                    ]
                })
            });
            console.log('Radarr Transmission client configured. HTTP Status:', dlRes.status);
        } catch (e) {
            console.log('Note on Radarr Transmission client:', e.message);
        }

    } catch (err) {
        console.error('Radarr config error:', err.message);
    }
}

async function main() {
    await configureSonarr();
    await configureRadarr();
    console.log('\nArrs configuration complete.');
}

main();
