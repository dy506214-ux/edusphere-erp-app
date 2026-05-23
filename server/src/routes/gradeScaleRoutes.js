const express = require('express');
const {
    getGradeScales,
    createGradeScale,
    updateGradeScale,
    deleteGradeScale,
} = require('../controllers/gradeScaleController');
const { authMiddleware, requireRole } = require('../middleware/auth');

const router = express.Router();

router.use(authMiddleware);

router.get('/', getGradeScales);
router.post('/', requireRole('SUPER_ADMIN', 'ADMIN'), createGradeScale);
router.put('/:id', requireRole('SUPER_ADMIN', 'ADMIN'), updateGradeScale);
router.delete('/:id', requireRole('SUPER_ADMIN', 'ADMIN'), deleteGradeScale);

module.exports = router;
