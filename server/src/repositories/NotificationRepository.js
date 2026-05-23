const prisma = require('../config/database');

class NotificationRepository {
    async findMany(where, orderBy = { createdAt: 'desc' }, limit = 20) {
        return prisma.notification.findMany({
            where,
            orderBy,
            take: limit
        });
    }

    async countUnread(userId) {
        return prisma.notification.count({
            where: {
                userId,
                isRead: false
            }
        });
    }

    async update(id, data) {
        return prisma.notification.update({
            where: { id },
            data
        });
    }

    async create(data) {
        return prisma.notification.create({
            data
        });
    }

    async markAllAsRead(userId) {
        return prisma.notification.updateMany({
            where: { userId, isRead: false },
            data: { 
                isRead: true,
                readAt: new Date()
            }
        });
    }
}

module.exports = new NotificationRepository();
