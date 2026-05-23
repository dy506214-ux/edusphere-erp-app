const prisma = require('../config/database');
const logger = require('../config/logger');

/**
 * Utility to get configuration values from the database with fallbacks to environment variables or defaults.
 * 
 * @param {string} key - The configuration key (e.g., 'school_start_time')
 * @param {any} fallback - The fallback value if not found in DB or Env
 * @returns {Promise<any>} The configuration value
 */
async function getConfigValue(key, fallback) {
    try {
        // 1. Try Database (SchoolBranding table)
        const config = await prisma.schoolBranding.findUnique({
            where: { key }
        });

        if (config && config.value !== undefined) {
            return config.value;
        }

        // 2. Try Environment Variables (upper-cased, e.g., 'SCHOOL_START_TIME')
        const envKey = key.toUpperCase();
        if (process.env[envKey] !== undefined) {
            return process.env[envKey];
        }

        // 3. Use provided fallback
        return fallback;
    } catch (error) {
        logger.error(`Error fetching config for ${key}:`, error);
        return fallback;
    }
}

module.exports = {
    getConfigValue
};
