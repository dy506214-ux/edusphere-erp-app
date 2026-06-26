const prisma = require('../config/database');
const { getStartOfDay } = require('../utils/dateUtils');
const AppError = require('../utils/AppError');

/**
 * Service for Academic Calendar & Institutional Events
 */
class CalendarService {
    /**
     * Create a new calendar event or holiday
     */
    async createEvent(data, userId) {
        const { date, title, type, isWorkingDay } = data;
        
        // Normalize date to start of day
        const eventDate = getStartOfDay(date);

        // Sanitize payload: Remove fields not present in Prisma schema
        const sanitizedData = { ...data };
        delete sanitizedData.isPublic; // Remove frontend-only field
        
        // Remove empty strings for optional fields to prevent Prisma crashes
        if (sanitizedData.startTime === '') delete sanitizedData.startTime;
        if (sanitizedData.endTime === '') delete sanitizedData.endTime;

        return prisma.schoolCalendar.create({
            data: {
                ...sanitizedData,
                date: eventDate,
                createdById: userId,
                isWorkingDay: type === 'HOLIDAY' ? false : (isWorkingDay ?? true)
            }
        });
    }

    /**
     * Get all events for a date range
     */
    async getEvents(startDate, endDate) {
        return prisma.schoolCalendar.findMany({
            where: {
                date: {
                    gte: getStartOfDay(startDate),
                    lte: getStartOfDay(endDate)
                }
            },
            orderBy: { date: 'asc' },
            include: {
                createdBy: {
                    select: { firstName: true, lastName: true, role: true }
                }
            }
        });
    }

    /**
     * Check if a specific date is a non-working day (Holiday)
     */
    async isNonWorkingDay(date) {
        const day = getStartOfDay(date);
        
        // 1. Check Weekend (Saturday/Sunday) - Standard assumption
        const dayOfWeek = day.getDay();
        if (dayOfWeek === 0 || dayOfWeek === 6) return true;

        // 2. Check Database for Holidays
        const holiday = await prisma.schoolCalendar.findFirst({
            where: {
                date: day,
                isWorkingDay: false
            }
        });

        return !!holiday;
    }

    /**
     * Get upcoming events (for Dashboard Ticker)
     */
    async getUpcomingEvents(limit = 5) {
        const today = getStartOfDay();
        return prisma.schoolCalendar.findMany({
            where: {
                date: { gte: today }
            },
            orderBy: { date: 'asc' },
            take: limit
        });
    }

    /**
     * Delete an event
     */
    async deleteEvent(id) {
        return prisma.schoolCalendar.delete({
            where: { id }
        });
    }

    /**
     * Update an event
     */
    async updateEvent(id, data) {
        if (data.date) data.date = getStartOfDay(data.date);
        
        // Sanitize payload: Remove fields not present in Prisma schema
        const sanitizedData = { ...data };
        delete sanitizedData.id;
        delete sanitizedData.isPublic;
        
        // Sanitize optional DateTime fields (remove empty strings)
        if (sanitizedData.startTime === '') delete sanitizedData.startTime;
        if (sanitizedData.endTime === '') delete sanitizedData.endTime;

        return prisma.schoolCalendar.update({
            where: { id },
            data: sanitizedData
        });
    }
}

module.exports = new CalendarService();
