const notificationRepo = require('../repositories/NotificationRepository');
const socketService = require('./socketService');
const logger = require('../config/logger');

class NotificationService {
    async getNotifications(userId) {
        const [notifications, unreadCount] = await Promise.all([
            notificationRepo.findMany({ userId }),
            notificationRepo.countUnread(userId)
        ]);
        return { notifications, unreadCount };
    }

    async createNotification(data) {
        const { userId, title, message, type, entityType, entityId } = data;
        
        try {
            const notification = await notificationRepo.create({
                userId,
                title,
                message,
                type,
                entityType,
                entityId
            });

            // Emit real-time event to the specific user room
            socketService.emitEvent('NEW_NOTIFICATION', notification, `user_${userId}`);
            
            return notification;
        } catch (error) {
            logger.error(`Error creating notification: ${error.message}`);
            throw error;
        }
    }

    async markAsRead(id, userId) {
        return notificationRepo.update(id, {
            isRead: true,
            readAt: new Date()
        });
    }

    async markAllRead(userId) {
        return notificationRepo.markAllAsRead(userId);
    }

    /**
     * Helper to notify multiple users or roles
     * @param {Object} options { role, userIds, title, message, ... }
     */
    async notify(options) {
        const { role, userIds, ...data } = options;
        
        if (userIds && userIds.length > 0) {
            return Promise.all(userIds.map(id => this.createNotification({ ...data, userId: id })));
        }
    }

    /**
     * Notify all users with specific roles
     * @param {Array} roles Array of roles e.g. ['STUDENT', 'TEACHER']
     * @param {Object} notificationData { title, message, ... }
     */
    async notifyRoles(roles, notificationData) {
        const prisma = require('../config/database');
        
        try {
            // 1. Find all users with these roles
            const users = await prisma.user.findMany({
                where: {
                    role: { in: roles },
                    isActive: true
                },
                select: { id: true, role: true }
            });

            if (users.length === 0) return;

            // 2. Create individual notifications for each user
            // In a large school, using createMany would be better, but we want to trigger individual socket events 
            // OR we can createMany and then emit once to the role rooms.
            
            const notificationRecords = users.map(user => ({
                ...notificationData,
                userId: user.id,
                isRead: false
            }));

            // Use createMany for efficiency if supported by the provider
            await prisma.notification.createMany({
                data: notificationRecords
            });

            // 3. Emit real-time event to role-specific rooms to notify online users
            const socketPayload = {
                ...notificationData,
                id: `realtime_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`,
                isRead: false,
                createdAt: new Date().toISOString()
            };

            roles.forEach(role => {
                socketService.emitEvent('NEW_NOTIFICATION', socketPayload, `dashboard_${role}`);
            });

            // Also emit to ALL room if it's a general announcement
            if (roles.includes('ALL')) {
                socketService.emitEvent('NEW_NOTIFICATION', socketPayload, 'dashboard_ALL');
            }

            logger.info(`Bulk notifications created for ${users.length} users in roles: ${roles.join(', ')}`);
        } catch (error) {
            logger.error(`Error in notifyRoles: ${error.message}`);
        }
    }
}

module.exports = new NotificationService();
