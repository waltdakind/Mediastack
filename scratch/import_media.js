const SONARR_URL = 'http://localhost:8989';
const SONARR_KEY = '38c67d03fd45409f9888cf8a5e7f0bac';

const RADARR_URL = 'http://localhost:7878';
const RADARR_KEY = 'a5e014872ce84a558391afb466d1f95e';

async function importSonarr() {
    console.log('\n--- Importing Sonarr Series ---');
    try {
        // Search for Lanterns
        const searchRes = await fetch(`${SONARR_URL}/api/v3/series/lookup?term=Lanterns`, {
            headers: { 'X-Api-Key': SONARR_KEY }
        });
        const results = await searchRes.json();
        if (results && results.length > 0) {
            const series = results[0];
            series.rootFolderPath = '/data/Shows';
            series.path = '/data/Shows/Lanterns';
            series.monitored = true;
            series.qualityProfileId = 1;
            series.addOptions = { searchForMissingEpisodes: false, ignoreEpisodesWithFiles: false };

            const addRes = await fetch(`${SONARR_URL}/api/v3/series`, {
                method: 'POST',
                headers: { 'Content-Type': 'application/json', 'X-Api-Key': SONARR_KEY },
                body: JSON.stringify(series)
            });
            const addData = await addRes.json();
            console.log('Sonarr series import status:', addRes.status, addData.title || addData.message || addData);
        } else {
            console.log('No lookup results found for Lanterns');
        }

        // Trigger RescanSeries Command
        await fetch(`${SONARR_URL}/api/v3/command`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json', 'X-Api-Key': SONARR_KEY },
            body: JSON.stringify({ name: 'RescanSeries' })
        });
        console.log('Sonarr RescanSeries command triggered.');

    } catch (err) {
        console.error('Sonarr import error:', err.message);
    }
}

async function importRadarr() {
    console.log('\n--- Importing Radarr Movies ---');
    const movies = [
        { term: 'Marcel the Shell with Shoes On 2022', path: '/data/movies/Marcel the Shell with Shoes On (2022)' },
        { term: 'Supergirl 2026', path: '/data/movies/Supergirl (2026)' }
    ];

    for (const m of movies) {
        try {
            const searchRes = await fetch(`${RADARR_URL}/api/v3/movie/lookup?term=${encodeURIComponent(m.term)}`, {
                headers: { 'X-Api-Key': RADARR_KEY }
            });
            const results = await searchRes.json();
            if (results && results.length > 0) {
                const movie = results[0];
                movie.rootFolderPath = '/data/movies';
                movie.path = m.path;
                movie.monitored = true;
                movie.qualityProfileId = 1;
                movie.addOptions = { searchForMovie: false };

                const addRes = await fetch(`${RADARR_URL}/api/v3/movie`, {
                    method: 'POST',
                    headers: { 'Content-Type': 'application/json', 'X-Api-Key': RADARR_KEY },
                    body: JSON.stringify(movie)
                });
                const addData = await addRes.json();
                console.log(`Radarr movie import (${m.term}):`, addRes.status, addData.title || addData.message || addData);
            } else {
                console.log(`No lookup results found in Radarr for ${m.term}`);
            }
        } catch (e) {
            console.log(`Error importing ${m.term}:`, e.message);
        }
    }

    // Trigger RescanMovie Command
    try {
        await fetch(`${RADARR_URL}/api/v3/command`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json', 'X-Api-Key': RADARR_KEY },
            body: JSON.stringify({ name: 'RescanMovie' })
        });
        console.log('Radarr RescanMovie command triggered.');
    } catch (e) {}
}

async function main() {
    await importSonarr();
    await importRadarr();
}

main();
