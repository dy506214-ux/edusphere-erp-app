const prisma = require('../config/database');
const { uploadToCloudinary } = require('../config/cloudinary');
const fs = require('fs');
const path = require('path');
const archiver = require('archiver');
const logger = require('../config/logger');

/**
 * BackupService handles the core logic for data exports.
 */
class BackupService {
    constructor() {
        this.backupDir = path.join(__dirname, '..', '..', 'backups');
        this.tempDir = path.join(this.backupDir, 'temp_backup');
    }

    /**
     * Prepare backup directories
     */
    async #prepareDirs() {
        if (!fs.existsSync(this.backupDir)) {
            fs.mkdirSync(this.backupDir, { recursive: true });
        }
        if (fs.existsSync(this.tempDir)) {
            fs.rmSync(this.tempDir, { recursive: true, force: true });
        }
        fs.mkdirSync(this.tempDir, { recursive: true });
    }

    /**
     * Get all data from all Prisma models
     */
    async #exportTables() {
        // Models are listed in prisma client directly as properties
        const modelNames = Object.keys(prisma).filter(key => 
            !key.startsWith('_') && 
            !key.startsWith('$') &&
            typeof prisma[key] === 'object' && 
            prisma[key].findMany
        );

        logger.info(`Starting data export for ${modelNames.length} tables...`);

        for (const model of modelNames) {
            try {
                const data = await prisma[model].findMany();
                fs.writeFileSync(
                    path.join(this.tempDir, `${model}.json`),
                    JSON.stringify(data, null, 2)
                );
                // logger.debug(`${model}: Exported ${data.length} records`);
            } catch (error) {
                logger.error(`Error exporting table ${model}:`, error);
                // Continue with other tables
            }
        }
    }

    /**
     * Create ZIP archive
     */
    async #archiveData(archiveName) {
        return new Promise((resolve, reject) => {
            const output = fs.createWriteStream(path.join(this.backupDir, archiveName));
            const archive = archiver('zip', { zlib: { level: 9 } });

            output.on('close', resolve);
            archive.on('error', reject);

            archive.pipe(output);
            archive.directory(this.tempDir, false);
            archive.finalize();
        });
    }

    /**
     * Perform a full backup and upload to Cloudinary
     */
    async performFullBackup() {
        const timestamp = new Date().toISOString().replace(/[:.]/g, '-');
        const filename = `edusphere_backup_${timestamp}.zip`;
        const localPath = path.join(this.backupDir, filename);

        try {
            await this.#prepareDirs();
            await this.#exportTables();
            await this.#archiveData(filename);

            logger.info(`Local backup created: ${filename}`);

            // Upload to Cloudinary (as raw)
            const uploadResult = await uploadToCloudinary(localPath, 'backup/automatic');
            
            logger.info(`Cloud backup completed: ${uploadResult.secure_url}`);

            // Cleanup temp dir
            fs.rmSync(this.tempDir, { recursive: true, force: true });

            return {
                success: true,
                filename,
                localPath,
                cloudUrl: uploadResult.secure_url,
                timestamp: new Date().toISOString()
            };
        } catch (error) {
            logger.error('Full Backup Service Failure:', error);
            throw error;
        }
    }

    /**
     * List local backups
     */
    getLocalBackups() {
        if (!fs.existsSync(this.backupDir)) return [];
        return fs.readdirSync(this.backupDir)
            .filter(f => f.endsWith('.zip'))
            .map(f => {
                const stats = fs.statSync(path.join(this.backupDir, f));
                return {
                    name: f,
                    size: stats.size,
                    createdAt: stats.birthtime
                };
            })
            .sort((a, b) => b.createdAt - a.createdAt);
    }
}

module.exports = new BackupService();
