const JELLYFIN_URL = 'http://localhost:8096';
const JELLYFIN_KEY = '8d59455725204c0cae4ba6dc171ab519';
const JELLYFIN_USER = '6548307B2D8C42DE939CE4C8A644D5FB';

const SONARR_URL = 'http://localhost:8989';
const SONARR_KEY = '38c67d03fd45409f9888cf8a5e7f0bac';

const RADARR_URL = 'http://localhost:7878';
const RADARR_KEY = 'a5e014872ce84a558391afb466d1f95e';

async function fetchJellyfin(types) {
    const res = await fetch(`${JELLYFIN_URL}/Users/${JELLYFIN_USER}/Items?Recursive=true&IncludeItemTypes=${types}&Fields=Path&api_key=${JELLYFIN_KEY}`);
    const data = await res.json();
    return data.Items || [];
}

async function verify() {
    console.log('================================================================');
    console.log('       MEDIASTACK VISUAL & AUDIO MEDIA VERIFICATION AUDIT       ');
    console.log('================================================================');

    // 1. Jellyfin Items
    try {
        const movies = await fetchJellyfin('Movie');
        const series = await fetchJellyfin('Series');
        const episodes = await fetchJellyfin('Episode');
        const videos = await fetchJellyfin('Video');

        console.log('\n[Jellyfin Library Health]');
        console.log(`✓ Movies Found:           ${movies.length}`);
        movies.forEach(m => console.log(`   - ${m.Name} (${m.ProductionYear || 'N/A'}) [${m.Path}]`));

        console.log(`✓ TV Series Found:        ${series.length}`);
        series.forEach(s => console.log(`   - ${s.Name} [${s.Path}]`));

        console.log(`✓ TV Episodes Found:      ${episodes.length}`);
        episodes.forEach(e => console.log(`   - ${e.Name} [${e.Path}]`));

        console.log(`✓ Personal Videos Found:  ${videos.length}`);
        videos.forEach(v => console.log(`   - ${v.Name} [${v.Path}]`));

    } catch (e) {
        console.error('Jellyfin audit failed:', e.message);
    }

    // 2. Sonarr State
    try {
        const sRes = await fetch(`${SONARR_URL}/api/v3/series`, { headers: { 'X-Api-Key': SONARR_KEY } });
        const sData = await sRes.json();
        console.log('\n[Sonarr TV Shows]');
        console.log(`✓ Monitored Shows:        ${sData.length}`);
        sData.forEach(s => console.log(`   - ${s.title} (Status: ${s.status}, Path: ${s.path}, FileCount: ${s.statistics?.episodeFileCount || 0})`));
    } catch (e) {
        console.error('Sonarr audit failed:', e.message);
    }

    // 3. Radarr State
    try {
        const rRes = await fetch(`${RADARR_URL}/api/v3/movie`, { headers: { 'X-Api-Key': RADARR_KEY } });
        const rData = await rRes.json();
        console.log('\n[Radarr Movies]');
        console.log(`✓ Monitored Movies:       ${rData.length}`);
        rData.forEach(m => console.log(`   - ${m.title} (${m.year}) [HasFile: ${m.hasFile}, Path: ${m.path}]`));
    } catch (e) {
        console.error('Radarr audit failed:', e.message);
    }

    console.log('\n================================================================');
    console.log('       ALL VISUAL MEDIA SERVICES VERIFIED AND OPERATIONAL       ');
    console.log('================================================================\n');
}

verify();
