// MediaStack Player Client SPA JavaScript
const API_URL = ''; // Relative path, Caddy handles reverse proxies
let accessToken = sessionStorage.getItem('jellyfin_token') || null;
let userId = sessionStorage.getItem('jellyfin_user_id') || null;
let username = sessionStorage.getItem('jellyfin_username') || null;
let activeCategory = 'Movie'; // Movie or Series

// DOM Elements
const bgOverlay = document.getElementById('bg-overlay');
const profileAvatar = document.getElementById('profile-avatar');
const openingMsg = document.getElementById('opening-msg');
const customStyles = document.getElementById('custom-enforced-styles');

const loginContainer = document.getElementById('login-container');
const loginForm = document.getElementById('login-form');
const loginError = document.getElementById('login-error');

const appContainer = document.getElementById('app-container');
const userDisplay = document.getElementById('user-display');
const logoutBtn = document.getElementById('logout-btn');
const mediaGrid = document.getElementById('media-grid');
const loadingSpinner = document.getElementById('loading-spinner');
const emptyState = document.getElementById('empty-state');
const tabButtons = document.querySelectorAll('.tab-btn');

const playerModal = document.getElementById('player-modal');
const videoElement = document.getElementById('video-element');
if (videoElement) {
    videoElement.setAttribute('controlslist', 'nodownload');
}
const closePlayerBtn = document.getElementById('close-player-btn');

// --- Theme Management ---
function initTheme() {
    const currentTheme = localStorage.getItem('theme') || 'dark';
    if (currentTheme === 'light') {
        document.body.classList.add('light-theme');
        updateThemeIcons('light');
    } else {
        document.body.classList.remove('light-theme');
        updateThemeIcons('dark');
    }
}

function toggleTheme() {
    if (document.body.classList.contains('light-theme')) {
        document.body.classList.remove('light-theme');
        localStorage.setItem('theme', 'dark');
        updateThemeIcons('dark');
    } else {
        document.body.classList.add('light-theme');
        localStorage.setItem('theme', 'light');
        updateThemeIcons('light');
    }
}

function updateThemeIcons(theme) {
    const loginToggle = document.getElementById('login-theme-toggle');
    const appToggle = document.getElementById('app-theme-toggle');
    const iconClass = theme === 'light' ? 'ph-sun' : 'ph-moon';
    
    if (loginToggle) {
        loginToggle.innerHTML = `<i class="ph ${iconClass}"></i>`;
    }
    if (appToggle) {
        appToggle.innerHTML = `<i class="ph ${iconClass}"></i>`;
    }
}

// --- Initialization ---
document.addEventListener('DOMContentLoaded', () => {
    // Check if URL has authentication parameters (magic login link)
    const urlParams = new URLSearchParams(window.location.search);
    const queryToken = urlParams.get('token');
    const queryUserId = urlParams.get('userId');
    const queryUsername = urlParams.get('username');
    
    if (queryToken && queryUserId && queryUsername) {
        accessToken = queryToken;
        userId = queryUserId;
        username = queryUsername;
        sessionStorage.setItem('jellyfin_token', accessToken);
        sessionStorage.setItem('jellyfin_user_id', userId);
        sessionStorage.setItem('jellyfin_username', username);
        
        // Clean URL to hide token from browser history
        window.history.replaceState({}, document.title, window.location.pathname);
    }

    initTheme();
    loadPlayerSettings();
    
    // Bind theme toggle buttons
    const loginThemeToggle = document.getElementById('login-theme-toggle');
    const appThemeToggle = document.getElementById('app-theme-toggle');
    if (loginThemeToggle) loginThemeToggle.addEventListener('click', toggleTheme);
    if (appThemeToggle) appThemeToggle.addEventListener('click', toggleTheme);
    
    if (accessToken && userId) {
        showApp();
    } else {
        showLogin();
    }
});



// Fetch settings from SQLite internal database via API Gateway
async function loadPlayerSettings() {
    try {
        const res = await fetch('/api/player/settings');
        if (!res.ok) throw new Error('Failed to load settings');
        const settings = await res.json();
        
        // Apply settings
        if (settings.opening_message) {
            openingMsg.innerText = settings.opening_message;
        } else {
            openingMsg.innerText = "Welcome to Voltaire's MediaStack Player. Please authenticate to stream.";
        }
        
        if (settings.enforced_css) {
            customStyles.textContent = settings.enforced_css;
        }
        
        if (settings.background_image) {
            // Check if it already includes prefix
            const bgData = settings.background_image.startsWith('data:') 
                ? settings.background_image 
                : `data:image/png;base64,${settings.background_image}`;
            bgOverlay.style.backgroundImage = `url("${bgData}")`;
            bgOverlay.style.filter = "blur(8px) brightness(0.3)";
        }
        
        if (settings.profile_image) {
            const avatarData = settings.profile_image.startsWith('data:') 
                ? settings.profile_image 
                : `data:image/png;base64,${settings.profile_image}`;
            profileAvatar.src = avatarData;
        }
    } catch (e) {
        console.error('Error fetching player settings:', e);
        openingMsg.innerText = "Welcome to Voltaire's MediaStack Player.";
    }
}

// --- Authentication ---
loginForm.addEventListener('submit', async (e) => {
    e.preventDefault();
    loginError.innerText = '';
    
    const userVal = document.getElementById('username').value.trim();
    const passVal = document.getElementById('password').value;
    
    try {
        // Jellyfin Emby Authentication Headers
        const authHeader = 'MediaBrowser Client="MediaStackPlayer", Device="WebBrowser", DeviceId="MediaStackPlayerDevice", Version="1.0.0"';
        
        const response = await fetch('/jellyfin/Users/AuthenticateByName', {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
                'X-Emby-Authorization': authHeader
            },
            body: JSON.stringify({
                Username: userVal,
                Pw: passVal
            })
        });
        
        if (!response.ok) {
            if (response.status === 401) {
                throw new Error('Invalid username or password.');
            }
            throw new Error('Failed to connect to Jellyfin server.');
        }
        
        const data = await response.json();
        
        accessToken = data.AccessToken;
        userId = data.User.Id;
        username = data.User.Name;
        
        sessionStorage.setItem('jellyfin_token', accessToken);
        sessionStorage.setItem('jellyfin_user_id', userId);
        sessionStorage.setItem('jellyfin_username', username);
        
        showApp();
    } catch (err) {
        loginError.innerText = err.message;
    }
});

function showLogin() {
    loginContainer.classList.remove('hidden');
    appContainer.classList.add('hidden');
}

function showApp() {
    loginContainer.classList.add('hidden');
    appContainer.classList.remove('hidden');
    userDisplay.innerHTML = `<i class="ph ph-user-circle"></i> ${username}`;
    fetchLibrary();
}

logoutBtn.addEventListener('click', () => {
    sessionStorage.clear();
    accessToken = null;
    userId = null;
    username = null;
    showLogin();
});

// --- Category Tabs ---
tabButtons.forEach(btn => {
    btn.addEventListener('click', (e) => {
        tabButtons.forEach(b => b.classList.remove('active'));
        btn.classList.add('active');
        activeCategory = btn.dataset.type;
        fetchLibrary();
    });
});

// --- Fetch Library ---
async function fetchLibrary() {
    mediaGrid.innerHTML = '';
    loadingSpinner.classList.remove('hidden');
    emptyState.classList.add('hidden');
    
    try {
        let itemTypes = activeCategory;
        if (activeCategory === 'Video') {
            itemTypes = 'Video,Movie';
        } else if (activeCategory === 'Downloads') {
            itemTypes = 'Movie,Series,Video,Episode';
        } else if (activeCategory === 'Music') {
            itemTypes = 'MusicAlbum,Audio';
        }

        const queryParams = new URLSearchParams({
            Recursive: 'true',
            IncludeItemTypes: itemTypes,
            Fields: 'PrimaryImageAspectRatio,Overview,Path,MediaSources',
            SortBy: 'SortName',
            SortOrder: 'Ascending'
        });
        
        const response = await fetch(`/jellyfin/Users/${userId}/Items?${queryParams.toString()}`, {
            headers: {
                'X-Emby-Token': accessToken
            }
        });
        
        if (!response.ok) throw new Error('Failed to retrieve items');
        
        const data = await response.json();
        let items = data.Items || [];

        // Category-specific client filtering if needed
        if (activeCategory === 'Video') {
            items = items.filter(it => (it.Path && it.Path.toLowerCase().includes('/videos')) || it.Type === 'Video');
        } else if (activeCategory === 'Downloads') {
            items = items.filter(it => it.Path && it.Path.toLowerCase().includes('/downloads'));
            // If none matched directly with /downloads, fallback to showing all completed items
            if (items.length === 0) {
                items = data.Items || [];
            }
        }
        
        loadingSpinner.classList.add('hidden');
        
        if (items.length === 0) {
            emptyState.classList.remove('hidden');
            return;
        }
        
        items.forEach(item => {
            renderMediaCard(item);
        });
    } catch (err) {
        console.error(err);
        loadingSpinner.classList.add('hidden');
        emptyState.classList.remove('hidden');
        emptyState.querySelector('p').innerText = 'Error fetching media. Ensure the server is online.';
    }
}

function renderMediaCard(item) {
    const card = document.createElement('div');
    card.className = 'glass-panel media-card';
    
    // Poster URL pointing to Jellyfin
    const posterUrl = `/jellyfin/Items/${item.Id}/Images/Primary?maxWidth=400`;
    const fallbackSvg = `data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 200 300'><rect width='200' height='300' fill='%2312131a'/><text x='50%25' y='50%25' fill='%236c5ce7' text-anchor='middle' dominant-baseline='middle' font-family='sans-serif'>No Image</text></svg>`;
    
    let metaText = item.ProductionYear || (item.Type === 'Audio' ? (item.ArtistItems ? item.ArtistItems.map(a => a.Name).join(', ') : 'Audio Track') : item.Type);

    card.innerHTML = `
        <div class="card-img-wrapper">
            <img src="${posterUrl}" onerror="this.src='${fallbackSvg}'" alt="${item.Name}">
            <div class="play-overlay">
                <i class="ph ph-play-circle"></i>
            </div>
        </div>
        <div class="card-info">
            <div class="card-title">${item.Name}</div>
            <div class="card-meta">${metaText}</div>
        </div>
    `;
    
    card.addEventListener('click', () => {
        playMedia(item);
    });
    
    mediaGrid.appendChild(card);
}

// --- Player Controls ---
function playMedia(item) {
    // Check if it's a TV Series or Music Album folder
    if (item.Type === 'Series') {
        fetchEpisodes(item.Id);
    } else if (item.Type === 'MusicAlbum') {
        fetchAlbumTracks(item.Id);
    } else if (item.Type === 'Audio') {
        const streamUrl = `/jellyfin/Audio/${item.Id}/stream?static=true&PlaySessionId=MediaStackPlay&api_key=${accessToken}`;
        playerModal.classList.remove('hidden');
        videoElement.src = streamUrl;
        videoElement.play().catch(e => console.warn('Autoplay prevented:', e));
    } else {
        // Direct video stream url
        const streamUrl = `/jellyfin/Videos/${item.Id}/stream?static=true&PlaySessionId=MediaStackPlay&api_key=${accessToken}`;
        playerModal.classList.remove('hidden');
        videoElement.src = streamUrl;
        videoElement.play().catch(e => console.warn('Autoplay prevented:', e));
    }
}

// Handle Music Album track navigation
async function fetchAlbumTracks(albumId) {
    mediaGrid.innerHTML = '';
    loadingSpinner.classList.remove('hidden');
    
    try {
        const queryParams = new URLSearchParams({
            Recursive: 'true',
            IncludeItemTypes: 'Audio',
            ParentId: albumId,
            Fields: 'PrimaryImageAspectRatio,Overview,MediaSources',
            SortBy: 'IndexNumber',
            SortOrder: 'Ascending'
        });
        
        const response = await fetch(`/jellyfin/Users/${userId}/Items?${queryParams.toString()}`, {
            headers: {
                'X-Emby-Token': accessToken
            }
        });
        
        if (!response.ok) throw new Error('Failed to retrieve album tracks');
        
        const data = await response.json();
        const items = data.Items || [];
        
        loadingSpinner.classList.add('hidden');
        
        const backBtn = document.createElement('button');
        backBtn.className = 'btn icon-btn';
        backBtn.style.marginBottom = '20px';
        backBtn.innerHTML = `<i class="ph ph-arrow-left"></i> Back to Albums`;
        backBtn.addEventListener('click', fetchLibrary);
        mediaGrid.appendChild(backBtn);
        
        const div = document.createElement('div');
        div.style.gridColumn = '1 / -1';
        mediaGrid.appendChild(div);

        if (items.length === 0) {
            emptyState.classList.remove('hidden');
            return;
        }
        
        items.forEach(item => {
            renderMediaCard(item);
        });
    } catch (err) {
        console.error(err);
        loadingSpinner.classList.add('hidden');
        fetchLibrary();
    }
}

// Handle TV Shows episode navigation
async function fetchEpisodes(seriesId) {
    mediaGrid.innerHTML = '';
    loadingSpinner.classList.remove('hidden');
    
    try {
        const queryParams = new URLSearchParams({
            Recursive: 'true',
            IncludeItemTypes: 'Episode',
            SeriesId: seriesId,
            Fields: 'PrimaryImageAspectRatio,Overview',
            SortBy: 'SortName',
            SortOrder: 'Ascending'
        });
        
        const response = await fetch(`/jellyfin/Users/${userId}/Items?${queryParams.toString()}`, {
            headers: {
                'X-Emby-Token': accessToken
            }
        });
        
        if (!response.ok) throw new Error('Failed to retrieve episodes');
        
        const data = await response.json();
        const items = data.Items || [];
        
        loadingSpinner.classList.add('hidden');
        
        // Add a back button to main view
        const backBtn = document.createElement('button');
        backBtn.className = 'btn icon-btn';
        backBtn.style.marginBottom = '20px';
        backBtn.innerHTML = `<i class="ph ph-arrow-left"></i> Back to TV Shows`;
        backBtn.addEventListener('click', fetchLibrary);
        mediaGrid.appendChild(backBtn);
        
        // Divider
        const div = document.createElement('div');
        div.style.gridColumn = '1 / -1';
        mediaGrid.appendChild(div);

        if (items.length === 0) {
            emptyState.classList.remove('hidden');
            return;
        }
        
        items.forEach(item => {
            renderEpisodeCard(item);
        });
    } catch (err) {
        console.error(err);
        loadingSpinner.classList.add('hidden');
        fetchLibrary();
    }
}

function renderEpisodeCard(item) {
    const card = document.createElement('div');
    card.className = 'glass-panel media-card';
    
    const posterUrl = `/jellyfin/Items/${item.Id}/Images/Primary?maxWidth=400`;
    const fallbackSvg = `data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 200 120'><rect width='200' height='120' fill='%2312131a'/><text x='50%25' y='50%25' fill='%236c5ce7' text-anchor='middle' dominant-baseline='middle' font-family='sans-serif'>No Image</text></svg>`;
    
    card.innerHTML = `
        <div class="card-img-wrapper" style="aspect-ratio: 16/9;">
            <img src="${posterUrl}" onerror="this.src='${fallbackSvg}'" alt="${item.Name}">
            <div class="play-overlay">
                <i class="ph ph-play-circle"></i>
            </div>
        </div>
        <div class="card-info">
            <div class="card-title">${item.Name}</div>
            <div class="card-meta">Season ${item.ParentIndexNumber || 1} • Episode ${item.IndexNumber || 1}</div>
        </div>
    `;
    
    card.addEventListener('click', () => {
        const streamUrl = `/jellyfin/Videos/${item.Id}/stream?static=true&PlaySessionId=MediaStackPlay&api_key=${accessToken}`;
        playerModal.classList.remove('hidden');
        videoElement.src = streamUrl;
        videoElement.play().catch(e => console.warn('Autoplay prevented:', e));
    });
    
    mediaGrid.appendChild(card);
}

closePlayerBtn.addEventListener('click', () => {
    videoElement.pause();
    videoElement.src = '';
    playerModal.classList.add('hidden');
});
