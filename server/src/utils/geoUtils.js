/**
 * Geofencing utilities for QR scanner location validation.
 * No external dependencies — pure math (Haversine formula).
 */

/**
 * Calculates the distance in metres between two GPS coordinates
 * using the Haversine formula.
 *
 * @param {number} lat1 - Latitude of point 1 (scanner fixed location)
 * @param {number} lng1 - Longitude of point 1
 * @param {number} lat2 - Latitude of point 2 (scan device live GPS)
 * @param {number} lng2 - Longitude of point 2
 * @returns {number} Distance in metres
 */
const haversineDistance = (lat1, lng1, lat2, lng2) => {
    const R = 6371000; // Earth radius in metres
    const toRad = (deg) => (deg * Math.PI) / 180;

    const dLat = toRad(lat2 - lat1);
    const dLng = toRad(lng2 - lng1);

    const a =
        Math.sin(dLat / 2) ** 2 +
        Math.cos(toRad(lat1)) * Math.cos(toRad(lat2)) * Math.sin(dLng / 2) ** 2;

    return R * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
};

/**
 * Checks whether a scan device is within the allowed geofence radius.
 *
 * @param {object} scanner - QRScanner record with latitude, longitude, geofenceRadius
 * @param {number|null} scanLat - Device's live latitude
 * @param {number|null} scanLng - Device's live longitude
 * @returns {{ valid: boolean, distanceMetres: number|null, reason: string|null }}
 */
const checkGeofence = (scanner, scanLat, scanLng) => {
    // If scanner has no GPS configured, geofence is not enforced
    if (
        scanner.latitude == null ||
        scanner.longitude == null ||
        scanLat == null ||
        scanLng == null
    ) {
        return { valid: true, distanceMetres: null, reason: null };
    }

    const dist = haversineDistance(
        scanner.latitude,
        scanner.longitude,
        scanLat,
        scanLng
    );

    const distRounded = Math.round(dist);

    if (dist > scanner.geofenceRadius) {
        return {
            valid: false,
            distanceMetres: distRounded,
            reason: `Device is ${distRounded}m away. Allowed radius: ${scanner.geofenceRadius}m.`,
        };
    }

    return { valid: true, distanceMetres: distRounded, reason: null };
};

module.exports = { haversineDistance, checkGeofence };
