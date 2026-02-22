import { Injectable, Logger } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';

@Injectable()
export class InventoryService {
  private readonly logger = new Logger(InventoryService.name);

  constructor(private prisma: PrismaService) {}

  /**
   * Processes inventory deductions for a given order.
   * This should be called after an order is successfully synced from the POS.
   */
  async deductStockForOrder(orderId: string) {
    try {
      // 1. Fetch the order and its items
      const order = await this.prisma.order.findUnique({
        where: { id: orderId },
        include: { items: true },
      });

      if (!order) {
        this.logger.error(`Order ${orderId} not found for inventory deduction.`);
        return;
      }

      this.logger.log(`Processing inventory for Order: ${order.receiptNumber}`);

      // 2. Loop through each item in the order
      for (const orderItem of order.items) {
        
        // 3. Find the recipe for this product
        const recipeIngredients = await this.prisma.recipeIngredient.findMany({
          where: { productId: orderItem.productId },
        });

        if (recipeIngredients.length === 0) {
            // It's a product without a recipe (maybe a retail item), skip deduction or handle retail logic.
            continue; 
        }

        // 4. Calculate total deduction and update inventory
        for (const ingredient of recipeIngredients) {
            // quantity ordered * amount needed per item
            const totalDeduction = Number(orderItem.quantity) * Number(ingredient.amount);

            await this.prisma.inventoryItem.update({
                where: { id: ingredient.inventoryItemId },
                data: {
                    currentStock: {
                        decrement: totalDeduction
                    }
                }
            });

            this.logger.debug(`Deducted ${totalDeduction} from InventoryItem ${ingredient.inventoryItemId}`);
        }
      }
    } catch (error) {
        this.logger.error(`Failed to deduct inventory for order ${orderId}: ${error.message}`);
    }
  }

  async getInventoryStatus() {
    return this.prisma.inventoryItem.findMany({
      orderBy: { currentStock: 'asc' }, // Order by lowest stock first
    });
  }
}