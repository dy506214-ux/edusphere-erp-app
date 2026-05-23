const cron = require('node-cron');
const backupService = require('../services/BackupService');
const logger = require('./logger');

/**
 * Initialize all scheduled tasks (Cron Jobs)
 */
const initScheduler = () => {
    logger.info('Initializing System Scheduler...');

    /**
     * Nightly Database Backup (02:00 AM)
     * Every day at 2:00 AM
     */
    cron.schedule('0 2 * * *', async () => {
        logger.info('Running Scheduled Nightly Backup...');
        try {
            const result = await backupService.performFullBackup();
            logger.info(`Scheduled backup success: ${result.filename}`);
        } catch (error) {
            logger.error('Scheduled backup failure:', error);
        }
    });

    /**
     * Weekly Log Archiving (Sunday 04:00 AM)
     * Optional: Move old logs to Cloudinary/S3
     */
    cron.schedule('0 4 * * 0', async () => {
        logger.info('Running Weekly Log Cleanup/Archive...');
        // Implement if needed for very large logs
    });

    logger.info('Scheduler Service: OK (Jobs scheduled: Backup [Daily], Logs [Weekly])');
};

module.exports = { initScheduler };
