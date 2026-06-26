const express = require('express');
const {
  getBooks,
  getBook,
  createBook,
  updateBook,
  issueBook,
  returnBook,
  renewBook,
  reserveBook,
  getReservations,
  getBookIssues,
  getOverdueBooks,
} = require('../controllers/libraryController');
const { authMiddleware, requireRole } = require('../middleware/auth');

const router = express.Router();

router.use(authMiddleware);

// Book management
router.get('/books', getBooks);
router.get('/books/:id', getBook);
router.post('/books', requireRole('SUPER_ADMIN', 'ADMIN', 'LIBRARIAN'), createBook);
router.put('/books/:id', requireRole('SUPER_ADMIN', 'ADMIN', 'LIBRARIAN'), updateBook);

// Book issue/return/renewal
router.post('/issue', requireRole('SUPER_ADMIN', 'ADMIN', 'LIBRARIAN'), issueBook);
router.post('/return', requireRole('SUPER_ADMIN', 'ADMIN', 'LIBRARIAN'), returnBook);
router.post('/renew', requireRole('SUPER_ADMIN', 'ADMIN', 'LIBRARIAN'), renewBook);

// Reservations
router.post('/reserve', requireRole('SUPER_ADMIN', 'ADMIN', 'LIBRARIAN', 'STUDENT', 'TEACHER'), reserveBook);
router.get('/reservations', requireRole('SUPER_ADMIN', 'ADMIN', 'LIBRARIAN'), getReservations);

// Reports
router.get('/issues', getBookIssues);
router.get('/overdue', getOverdueBooks);

module.exports = router;
