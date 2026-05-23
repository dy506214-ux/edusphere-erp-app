const CalendarService = require('../services/CalendarService');

/**
 * Controller for Academic Calendar & Institutional Events
 */
class CalendarController {
    /**
     * @route POST /api/calendar
     * @access ADMIN, SUPER_ADMIN
     */
    async createEvent(req, res) {
        const event = await CalendarService.createEvent(req.body, req.user.id);
        res.status(201).json({ success: true, event });
    }

    /**
     * @route GET /api/calendar
     * @access PUBLIC (Authenticated)
     */
    async getEvents(req, res) {
        const { startDate, endDate } = req.query;
        // Default to current month if no dates provided
        const start = startDate || new Date(new Date().getFullYear(), new Date().getMonth(), 1);
        const end = endDate || new Date(new Date().getFullYear(), new Date().getMonth() + 1, 0);
        
        const events = await CalendarService.getEvents(start, end);
        res.status(200).json({ success: true, events });
    }

    /**
     * @route GET /api/calendar/upcoming
     * @access PUBLIC (Authenticated)
     */
    async getUpcomingEvents(req, res) {
        const { limit } = req.query;
        const events = await CalendarService.getUpcomingEvents(parseInt(limit) || 5);
        res.status(200).json({ success: true, events });
    }

    /**
     * @route PATCH /api/calendar/:id
     * @access ADMIN, SUPER_ADMIN
     */
    async updateEvent(req, res) {
        const event = await CalendarService.updateEvent(req.params.id, req.body);
        res.status(200).json({ success: true, event });
    }

    /**
     * @route DELETE /api/calendar/:id
     * @access ADMIN, SUPER_ADMIN
     */
    async deleteEvent(req, res) {
        await CalendarService.deleteEvent(req.params.id);
        res.status(200).json({ success: true, message: 'Event deleted successfully' });
    }
}

module.exports = new CalendarController();
