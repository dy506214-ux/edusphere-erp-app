const prisma = require('../config/database');
const AppError = require('../utils/AppError');
const logger = require('../config/logger');

class TimetableService {
    /**
     * Get or Create Timetable Configuration for a Class
     */
    async getOrCreateConfig(classId, academicYearId, data = {}) {
        const existing = await prisma.timetableConfig.findUnique({
            where: { classId }
        });

        if (existing) {
            if (Object.keys(data).length > 0) {
                return prisma.timetableConfig.update({
                    where: { classId },
                    data
                });
            }
            return existing;
        }

        // Create default config if not exists
        return prisma.timetableConfig.create({
            data: {
                classId,
                academicYearId,
                startTime: data.startTime || "08:00",
                endTime: data.endTime || "14:00",
                periodDuration: data.periodDuration || 45,
                lunchStartTime: data.lunchStartTime || "12:00",
                lunchDuration: data.lunchDuration || 30,
                daysActive: data.daysActive || [1, 2, 3, 4, 5, 6],
                ...data
            }
        });
    }

    /**
     * Get or Create Timetable Record for a Class
     */
    async getOrCreateActiveTimetable(classId, name = "Main Schedule") {
        const existing = await prisma.timetable.findFirst({
            where: { classId, isActive: true },
            orderBy: { createdAt: 'desc' }
        });

        if (existing) return existing;

        // Try to get current academic year for the new timetable
        const academicYear = await prisma.academicYear.findFirst({ where: { isCurrent: true } });

        if (!academicYear) {
            throw new Error('Current academic year not found. Please set an academic year as current first.');
        }

        return prisma.timetable.create({
            data: {
                name,
                classId,
                academicYearId: academicYear.id,
                effectiveFrom: new Date(),
                isActive: true
            }
        });
    }

    /**
     * Generate baseline slots (Skeleton with Lunch/Breaks)
     */
    async generateBaseline(timetableId, configId, classId = null) {
        let finalTimetableId = timetableId;

        if (!finalTimetableId && classId) {
            const timetable = await this.getOrCreateActiveTimetable(classId);
            finalTimetableId = timetable.id;
        }

        if (!finalTimetableId) throw new AppError('Timetable ID or Class ID is required', 400);

        const config = await prisma.timetableConfig.findUnique({
            where: { id: configId },
            include: { class: { include: { sections: true } } }
        });

        if (!config) throw new AppError('Configuration not found', 404);

        const timetable = await prisma.timetable.findUnique({
            where: { id: finalTimetableId }
        });

        if (!timetable) throw new AppError('Timetable not found', 404);

        const sections = config.class.sections;
        const slotsToCreate = [];

        for (const day of config.daysActive) {
            let currentTime = config.startTime;
            let periodCount = 1;

            while (this._timeToMinutes(currentTime) < this._timeToMinutes(config.endTime)) {
                const startTimeStr = currentTime;
                const endTimeStr = this._addMinutes(currentTime, config.periodDuration);
                
                // 1. Check if we have hit the Lunch Break
                const isLunchStart = this._timeToMinutes(currentTime) === this._timeToMinutes(config.lunchStartTime);
                const overlapsLunch = this._isInside(currentTime, config.lunchStartTime, config.lunchDuration) || 
                                     (this._timeToMinutes(startTimeStr) < this._timeToMinutes(config.lunchStartTime) && 
                                      this._timeToMinutes(endTimeStr) > this._timeToMinutes(config.lunchStartTime));

                if (isLunchStart || overlapsLunch) {
                    // Create Lunch Slot if not already passed
                    if (this._timeToMinutes(currentTime) <= this._timeToMinutes(config.lunchStartTime)) {
                        for (const section of sections) {
                            slotsToCreate.push({
                                timetableId: finalTimetableId,
                                sectionId: section.id,
                                dayOfWeek: day,
                                startTime: config.lunchStartTime,
                                endTime: this._addMinutes(config.lunchStartTime, config.lunchDuration),
                                period: 0,
                                isSpecialSlot: true,
                                specialSlotName: 'Lunch Break',
                                durationMinutes: config.lunchDuration
                            });
                        }
                    }
                    // Move time to after lunch and continue
                    currentTime = this._addMinutes(config.lunchStartTime, config.lunchDuration);
                    continue; 
                }

                // 2. Create Regular Period
                for (const section of sections) {
                    slotsToCreate.push({
                        timetableId: finalTimetableId,
                        sectionId: section.id,
                        dayOfWeek: day,
                        startTime: startTimeStr,
                        endTime: endTimeStr,
                        period: periodCount,
                        durationMinutes: config.periodDuration
                    });
                }

                currentTime = endTimeStr;
                periodCount++;

                if (periodCount > 15) break; 
            }
        }

        // Delete existing slots and recreation
        await prisma.timetableSlot.deleteMany({ where: { timetableId: finalTimetableId } });
        
        return prisma.timetableSlot.createMany({
            data: slotsToCreate
        });
    }

    /**
     * Validate and Add / Update a Slot
     */
    async updateSlot(slotId, data) {
        const { teacherId, subjectId, roomId } = data;

        const slot = await prisma.timetableSlot.findUnique({
            where: { id: slotId },
            include: { timetable: true }
        });

        if (!slot) throw new AppError('Slot not found', 404);

        // Conflict Detection
        if (teacherId) {
            const conflict = await this._checkTeacherConflict(teacherId, slot.dayOfWeek, slot.startTime, slot.endTime, slotId);
            if (conflict) throw new AppError(`Teacher is already booked for Period ${conflict.period} in Class ${conflict.timetable.classId}`, 400);
        }

        if (roomId) {
            const conflict = await this._checkRoomConflict(roomId, slot.dayOfWeek, slot.startTime, slot.endTime, slotId);
            if (conflict) throw new AppError('Room is already occupied during this time', 400);
        }

        return prisma.timetableSlot.update({
            where: { id: slotId },
            data: {
                teacherId,
                subjectId,
                roomId,
                isSpecialSlot: false
            }
        });
    }

    // Helper: Verify Teacher Availability
    async _checkTeacherConflict(teacherId, day, start, end, excludeId) {
        return prisma.timetableSlot.findFirst({
            where: {
                teacherId,
                dayOfWeek: day,
                id: { not: excludeId },
                // Overlap logical check: (ExistingStart < NewEnd) AND (ExistingEnd > NewStart)
                startTime: { lt: end },
                endTime: { gt: start }
            },
            include: { timetable: { select: { classId: true } } }
        });
    }

    // Helper: Verify Room Availability
    async _checkRoomConflict(roomId, day, start, end, excludeId) {
        return prisma.timetableSlot.findFirst({
            where: {
                roomId,
                dayOfWeek: day,
                id: { not: excludeId },
                startTime: { lt: end },
                endTime: { gt: start }
            }
        });
    }

    // Utils
    _timeToMinutes(time) {
        const [hh, mm] = time.split(':').map(Number);
        return hh * 60 + mm;
    }

    _minutesToTime(mins) {
        const hh = Math.floor(mins / 60).toString().padStart(2, '0');
        const mm = (mins % 60).toString().padStart(2, '0');
        return `${hh}:${mm}`;
    }

    _addMinutes(time, mins) {
        return this._minutesToTime(this._timeToMinutes(time) + mins);
    }

    _isInside(time, start, duration) {
        const t = this._timeToMinutes(time);
        const s = this._timeToMinutes(start);
        const e = s + duration;
        return t >= s && t < e;
    }
}

module.exports = new TimetableService();
