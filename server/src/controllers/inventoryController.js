const inventoryService = require('../services/InventoryService');
const asyncHandler = require('../utils/asyncHandler');

// Get all inventory items
const getInventoryItems = asyncHandler(async (req, res) => {
  const result = await inventoryService.getInventoryItems(req.query);
  res.status(200).json({ 
    success: true,
    ...result 
  });
});

// Get single inventory item
const getInventoryItem = asyncHandler(async (req, res) => {
  const item = await inventoryService.getItemById(req.params.id);
  res.status(200).json({ 
    success: true,
    item 
  });
});

// Create inventory item
const createInventoryItem = asyncHandler(async (req, res) => {
  const item = await inventoryService.createItem(req.body);
  res.status(201).json({ 
    success: true,
    message: 'Inventory item created successfully', 
    item 
  });
});

// Update inventory item
const updateInventoryItem = asyncHandler(async (req, res) => {
  const item = await inventoryService.updateItem(req.params.id, req.body);
  res.status(200).json({ 
    success: true,
    message: 'Inventory item updated successfully', 
    item 
  });
});

// Record stock movement
const recordStockMovement = asyncHandler(async (req, res) => {
  const movement = await inventoryService.recordStockMovement(req.body, req.user.userId);
  res.status(201).json({ 
    success: true,
    message: 'Stock movement recorded successfully', 
    movement 
  });
});

// Get stock movements
const getStockMovements = asyncHandler(async (req, res) => {
  const result = await inventoryService.getStockMovements(req.query);
  res.status(200).json({ 
    success: true,
    ...result 
  });
});

// Get low stock items
const getLowStockItems = asyncHandler(async (req, res) => {
  const lowStockItems = await inventoryService.getLowStockItems();
  res.status(200).json({ 
    success: true,
    items: lowStockItems, 
    total: lowStockItems.length 
  });
});

// Get inventory summary
const getInventorySummary = asyncHandler(async (req, res) => {
  const summary = await inventoryService.getSummary();
  res.status(200).json({ 
    success: true,
    summary 
  });
});

module.exports = {
  getInventoryItems,
  getInventoryItem,
  createInventoryItem,
  updateInventoryItem,
  recordStockMovement,
  getStockMovements,
  getLowStockItems,
  getInventorySummary,
};
