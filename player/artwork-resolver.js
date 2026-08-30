/**
 * Artwork and Artist Resolver for MediaStack Player
 * Intelligently resolves track artist names, expands abbreviations (e.g., SW -> Steve Winwood),
 * and supplies high-resolution artwork for tracks missing embedded images or artist tags.
 */
class ArtworkResolver {
    constructor(artistsData) {
        this.data = artistsData || null;
        this.fallback = (this.data && this.data.default_fallback) ? this.data.default_fallback : {
            image_url: 'https://images.unsplash.com/photo-1511671782779-c97d3d27a1d4?q=80&w=800&auto=format&fit=crop',
            thumbnail_url: 'https://images.unsplash.com/photo-1511671782779-c97d3d27a1d4?q=80&w=300&auto=format&fit=crop',
            banner_url: 'https://images.unsplash.com/photo-1470225620780-dba8ba36b745?q=80&w=1600&auto=format&fit=crop'
        };
    }

    static async load(jsonPath = 'artists.json') {
        try {
            const resp = await fetch(jsonPath);
            if (!resp.ok) throw new Error(`HTTP ${resp.status}`);
            const json = await resp.json();
            return new ArtworkResolver(json);
        } catch (e) {
            console.warn('ArtworkResolver: Could not load artists.json. Using standard fallbacks.', e);
            return new ArtworkResolver(null);
        }
    }

    /**
     * Resolves metadata and artwork for a track object.
     * @param {Object} track - Object containing { artist, title, album, path, filename, artworkUrl, genre }
     * @returns {Object} { artist, artworkUrl, bannerUrl, genres, bio }
     */
    resolveTrack(track = {}) {
        if (!this.data || !this.data.artists) {
            return {
                artist: track.artist || 'Unknown Artist',
                artworkUrl: track.artworkUrl || this.fallback.image_url,
                bannerUrl: this.fallback.banner_url,
                genres: track.genre ? [track.genre] : ['Music'],
                bio: ''
            };
        }

        const inputArtist = (track.artist || '').trim();
        const inputTitle = (track.title || '').trim();
        const inputAlbum = (track.album || '').trim();
        const inputPath = (track.path || track.filename || '').trim();

        // 1. Direct and Alias matching (e.g. 'SW' -> 'Steve Winwood')
        if (inputArtist) {
            for (const artist of this.data.artists) {
                if (artist.name.toLowerCase() === inputArtist.toLowerCase()) {
                    return {
                        artist: artist.name,
                        artworkUrl: track.artworkUrl || artist.image_url,
                        bannerUrl: artist.banner_url,
                        genres: artist.genres || [],
                        bio: artist.bio_summary || ''
                    };
                }
                if (artist.aliases && artist.aliases.some(a => a.toLowerCase() === inputArtist.toLowerCase())) {
                    return {
                        artist: artist.name,
                        artworkUrl: track.artworkUrl || artist.image_url,
                        bannerUrl: artist.banner_url,
                        genres: artist.genres || [],
                        bio: artist.bio_summary || ''
                    };
                }
            }
        }

        // 2. Signature Regex matching against combined metadata & filename
        const combined = `${inputPath} ${inputTitle} ${inputAlbum} ${inputArtist}`;
        for (const artist of this.data.artists) {
            if (artist.track_signature_regex) {
                try {
                    const re = new RegExp(artist.track_signature_regex, 'i');
                    if (re.test(combined)) {
                        return {
                            artist: artist.name,
                            artworkUrl: track.artworkUrl || artist.image_url,
                            bannerUrl: artist.banner_url,
                            genres: artist.genres || [],
                            bio: artist.bio_summary || ''
                        };
                    }
                } catch (e) {
                    console.error('ArtworkResolver: Regex error for artist ' + artist.name, e);
                }
            }
        }

        // 3. Fallback
        const genreFallback = (track.genre && this.fallback.genre_fallbacks && this.fallback.genre_fallbacks[track.genre])
            ? this.fallback.genre_fallbacks[track.genre]
            : this.fallback.image_url;

        return {
            artist: inputArtist || 'Unknown Artist',
            artworkUrl: track.artworkUrl || genreFallback,
            bannerUrl: this.fallback.banner_url,
            genres: track.genre ? [track.genre] : ['Music'],
            bio: ''
        };
    }
}

if (typeof window !== 'undefined') {
    window.ArtworkResolver = ArtworkResolver;
}
if (typeof module !== 'undefined' && module.exports) {
    module.exports = ArtworkResolver;
}
