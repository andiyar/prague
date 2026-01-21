// =============================================================================
// BEN'S PRAGUE TRIP DASHBOARD
// =============================================================================

// Supabase Config
const SUPABASE_URL = 'https://dyxupzbyssvcxjppipnl.supabase.co';
const SUPABASE_ANON_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImR5eHVwemJ5c3N2Y3hqcHBpcG5sIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Njg5Mjc0MTksImV4cCI6MjA4NDUwMzQxOX0._pmFY2kmyUYLauX-BQeELbWziJ4nuXIaxOM5YsUYsBI';

// Initialize Supabase client
const supabaseClient = window.supabase.createClient(SUPABASE_URL, SUPABASE_ANON_KEY);

// Global state
let tripSegments = [];
let config = {};
let currentStatus = null;
let familyMap = null;
let kidsMap = null;
let planeMarker = null;
let kidsPlaneMarker = null;

// Airport coordinates for flight paths
const AIRPORTS = {
    SYD: { lat: -33.9461, lng: 151.1772, name: 'Sydney' },
    DXB: { lat: 25.2532, lng: 55.3657, name: 'Dubai' },
    PRG: { lat: 50.1008, lng: 14.2600, name: 'Prague' }
};

// =============================================================================
// INITIALIZATION
// =============================================================================

document.addEventListener('DOMContentLoaded', async () => {
    // Set up view toggle
    setupViewToggle();

    // Check URL for view parameter
    const urlParams = new URLSearchParams(window.location.search);
    if (urlParams.get('view') === 'kids') {
        switchView('kids');
    }

    // Load data from Supabase
    await loadData();

    // Initialize maps
    initMaps();

    // Start update loops
    updateClocks();
    setInterval(updateClocks, 1000);

    updateStatus();
    setInterval(updateStatus, 30000); // Update status every 30 seconds

    updateCountdown();
    setInterval(updateCountdown, 60000); // Update countdown every minute

    // Load weather
    loadWeather();
});

// =============================================================================
// VIEW TOGGLE
// =============================================================================

function setupViewToggle() {
    const btnFamily = document.getElementById('btn-family');
    const btnKids = document.getElementById('btn-kids');

    btnFamily.addEventListener('click', () => switchView('family'));
    btnKids.addEventListener('click', () => switchView('kids'));
}

function switchView(view) {
    const familyView = document.getElementById('family-view');
    const kidsView = document.getElementById('kids-view');
    const btnFamily = document.getElementById('btn-family');
    const btnKids = document.getElementById('btn-kids');

    if (view === 'kids') {
        familyView.classList.remove('active');
        kidsView.classList.add('active');
        btnFamily.classList.remove('active');
        btnKids.classList.add('active');

        // Invalidate kids map size after view switch
        setTimeout(() => {
            if (kidsMap) kidsMap.invalidateSize();
        }, 100);
    } else {
        familyView.classList.add('active');
        kidsView.classList.remove('active');
        btnFamily.classList.add('active');
        btnKids.classList.remove('active');

        // Invalidate family map size after view switch
        setTimeout(() => {
            if (familyMap) familyMap.invalidateSize();
        }, 100);
    }
}

// =============================================================================
// DATA LOADING
// =============================================================================

async function loadData() {
    try {
        // Load trip segments
        const { data: segments, error: segmentsError } = await supabaseClient
            .from('trip_segments')
            .select('*')
            .order('start_time', { ascending: true });

        if (segmentsError) throw segmentsError;
        tripSegments = segments || [];

        // Load config
        const { data: configData, error: configError } = await supabaseClient
            .from('config')
            .select('*');

        if (configError) throw configError;
        config = {};
        (configData || []).forEach(row => {
            config[row.key] = row.value;
        });

        // Render flights
        renderFlights();

        // Render contact info
        renderContact();

    } catch (error) {
        console.error('Error loading data:', error);
    }
}

// =============================================================================
// STATUS
// =============================================================================

async function updateStatus() {
    try {
        const now = new Date();

        // Check for active override first
        const { data: overrides, error: overrideError } = await supabaseClient
            .from('status_override')
            .select('*')
            .gt('expires_at', now.toISOString())
            .order('created_at', { ascending: false })
            .limit(1);

        if (!overrideError && overrides && overrides.length > 0) {
            currentStatus = {
                ...overrides[0],
                isOverride: true
            };
        } else {
            // Find current segment based on time
            const segment = tripSegments.find(s => {
                const start = new Date(s.start_time);
                const end = new Date(s.end_time);
                return now >= start && now < end;
            });

            if (segment) {
                currentStatus = {
                    ...segment,
                    isOverride: false
                };
            } else {
                // Default: trip hasn't started or has ended
                const firstSegment = tripSegments[0];
                const lastSegment = tripSegments[tripSegments.length - 1];

                if (firstSegment && now < new Date(firstSegment.start_time)) {
                    currentStatus = {
                        status_emoji: '📅',
                        status_text: 'Trip starts soon!',
                        kids_text: 'Daddy\'s trip is coming up!',
                        lat: -33.8688,
                        lng: 151.2093,
                        isOverride: false
                    };
                } else if (lastSegment) {
                    currentStatus = {
                        status_emoji: '🏠',
                        status_text: 'Back home!',
                        kids_text: 'Daddy\'s home!',
                        lat: -33.8688,
                        lng: 151.2093,
                        isOverride: false
                    };
                }
            }
        }

        // Update UI
        renderStatus();
        updateMapPosition();

    } catch (error) {
        console.error('Error updating status:', error);
    }
}

function renderStatus() {
    if (!currentStatus) return;

    // Family view
    document.getElementById('status-emoji').textContent = currentStatus.status_emoji;
    document.getElementById('status-title').textContent = currentStatus.status_text;

    const noteEl = document.getElementById('status-note');
    if (currentStatus.note) {
        noteEl.textContent = currentStatus.note;
        noteEl.style.display = 'block';
    } else {
        noteEl.style.display = 'none';
    }

    const updatedEl = document.getElementById('status-updated');
    if (currentStatus.isOverride && currentStatus.created_at) {
        const updated = new Date(currentStatus.created_at);
        updatedEl.textContent = `Updated ${formatTimeAgo(updated)}`;
    } else {
        updatedEl.textContent = '';
    }

    // Kids view
    document.getElementById('kids-emoji').textContent = currentStatus.status_emoji;
    document.getElementById('kids-text').textContent = currentStatus.kids_text;
}

function formatTimeAgo(date) {
    const now = new Date();
    const diff = Math.floor((now - date) / 1000 / 60); // minutes

    if (diff < 1) return 'just now';
    if (diff < 60) return `${diff} minute${diff > 1 ? 's' : ''} ago`;
    if (diff < 1440) return `${Math.floor(diff / 60)} hour${Math.floor(diff / 60) > 1 ? 's' : ''} ago`;
    return `${Math.floor(diff / 1440)} day${Math.floor(diff / 1440) > 1 ? 's' : ''} ago`;
}

// =============================================================================
// CLOCKS
// =============================================================================

function updateClocks() {
    const now = new Date();

    // Sydney (AEST = UTC+10, no DST in May)
    const sydneyTime = new Date(now.toLocaleString('en-US', { timeZone: 'Australia/Sydney' }));
    document.getElementById('time-sydney').textContent = formatTime(sydneyTime);

    // Prague (CEST = UTC+2 in May)
    const pragueTime = new Date(now.toLocaleString('en-US', { timeZone: 'Europe/Prague' }));
    document.getElementById('time-prague').textContent = formatTime(pragueTime);

    // Dad's local time (based on current status location)
    let dadTimezone = 'Australia/Sydney';
    let dadLabel = 'Sydney';

    if (currentStatus) {
        if (currentStatus.flight_from === 'DXB' || currentStatus.flight_to === 'DXB' ||
            (currentStatus.location && currentStatus.location.includes('Dubai'))) {
            dadTimezone = 'Asia/Dubai';
            dadLabel = 'Dubai';
        } else if (currentStatus.lat && currentStatus.lat > 40 && currentStatus.lng > 10 && currentStatus.lng < 20) {
            dadTimezone = 'Europe/Prague';
            dadLabel = 'Prague';
        }
    }

    const dadTime = new Date(now.toLocaleString('en-US', { timeZone: dadTimezone }));
    document.getElementById('time-dad').textContent = formatTime(dadTime);
    document.getElementById('label-dad').textContent = `Ben (${dadLabel})`;

    // Highlight the relevant clock
    document.querySelectorAll('.clock').forEach(el => el.classList.remove('highlight'));
    document.getElementById('clock-dad').classList.add('highlight');
}

function formatTime(date) {
    return date.toLocaleTimeString('en-AU', {
        hour: '2-digit',
        minute: '2-digit',
        hour12: false
    });
}

// =============================================================================
// COUNTDOWN
// =============================================================================

function updateCountdown() {
    const returnTime = config.return_datetime_utc
        ? new Date(config.return_datetime_utc)
        : new Date('2026-05-17T20:05:00Z');

    const now = new Date();
    const diff = returnTime - now;

    if (diff <= 0) {
        document.getElementById('countdown-value').textContent = '🎉';
        document.getElementById('countdown-label').textContent = 'Ben\'s home!';
        document.getElementById('kids-countdown-value').textContent = '0';
        document.getElementById('kids-countdown-label').textContent = 'Daddy\'s home!';
        return;
    }

    const days = Math.floor(diff / (1000 * 60 * 60 * 24));
    const hours = Math.floor((diff % (1000 * 60 * 60 * 24)) / (1000 * 60 * 60));

    // Family view countdown
    if (days > 0) {
        document.getElementById('countdown-value').textContent = `${days}d ${hours}h`;
    } else {
        document.getElementById('countdown-value').textContent = `${hours}h`;
    }
    document.getElementById('countdown-label').textContent = 'until Ben\'s home';

    // Kids view: count sleeps (Sydney midnights)
    const sydneyNow = new Date(now.toLocaleString('en-US', { timeZone: 'Australia/Sydney' }));
    const sydneyReturn = new Date(returnTime.toLocaleString('en-US', { timeZone: 'Australia/Sydney' }));

    // Count midnights between now and return
    let sleeps = 0;
    const checkDate = new Date(sydneyNow);
    checkDate.setHours(0, 0, 0, 0);
    checkDate.setDate(checkDate.getDate() + 1); // Start from next midnight

    while (checkDate <= sydneyReturn) {
        sleeps++;
        checkDate.setDate(checkDate.getDate() + 1);
    }

    document.getElementById('kids-countdown-value').textContent = sleeps;
    document.getElementById('kids-countdown-label').textContent =
        sleeps === 1 ? 'sleep until Daddy\'s home!' : 'sleeps until Daddy\'s home!';
}

// =============================================================================
// FLIGHTS
// =============================================================================

function renderFlights() {
    const container = document.getElementById('flights-container');
    const flights = tripSegments.filter(s => s.flight_number);

    if (flights.length === 0) {
        container.innerHTML = '<div class="loading">No flight data available</div>';
        return;
    }

    const now = new Date();

    container.innerHTML = flights.map(flight => {
        const start = new Date(flight.start_time);
        const end = new Date(flight.end_time);
        const duration = end - start;

        let progress = 0;
        let statusText = 'Scheduled';
        let isComplete = false;

        if (now >= end) {
            progress = 100;
            statusText = 'Complete';
            isComplete = true;
        } else if (now >= start) {
            progress = Math.min(100, ((now - start) / duration) * 100);
            const remaining = end - now;
            const hoursLeft = Math.floor(remaining / (1000 * 60 * 60));
            const minsLeft = Math.floor((remaining % (1000 * 60 * 60)) / (1000 * 60));
            statusText = hoursLeft > 0 ? `${hoursLeft}h ${minsLeft}m remaining` : `${minsLeft}m remaining`;
        }

        const fromAirport = AIRPORTS[flight.flight_from] || { name: flight.flight_from };
        const toAirport = AIRPORTS[flight.flight_to] || { name: flight.flight_to };

        const departTime = start.toLocaleString('en-AU', {
            weekday: 'short',
            day: 'numeric',
            month: 'short',
            hour: '2-digit',
            minute: '2-digit',
            timeZone: flight.flight_from === 'SYD' ? 'Australia/Sydney' :
                       flight.flight_from === 'DXB' ? 'Asia/Dubai' : 'Europe/Prague'
        });

        return `
            <div class="flight-card">
                <div class="flight-header">
                    <span class="flight-number">✈️ ${flight.flight_number}</span>
                    <span class="flight-route">${fromAirport.name} → ${toAirport.name}</span>
                </div>
                <div class="flight-time">${departTime}</div>
                <div class="progress-bar">
                    <div class="progress-fill ${isComplete ? 'complete' : ''}" style="width: ${progress}%"></div>
                </div>
                <div class="flight-status">
                    <span class="flight-status-text">${isComplete ? '✅' : progress > 0 ? '🛫' : '📅'} ${statusText}</span>
                    ${!isComplete ? `<a href="https://www.flightradar24.com/${flight.flight_number}" target="_blank" class="track-link">Track Live →</a>` : ''}
                </div>
            </div>
        `;
    }).join('');
}

// =============================================================================
// WEATHER
// =============================================================================

async function loadWeather() {
    try {
        // Determine location for weather
        let lat = 50.0875; // Prague default
        let lng = 14.4213;
        let locationName = 'Prague';

        if (currentStatus && currentStatus.lat && currentStatus.lng) {
            lat = currentStatus.lat;
            lng = currentStatus.lng;

            if (lat < 0) locationName = 'Sydney';
            else if (lat > 20 && lat < 30) locationName = 'Dubai';
            else locationName = 'Prague';
        }

        const response = await fetch(
            `https://api.open-meteo.com/v1/forecast?latitude=${lat}&longitude=${lng}&current=temperature_2m,weather_code`
        );

        if (!response.ok) throw new Error('Weather fetch failed');

        const data = await response.json();
        const temp = Math.round(data.current.temperature_2m);
        const weatherCode = data.current.weather_code;

        document.getElementById('weather-temp').textContent = `${temp}°C`;
        document.getElementById('weather-icon').textContent = getWeatherEmoji(weatherCode);
        document.getElementById('weather-desc').textContent = getWeatherDescription(weatherCode);
        document.getElementById('weather-location').textContent = `in ${locationName}`;

    } catch (error) {
        console.error('Error loading weather:', error);
        document.getElementById('weather-temp').textContent = '--';
        document.getElementById('weather-desc').textContent = 'Unable to load weather';
    }
}

function getWeatherEmoji(code) {
    if (code === 0) return '☀️';
    if (code <= 3) return '⛅';
    if (code <= 48) return '☁️';
    if (code <= 67) return '🌧️';
    if (code <= 77) return '🌨️';
    if (code <= 82) return '🌧️';
    if (code <= 86) return '🌨️';
    if (code >= 95) return '⛈️';
    return '🌤️';
}

function getWeatherDescription(code) {
    if (code === 0) return 'Clear sky';
    if (code <= 3) return 'Partly cloudy';
    if (code <= 48) return 'Foggy';
    if (code <= 67) return 'Rainy';
    if (code <= 77) return 'Snowy';
    if (code <= 82) return 'Rain showers';
    if (code <= 86) return 'Snow showers';
    if (code >= 95) return 'Thunderstorm';
    return 'Variable';
}

// =============================================================================
// CONTACT
// =============================================================================

function renderContact() {
    const container = document.getElementById('contact-container');

    const items = [
        { label: 'Hotel', value: config.hotel_name || 'STAGES HOTEL Prague', link: null },
        { label: 'Hotel Address', value: config.hotel_address || 'Ceskomoravska 19a, Prague', link: `https://maps.google.com/?q=${encodeURIComponent(config.hotel_address || 'Ceskomoravska 19a Prague')}` },
        { label: 'Conference', value: config.conference_name || 'EAPC World Congress 2026', link: config.conference_url },
        { label: 'Ben\'s Phone', value: config.contact_phone || 'Not set', link: config.contact_phone ? `tel:${config.contact_phone}` : null },
        { label: 'Emergency', value: config.emergency_contact || 'Not set', link: null }
    ];

    container.innerHTML = items.map(item => `
        <div class="contact-item">
            <span class="contact-label">${item.label}</span>
            <span class="contact-value">
                ${item.link ? `<a href="${item.link}" target="_blank">${item.value}</a>` : item.value}
            </span>
        </div>
    `).join('');
}

// =============================================================================
// MAPS
// =============================================================================

function initMaps() {
    // Family map
    familyMap = L.map('family-map').setView([50.0875, 14.4213], 4);
    L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', {
        attribution: '© OpenStreetMap contributors'
    }).addTo(familyMap);

    // Kids map
    kidsMap = L.map('kids-map').setView([50.0875, 14.4213], 3);
    L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', {
        attribution: '© OpenStreetMap contributors'
    }).addTo(kidsMap);

    // Draw flight paths on kids map
    drawFlightPaths(kidsMap);
}

function drawFlightPaths(map) {
    // Sydney to Dubai
    const sydDxb = createCurvedPath(AIRPORTS.SYD, AIRPORTS.DXB);
    L.polyline(sydDxb, { color: '#94a3b8', weight: 2, dashArray: '5, 10' }).addTo(map);

    // Dubai to Prague
    const dxbPrg = createCurvedPath(AIRPORTS.DXB, AIRPORTS.PRG);
    L.polyline(dxbPrg, { color: '#94a3b8', weight: 2, dashArray: '5, 10' }).addTo(map);

    // Add airport markers
    Object.values(AIRPORTS).forEach(airport => {
        L.circleMarker([airport.lat, airport.lng], {
            radius: 6,
            fillColor: '#3b82f6',
            color: '#1e40af',
            weight: 2,
            fillOpacity: 0.8
        }).addTo(map).bindPopup(airport.name);
    });
}

function createCurvedPath(from, to) {
    // Create a curved path using a simple quadratic bezier
    const points = [];
    const midLat = (from.lat + to.lat) / 2;
    const midLng = (from.lng + to.lng) / 2;

    // Offset the midpoint to create a curve
    const latDiff = to.lat - from.lat;
    const lngDiff = to.lng - from.lng;
    const offset = Math.sqrt(latDiff * latDiff + lngDiff * lngDiff) * 0.2;

    const controlLat = midLat + offset;
    const controlLng = midLng;

    for (let t = 0; t <= 1; t += 0.05) {
        const lat = (1 - t) * (1 - t) * from.lat + 2 * (1 - t) * t * controlLat + t * t * to.lat;
        const lng = (1 - t) * (1 - t) * from.lng + 2 * (1 - t) * t * controlLng + t * t * to.lng;
        points.push([lat, lng]);
    }

    return points;
}

function updateMapPosition() {
    if (!currentStatus) return;

    const isFlying = currentStatus.flight_number != null;

    if (isFlying) {
        // Calculate position along flight path
        const from = AIRPORTS[currentStatus.flight_from];
        const to = AIRPORTS[currentStatus.flight_to];

        if (from && to) {
            const start = new Date(currentStatus.start_time);
            const end = new Date(currentStatus.end_time);
            const now = new Date();

            let progress = 0;
            if (now >= start && now < end) {
                progress = (now - start) / (end - start);
            } else if (now >= end) {
                progress = 1;
            }

            // Get position along curved path
            const path = createCurvedPath(from, to);
            const pathIndex = Math.min(Math.floor(progress * (path.length - 1)), path.length - 1);
            const position = path[pathIndex];

            // Calculate bearing for plane rotation
            const nextIndex = Math.min(pathIndex + 1, path.length - 1);
            const bearing = calculateBearing(path[pathIndex], path[nextIndex]);

            updatePlaneMarker(familyMap, position, bearing, 'plane-family');
            updatePlaneMarker(kidsMap, position, bearing, 'plane-kids');

            // Pan maps to show plane
            familyMap.setView(position, familyMap.getZoom());
            kidsMap.setView(position, kidsMap.getZoom());
        }
    } else if (currentStatus.lat && currentStatus.lng) {
        // Show pin at fixed location
        const position = [currentStatus.lat, currentStatus.lng];

        updatePinMarker(familyMap, position, 'pin-family');
        updatePinMarker(kidsMap, position, 'pin-kids');

        familyMap.setView(position, 10);
        kidsMap.setView(position, 6);
    }
}

function updatePlaneMarker(map, position, bearing, id) {
    // Remove existing marker
    map.eachLayer(layer => {
        if (layer.options && layer.options.id === id) {
            map.removeLayer(layer);
        }
    });

    // Create plane icon
    const planeIcon = L.divIcon({
        html: `<div style="font-size: 32px; transform: rotate(${bearing}deg);">✈️</div>`,
        className: 'plane-marker',
        iconSize: [40, 40],
        iconAnchor: [20, 20]
    });

    L.marker(position, { icon: planeIcon, id: id }).addTo(map);
}

function updatePinMarker(map, position, id) {
    // Remove existing marker
    map.eachLayer(layer => {
        if (layer.options && layer.options.id === id) {
            map.removeLayer(layer);
        }
    });

    // Create pin icon
    const pinIcon = L.divIcon({
        html: '<div style="font-size: 32px;">📍</div>',
        className: 'pin-marker',
        iconSize: [40, 40],
        iconAnchor: [20, 40]
    });

    L.marker(position, { icon: pinIcon, id: id }).addTo(map);
}

function calculateBearing(from, to) {
    const lat1 = from[0] * Math.PI / 180;
    const lat2 = to[0] * Math.PI / 180;
    const dLng = (to[1] - from[1]) * Math.PI / 180;

    const y = Math.sin(dLng) * Math.cos(lat2);
    const x = Math.cos(lat1) * Math.sin(lat2) - Math.sin(lat1) * Math.cos(lat2) * Math.cos(dLng);

    let bearing = Math.atan2(y, x) * 180 / Math.PI;
    bearing = (bearing + 360) % 360;

    // Adjust for plane emoji orientation (it points right by default)
    return bearing - 90;
}

// =============================================================================
// REFRESH ON VISIBILITY CHANGE
// =============================================================================

document.addEventListener('visibilitychange', () => {
    if (!document.hidden) {
        updateStatus();
        updateClocks();
        updateCountdown();
        loadWeather();
    }
});
