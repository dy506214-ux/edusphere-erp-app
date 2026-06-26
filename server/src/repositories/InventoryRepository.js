const prisma = require('../config/database');

/**
 * Repository for Inventory related database operations
 */
class InventoryRepository {
    async findItems(where, skip, take) {
        return prisma.inventoryItem.findMany({
            where,
            skip,
            take,
            orderBy: { createdAt: 'desc' },
        });
    }

    async countItems(where) {
        return prisma.inventoryItem.count({ where });
    }

    async findItemById(id) {
        return prisma.inventoryItem.findUnique({
            where: { id },
            include: {
                movements: {
                    orderBy: { createdAt: 'desc' },
                    take: 20,
                },
            },
        });
    }

    async findItemByCode(itemCode) {
        return prisma.inventoryItem.findUnique({ where: { itemCode } });
    }

    async createItem(data) {
        return prisma.inventoryItem.create({ data });
    }

    async updateItem(id, data) {
        return prisma.inventoryItem.update({
            where: { id },
            data,
        });
    }

    async findMovements(where, skip, take) {
        return prisma.stockMovement.findMany({
            where,
            include: {
                item: {
                    select: {
                        id: true,
                        itemCode: true,
                        name: true,
                        category: true,
                        unit: true,
                    },
                },
            },
            skip,
            take,
            orderBy: { createdAt: 'desc' },
        });
    }

    async countMovements(where) {
        return prisma.stockMovement.count({ where });
    }

    async createMovement(data) {
        return prisma.stockMovement.create({
            data,
            include: { item: true }
        });
    }

    async getLowStockItems() {
        return prisma.$queryRaw`
            SELECT * FROM "InventoryItem"
            WHERE quantity <= "minStockLevel"
            AND "isActive" = true
            ORDER BY quantity ASC
        `;
    }

    async getInventorySummaryData() {
        const totalItems = await prisma.inventoryItem.count();
        const activeItems = await prisma.inventoryItem.count({ where: { isActive: true } });
        
        const lowStockItemsResult = await prisma.$queryRaw`
            SELECT COUNT(*) as count FROM "InventoryItem" WHERE quantity <= "minStockLevel" AND "isActive" = true
        `;
        const lowStockItems = parseInt(lowStockItemsResult[0]?.count || 0);
        
        const outOfStockItems = await prisma.inventoryItem.count({
            where: { isActive: true, quantity: 0 },
        });

        const valueItems = await prisma.inventoryItem.findMany({
            where: { isActive: true },
            select: { quantity: true, unitPrice: true },
        });

        const inventoryValue = valueItems.reduce((sum, item) => {
            return sum + item.quantity * (item.unitPrice || 0);
        }, 0);

        return {
            totalItems,
            activeItems,
            lowStockItems,
            outOfStockItems,
            inventoryValue: parseFloat(inventoryValue.toFixed(2)),
        };
    }

    async executeTransaction(callback) {
        return prisma.$transaction(callback);
    }
}

module.exports = new InventoryRepository();
