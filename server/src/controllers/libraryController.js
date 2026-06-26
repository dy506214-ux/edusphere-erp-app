const libraryService = require('../services/LibraryService');
const asyncHandler = require('../utils/asyncHandler');

// Get all books with advanced filtering
const getBooks = asyncHandler(async (req, res) => {
  const result = await libraryService.getBooks(req.query);
  res.status(200).json({ 
    success: true,
    ...result 
  });
});

// Get single book with detailed history
const getBook = asyncHandler(async (req, res) => {
  const book = await libraryService.getBookById(req.params.id);
  res.status(200).json({ 
    success: true,
    book 
  });
});

// Create book
const createBook = asyncHandler(async (req, res) => {
  const book = await libraryService.createBook(req.body);
  res.status(201).json({ 
    success: true,
    message: 'Book created successfully', 
    book 
  });
});

// Update book
const updateBook = asyncHandler(async (req, res) => {
  const book = await libraryService.updateBook(req.params.id, req.body);
  res.status(200).json({ 
    success: true,
    message: 'Book updated successfully', 
    book 
  });
});

// Issue book
const issueBook = asyncHandler(async (req, res) => {
  const result = await libraryService.issueBook(req.body, req.user.userId);
  res.status(201).json({ 
    success: true,
    message: 'Book issued successfully', 
    issue: result 
  });
});

// Return book with condition tracking
const returnBook = asyncHandler(async (req, res) => {
  const result = await libraryService.returnBook(req.body, req.user.userId);
  res.status(200).json({ 
    success: true,
    message: 'Book returned successfully', 
    issue: result.updatedIssue, 
    fine: result.fine 
  });
});

// Renew book
const renewBook = asyncHandler(async (req, res) => {
  const updatedIssue = await libraryService.renewBook(req.body.issueId);
  res.status(200).json({ 
    success: true,
    message: 'Book renewed successfully', 
    issue: updatedIssue 
  });
});

// Reserve book
const reserveBook = asyncHandler(async (req, res) => {
  const reservation = await libraryService.reserveBook(req.body);
  res.status(201).json({ 
    success: true,
    message: 'Reservation created successfully', 
    reservation 
  });
});

// Get book issues history
const getBookIssues = asyncHandler(async (req, res) => {
  const result = await libraryService.getBookIssues(req.query);
  res.status(200).json({ 
    success: true,
    ...result 
  });
});

// Get overdue books
const getOverdueBooks = asyncHandler(async (req, res) => {
  const overdueBooks = await libraryService.getOverdueBooks();
  res.status(200).json({ 
    success: true,
    overdueBooks, 
    total: overdueBooks.length 
  });
});

const getReservations = asyncHandler(async (req, res) => {
  const reservations = await libraryService.getReservations(req.query.status);
  res.status(200).json({ 
    success: true,
    reservations 
  });
});

module.exports = {
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
};
