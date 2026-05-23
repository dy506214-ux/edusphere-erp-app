const express = require('express');
const {
    getTerms,
    createTerm,
    updateTerm,
    deleteTerm,
} = require('../controllers/termController');
const { authMiddleware, requireRole } = require('../middleware/auth');

const router = express.Router();

router.use(authMiddleware);

router.get('/', getTerms);
router.post('/', requireRole('SUPER_ADMIN', 'ADMIN'), createTerm);
router.put('/:id', requireRole('SUPER_ADMIN', 'ADMIN'), updateTerm);
router.delete('/:id', requireRole('SUPER_ADMIN', 'ADMIN'), deleteTerm);

module.exports = router;
