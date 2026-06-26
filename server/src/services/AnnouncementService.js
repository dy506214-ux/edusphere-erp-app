const { getSchoolDate, getStartOfDay } = require('../utils/dateUtils');
const announcementRepo = require('../repositories/AnnouncementRepository');
const { emitEvent } = require('./socketService');
const notificationService = require('./NotificationService');
const NotFoundError = require('../errors/NotFoundError');
const ValidationError = require('../errors/ValidationError');

class AnnouncementService {
    async getAnnouncements(filters) {
        const { targetAudience, isPublished, page = 1, limit = 25 } = filters;

        const where = {};
        if (targetAudience) where.targetAudience = { has: targetAudience };
        if (isPublished !== undefined) where.isPublished = isPublished === 'true';

        const skip = (parseInt(page) - 1) * parseInt(limit);
        const [announcements, total] = await Promise.all([
            announcementRepo.findAnnouncements(where, skip, parseInt(limit)),
            announcementRepo.countAnnouncements(where)
        ]);

        const formattedAnnouncements = announcements.map(a => this._formatAnnouncement(a));

        return {
            announcements: formattedAnnouncements,
            pagination: {
                total,
                page: parseInt(page),
                limit: parseInt(limit),
                totalPages: Math.ceil(total / parseInt(limit)),
            },
        };
    }

    async getAnnouncementById(id) {
        const announcement = await announcementRepo.findAnnouncementById(id);
        if (!announcement) throw new NotFoundError('Announcement not found');
        return this._formatAnnouncement(announcement);
    }

    async createAnnouncement(data, userId) {
        const { title, content, targetAudience, priority, expiryDate } = data;

        if (!title || !content) {
            throw new ValidationError('Required fields (title, content) missing');
        }

        const audienceArray = targetAudience && targetAudience !== 'ALL' ? [targetAudience] : [];
        const finalPriority = priority === 'MEDIUM' ? 'NORMAL' : (priority || 'NORMAL');

        const announcement = await announcementRepo.createAnnouncement({
            title,
            content,
            targetAudience: audienceArray,
            classIds: [],
            priority: finalPriority,
            isPublished: true,
            publishedAt: getSchoolDate(),
            expiresAt: expiryDate ? new Date(expiryDate) : null,
            createdBy: userId,
        });

        emitEvent('ANNOUNCEMENT_CREATED', announcement, 'ALL');

        // Create persistent notifications for the target audience
        const mappedRoles = [];
        if (!targetAudience || targetAudience === 'ALL' || (Array.isArray(targetAudience) && targetAudience.includes('ALL'))) {
            mappedRoles.push('STUDENT', 'TEACHER', 'PARENT', 'ACCOUNTANT', 'LIBRARIAN', 'HR_MANAGER', 'INVENTORY_MANAGER', 'ADMISSION_MANAGER', 'ADMIN');
        } else {
            const audiences = Array.isArray(targetAudience) ? targetAudience : [targetAudience];
            audiences.forEach(aud => {
                if (aud === 'STUDENTS') mappedRoles.push('STUDENT');
                if (aud === 'TEACHERS') mappedRoles.push('TEACHER');
                if (aud === 'PARENTS') mappedRoles.push('PARENT');
                if (aud === 'STAFF') mappedRoles.push('ACCOUNTANT', 'LIBRARIAN', 'HR_MANAGER', 'INVENTORY_MANAGER', 'ADMISSION_MANAGER');
            });
        }

        if (mappedRoles.length > 0) {
            notificationService.notifyRoles(mappedRoles, {
                title: `New Announcement: ${title}`,
                message: content.substring(0, 100) + (content.length > 100 ? '...' : ''),
                type: 'ANNOUNCEMENT',
                entityType: 'ANNOUNCEMENT',
                entityId: announcement.id
            });
        }

        return announcement;
    }

    async updateAnnouncement(id, updates) {
        const announcement = await announcementRepo.findAnnouncementById(id);
        if (!announcement) throw new NotFoundError('Announcement not found');

        const allowedUpdates = ['title', 'content', 'targetAudience', 'priority', 'expiryDate', 'isActive'];
        const updateData = {};

        Object.keys(updates).forEach((key) => {
            if (allowedUpdates.includes(key)) {
                if (key === 'expiryDate') {
                    updateData.expiresAt = updates[key] ? new Date(updates[key]) : null;
                } else if (key === 'targetAudience') {
                    updateData.targetAudience = updates[key] && updates[key] !== 'ALL' ? [updates[key]] : [];
                } else if (key === 'isActive') {
                    updateData.isPublished = updates[key];
                } else if (key === 'priority') {
                    updateData[key] = updates[key] === 'MEDIUM' ? 'NORMAL' : updates[key];
                } else {
                    updateData[key] = updates[key];
                }
            }
        });

        const updatedAnnouncement = await announcementRepo.updateAnnouncement(id, updateData);
        emitEvent('ANNOUNCEMENT_UPDATED', updatedAnnouncement, 'ALL');
        return updatedAnnouncement;
    }

    async deleteAnnouncement(id) {
        await announcementRepo.deleteAnnouncement(id);
        emitEvent('ANNOUNCEMENT_DELETED', { id }, 'ALL');
    }

    async getActiveAnnouncementsForUser(user) {
        try {
            const { role: userRole } = user;
            if (!userRole) return { announcements: [] };

            const roleMap = {
                'STUDENT': 'STUDENTS',
                'TEACHER': 'TEACHERS',
                'PARENT': 'PARENTS',
                'ACCOUNTANT': 'STAFF',
                'LIBRARIAN': 'STAFF',
                'HR_MANAGER': 'STAFF',
                'INVENTORY_MANAGER': 'STAFF',
            };

            const isAdminRole = ['ADMIN', 'SUPER_ADMIN', 'ADMISSION_MANAGER'].includes(userRole);
            const mappedRole = roleMap[userRole] || userRole;
            const now = getSchoolDate();

            const announcements = await announcementRepo.findActiveAnnouncements({
                isPublished: true,
                OR: [
                    { expiresAt: null },
                    { expiresAt: { gte: now } }
                ],
            });

            const filteredAnnouncements = announcements.filter(a => {
                if (isAdminRole) return true;
                
                // If no specific audience is targetted, it's for everyone
                if (!a.targetAudience || !Array.isArray(a.targetAudience) || a.targetAudience.length === 0) return true;
                
                return a.targetAudience.includes(mappedRole) || 
                       a.targetAudience.includes(userRole) || 
                       a.targetAudience.includes('ALL');
            });

            return { announcements: filteredAnnouncements.map(a => this._formatAnnouncement(a)) };
        } catch (error) {
            logger.error('Error in getActiveAnnouncementsForUser:', error);
            return { announcements: [] }; // Fallback to empty list instead of crashing
        }
    }

    _formatAnnouncement(a) {
        const audience = (a.targetAudience && Array.isArray(a.targetAudience)) 
            ? (a.targetAudience.length ? a.targetAudience : ['ALL']) 
            : ['ALL'];
            
        return {
            ...a,
            isActive: a.isPublished,
            targetAudience: audience,
            expiryDate: a.expiresAt
        };
    }
}

module.exports = new AnnouncementService();
