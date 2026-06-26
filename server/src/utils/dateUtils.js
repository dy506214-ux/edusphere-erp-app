/**
 * Global Date & Timezone Utilities
 * Anchors all institutional calculations to the school's operational timezone.
 */

// Default to India Standard Time (IST) if not configured
const APP_TIMEZONE = process.env.APP_TIMEZONE || 'Asia/Kolkata';

/**
 * Returns a Date object representing the CURRENT time in the school's local timezone.
 * Useful for marking attendance and logging events consistently across international servers.
 * @returns {Date}
 */
const getSchoolDate = () => {
    // Current UTC time
    const now = new Date();
    
    // Format to school timezone string and parse back to Date
    const tzString = now.toLocaleString('en-US', { timeZone: APP_TIMEZONE });
    return new Date(tzString);
};

/**
 * Returns a Date object representing the START of the current local day (00:00:00).
 * @param {Date|string|null} date - Optional date to normalize. Defaults to now.
 * @returns {Date}
 */
const getStartOfDay = (date = null) => {
    const d = date ? new Date(date) : getSchoolDate();
    d.setHours(0, 0, 0, 0);
    return d;
};

/**
 * Returns a Date object representing the END of the current local day (23:59:59).
 * @param {Date|string|null} date - Optional date to normalize. Defaults to now.
 * @returns {Date}
 */
const getEndOfDay = (date = null) => {
    const d = date ? new Date(date) : getSchoolDate();
    d.setHours(23, 59, 59, 999);
    return d;
};

/**
 * Checks if a given time is between two HH:mm strings.
 * @param {string} time - Current time HH:mm
 * @param {string} start - Start time HH:mm
 * @param {string} end - End time HH:mm
 */
const isTimeBetween = (time, start, end) => {
    return time >= start && time <= end;
};

module.exports = {
    getSchoolDate,
    getStartOfDay,
    getEndOfDay,
    isTimeBetween,
    APP_TIMEZONE
};
