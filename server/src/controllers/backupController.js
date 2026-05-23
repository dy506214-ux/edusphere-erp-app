const backupService = require('../services/BackupService');
const asyncHandler = require('../utils/asyncHandler');
const logger = require('../config/logger');

/**
 * Trigger a manual backup
 * POST /api/admin/backups/trigger
 */
exports.manualBackup = asyncHandler(async (req, res) => {
    logger.info(`Manual backup triggered by user: ${req.user.id}`);
    
    // Start backup in background to avoid timeout
    // (though for small DBs this is fast)
    try {
        const result = await backupService.performFullBackup();
        
        res.status(200).json({
            success: true,
            message: 'Backup completed successfully',
            data: {
                filename: result.filename,
                timestamp: result.timestamp,
                cloudUrl: result.cloudUrl
            }
        });
    } catch (error) {
        logger.error('Manual Backup Error:', error);
        res.status(500).json({
            success: false,
            message: 'Backup failed: ' + error.message
        });
    }
});

/**
 * Get backup history
 * GET /api/admin/backups/history
 */
exports.getBackupHistory = asyncHandler(async (req, res) => {
    const backups = await backupService.getLocalBackups();
    
    res.status(200).json({
        success: true,
        data: backups
    });
});
