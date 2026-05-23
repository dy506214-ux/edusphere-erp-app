const axios = require('axios');

const API_URL = 'http://localhost:5001/api';
const TOKEN = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpZCI6InRlc3QtYWRtaW4taWQiLCJyb2xlIjoiU1VQRVJfQURNSU4iLCJlbWFpbCI6ImFkbWluQGVkdXNwaGVyZS5jb20iLCJpYXQiOjE3NzYzMzQ0NDAsImV4cCI6MTc3NjMzODA0MH0.B0gvUQgxvxo7FXHDDlUknDOnZZu-7U6-0cDNpHBpMt8';

const TRIP_ID = process.argv[2];

if (!TRIP_ID) {
    console.error('Usage: node scripts/simulate-trip.js <trip_id>');
    process.exit(1);
}

async function updateLocation(lat, lng) {
    try {
        const response = await axios.post(`${API_URL}/transport/trips/update-location`, {
            tripId: TRIP_ID,
            latitude: lat,
            longitude: lng,
            speed: 40 + Math.random() * 10
        }, {
            headers: { Authorization: `Bearer ${TOKEN}` }
        });
        console.log(`[SIM] Location Update: lat=${lat.toFixed(6)}, lng=${lng.toFixed(6)} | Status: ${response.data.success ? 'SUCCESS' : 'FAILED'}`);
    } catch (err) {
        console.error('[SIM] Error:', err.response?.data?.message || err.message);
        // If trip not found, we can't continue
        if (err.response?.status === 404) {
            console.error('Ending simulation: Trip ID not found in database.');
            process.exit(1);
        }
    }
}

async function simulate() {
    let lat = 17.4483;
    let lng = 78.3915;

    console.log(`-------------------------------------------`);
    console.log(`🚍 STARTING FLEET TRACKING SIMULATION`);
    console.log(`📍 Initial Point: ${lat}, ${lng}`);
    console.log(`🆔 Target Trip: ${TRIP_ID}`);
    console.log(`-------------------------------------------`);
    
    for (let i = 0; i < 50; i++) {
        // Simulating slow movement
        lat += 0.0002;
        lng += 0.0002;
        await updateLocation(lat, lng);
        await new Promise(r => setTimeout(r, 2000)); // Sync interval
    }
}

simulate();
