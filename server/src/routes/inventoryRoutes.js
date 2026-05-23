const express = require('express');
const {
  getInventoryItems,
  getInventoryItem,
  createInventoryItem,
  updateInventoryItem,
  recordStockMovement,
  getStockMovements,
  getLowStockItems,
  getInventorySummary,
} = require('../controllers/inventoryController');
const { authMiddleware, requireRole } = require('../middleware/auth');

const router = express.Router();

router.use(authMiddleware);

// Inventory items
router.get('/items', getInventoryItems);
router.get('/items/:id', getInventoryItem);
router.post('/items', requireRole('SUPER_ADMIN', 'ADMIN', 'INVENTORY_MANAGER'), createInventoryItem);
router.put('/items/:id', requireRole('SUPER_ADMIN', 'ADMIN', 'INVENTORY_MANAGER'), updateInventoryItem);

// Stock movements
router.post('/movements', requireRole('SUPER_ADMIN', 'ADMIN', 'INVENTORY_MANAGER'), recordStockMovement);
router.get('/movements', getStockMovements);

// Reports
router.get('/low-stock', getLowStockItems);
router.get('/summary', getInventorySummary);

module.exports = router;
