const prisma = require('../config/database');

/**
 * Repository for Announcement related database operations
 */
class AnnouncementRepository {
    async findAnnouncements(where, skip, take) {
        return prisma.announcement.findMany({
            where,
            skip,
            take,
            orderBy: { createdAt: 'desc' },
        });
    }

    async countAnnouncements(where) {
        return prisma.announcement.count({ where });
    }

    async findAnnouncementById(id) {
        return prisma.announcement.findUnique({ where: { id } });
    }

    async createAnnouncement(data) {
        return prisma.announcement.create({ data });
    }

    async updateAnnouncement(id, data) {
        return prisma.announcement.update({
            where: { id },
            data,
        });
    }

    async deleteAnnouncement(id) {
        return prisma.announcement.delete({ where: { id } });
    }

    async findActiveAnnouncements(where, take = 10) {
        return prisma.announcement.findMany({
            where,
            orderBy: [
                { createdAt: 'desc' },
                { priority: 'desc' },
            ],
            take,
        });
    }
}

module.exports = new AnnouncementRepository();
