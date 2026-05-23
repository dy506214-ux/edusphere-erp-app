const inventoryRepo = require('../repositories/InventoryRepository');
const { emitEvent } = require('./socketService');
const NotFoundError = require('../errors/NotFoundError');
const ValidationError = require('../errors/ValidationError');

class InventoryService {
    async getInventoryItems(filters) {
        const { category, status, search, page = 1, limit = 25 } = filters;

        const where = {};
        if (category) where.category = category;
        if (status === 'active') where.isActive = true;
        else if (status === 'inactive') where.isActive = false;

        if (search) {
            where.OR = [
                { name: { contains: search, mode: 'insensitive' } },
                { itemCode: { contains: search, mode: 'insensitive' } },
                { description: { contains: search, mode: 'insensitive' } },
            ];
        }

        const skip = (parseInt(page) - 1) * parseInt(limit);
        const [items, total] = await Promise.all([
            inventoryRepo.findItems(where, skip, parseInt(limit)),
            inventoryRepo.countItems(where)
        ]);

        return {
            items,
            pagination: {
                total,
                page: parseInt(page),
                limit: parseInt(limit),
                totalPages: Math.ceil(total / parseInt(limit)),
            },
        };
    }

    async getItemById(id) {
        const item = await inventoryRepo.findItemById(id);
        if (!item) throw new NotFoundError('Inventory item not found');
        return item;
    }

    async createItem(data) {
        const { itemCode, quantity, minStockLevel, unitPrice } = data;

        const existing = await inventoryRepo.findItemByCode(itemCode);
        if (existing) throw new ValidationError('Item code already exists');

        const item = await inventoryRepo.createItem({
            ...data,
            quantity: quantity ? parseInt(quantity) : 0,
            minStockLevel: minStockLevel ? parseInt(minStockLevel) : 0,
            unitPrice: unitPrice ? parseFloat(unitPrice) : null,
        });

        emitEvent('INVENTORY_ITEM_CREATED', item, 'ADMIN');
        return item;
    }

    async updateItem(id, updates) {
        const item = await inventoryRepo.findItemById(id);
        if (!item) throw new NotFoundError('Inventory item not found');

        const allowedUpdates = [
            'name', 'description', 'category', 'unit', 'minStockLevel', 'unitPrice', 'location', 'isActive'
        ];

        const updateData = {};
        Object.keys(updates).forEach((key) => {
            if (allowedUpdates.includes(key)) {
                if (key === 'minStockLevel') {
                    updateData[key] = parseInt(updates[key]);
                } else if (key === 'unitPrice') {
                    updateData[key] = parseFloat(updates[key]);
                } else {
                    updateData[key] = updates[key];
                }
            }
        });

        const updatedItem = await inventoryRepo.updateItem(id, updateData);
        emitEvent('INVENTORY_ITEM_UPDATED', updatedItem, 'ADMIN');
        return updatedItem;
    }

    async recordStockMovement(movementData, performedBy) {
        const { itemId, movementType, quantity, referenceNumber, remarks } = movementData;
        const qty = parseInt(quantity);

        return await inventoryRepo.executeTransaction(async (tx) => {
            // Lock the item for update to prevent race conditions
            const item = await tx.inventoryItem.findUnique({
                where: { id: itemId }
            });
            
            if (!item) throw new NotFoundError('Inventory item not found');

            let newQuantity = item.quantity;
            const isIncrement = ['IN', 'PURCHASE', 'RETURN', 'ADJUSTMENT_IN'].includes(movementType);
            const isDecrement = ['OUT', 'ISSUE', 'DAMAGE', 'LOST', 'ADJUSTMENT_OUT'].includes(movementType);

            if (isIncrement) {
                newQuantity += qty;
            } else if (isDecrement) {
                if (qty > item.quantity) {
                    throw new ValidationError(`Insufficient stock. Available: ${item.quantity}`);
                }
                newQuantity -= qty;
            }

            const movement = await tx.stockMovement.create({
                data: {
                    itemId,
                    movementType,
                    quantity: qty,
                    previousQuantity: item.quantity,
                    newQuantity,
                    referenceNumber,
                    remarks,
                    performedBy,
                },
                include: { item: true }
            });

            await tx.inventoryItem.update({
                where: { id: itemId },
                data: { quantity: newQuantity }
            });

            return movement;
        });
    }

    async getStockMovements(filters) {
        const { itemId, movementType, startDate, endDate, page = 1, limit = 25 } = filters;

        const where = {};
        if (itemId) where.itemId = itemId;
        if (movementType) where.movementType = movementType;

        if (startDate || endDate) {
            where.createdAt = {};
            if (startDate) where.createdAt.gte = new Date(startDate);
            if (endDate) where.createdAt.lte = new Date(endDate);
        }

        const skip = (parseInt(page) - 1) * parseInt(limit);
        const [movements, total] = await Promise.all([
            inventoryRepo.findMovements(where, skip, parseInt(limit)),
            inventoryRepo.countMovements(where)
        ]);

        return {
            movements,
            pagination: { total, page: parseInt(page), limit: parseInt(limit) }
        };
    }

    async getLowStockItems() {
        return inventoryRepo.getLowStockItems();
    }

    async getSummary() {
        return inventoryRepo.getInventorySummaryData();
    }
}

module.exports = new InventoryService();
