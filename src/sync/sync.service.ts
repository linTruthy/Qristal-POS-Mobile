import { Injectable, BadRequestException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service'; // Assuming you generated a Prisma module
import { EventsGateway } from '../events/events.gateway';
import { InventoryService } from '../inventory/inventory.service';
import { Order } from '@prisma/client';

@Injectable()
export class SyncService {
  constructor(private prisma: PrismaService,
    private inventoryService: InventoryService,
    private eventsGateway: EventsGateway
  ) { }

  /**
   * PULL: Client requests data that has changed since `lastSyncTimestamp`.
   * The client sends a timestamp (ISO string), and the server returns
   * all records where `updatedAt > lastSyncTimestamp`.
   */
  async pullChanges(lastSyncTimestamp: string) {
    let lastSyncDate: Date;

    if (!lastSyncTimestamp) {
      // If no timestamp provided, do a full initial sync (return all data)
      lastSyncDate = new Date(0); // 1970-01-01
    } else {
      lastSyncDate = new Date(lastSyncTimestamp);
      if (isNaN(lastSyncDate.getTime())) {
        throw new BadRequestException('Invalid lastSyncTimestamp format.');
      }
    }

    // Fetch all updated records
    const [categories, products, users, seatingTables, orders] = await Promise.all([
      this.prisma.category.findMany({
        where: { updatedAt: { gt: lastSyncDate } },
      }),
      this.prisma.product.findMany({
        where: { updatedAt: { gt: lastSyncDate } },
      }),
      this.prisma.user.findMany({
        where: { updatedAt: { gt: lastSyncDate } },
      }),
      this.prisma.seatingTable.findMany({
        where: { updatedAt: { gt: lastSyncDate } },
      }),
      this.prisma.order.findMany({
        where: { updatedAt: { gt: lastSyncDate } },
      }),
    ]);

    return {
      timestamp: new Date().toISOString(), // The client will save this for the next sync
      changes: {
        categories,
        products,
        users,
        seatingTables,
        orders,
      },
    };
  }

  /**
   * PUSH: Client sends new/updated data (orders, transactions) to the server.
   * Since orders are generated on the POS, the server needs to upsert them.
   */
  async pushChanges(payload: any) {
    const { orders, orderItems, payments } = payload;
    const errors: { id: any; error: any }[] = [];
    let processedOrders = 0;

    const newOrderIdsToDeduct: string[] = [];

    const newlyCreatedOrdersForKDS: Order[] = [];
    // We use a transaction to ensure data integrity
    try {
      await this.prisma.$transaction(async (tx) => {

        // 1. Process Orders
        if (orders && Array.isArray(orders)) {
          for (const order of orders) {
            try {
              const existing = await tx.order.findUnique({ where: { id: order.id } });
              const savedOrder = await tx.order.upsert({
                where: { id: order.id },
                update: {
                  status: order.status,
                  totalAmount: order.totalAmount,
                  updatedAt: new Date(), // Force server timestamp
                },
                create: {
                  id: order.id,
                  receiptNumber: order.receiptNumber,
                  userId: order.userId,
                  tableId: order.tableId,
                  totalAmount: order.totalAmount,
                  status: order.status,
                  createdAt: new Date(order.createdAt), // Keep original creation time
                },
              });
              processedOrders++;
              if (!existing) {
                newOrderIdsToDeduct.push(order.id);
                newlyCreatedOrdersForKDS.push(savedOrder); // Save for WebSocket
              }

            } catch (err) {
              errors.push({ id: order.id, error: err.message });
            }
          }
        }

        // 2. Process Order Items
        if (orderItems && Array.isArray(orderItems)) {
          for (const item of orderItems) {
            try {
              await tx.orderItem.upsert({
                where: { id: item.id },
                update: {
                  quantity: item.quantity,
                  notes: item.notes,
                },
                create: {
                  id: item.id,
                  orderId: item.orderId,
                  productId: item.productId,
                  quantity: item.quantity,
                  priceAtTimeOfOrder: item.priceAtTimeOfOrder,
                  notes: item.notes,
                },
              });
            } catch (err) {
              errors.push({ id: item.id, error: err.message });
            }
          }
        }

        // 3. Process Payments
        if (payments && Array.isArray(payments)) {
          for (const pay of payments) {
            try {
              await tx.payment.create({ // We usually only create payments, not update them
                data: {
                  id: pay.id,
                  orderId: pay.orderId,
                  method: pay.method, // Ensure Enum mapping matches
                  amount: pay.amount,
                  reference: pay.reference,
                  createdAt: new Date(pay.createdAt),
                }
              });
            } catch (err) {
              // If it exists, ignore (idempotency), otherwise log error
              if (!err.message.includes('Unique constraint')) {
                errors.push({ id: pay.id, error: err.message });
              }
            }
          }
        }
      });

      for (const orderId of newOrderIdsToDeduct) {
        // Fire and forget - don't await this so the POS gets a fast response
        this.inventoryService.deductStockForOrder(orderId).catch(e =>
          console.error(`Inventory deduction failed async: ${e}`)
        );
      }
      if (newlyCreatedOrdersForKDS.length > 0) {
        // In a real app we'd fetch the items too, but sending the signal is enough 
        // for the KDS to know it needs to pull. Let's send the data.
        this.eventsGateway.emitNewOrder({ message: 'New orders arrived!' });
      }

      // 2. Trigger Inventory Deduction (Non-blocking)
      for (const orderId of newOrderIdsToDeduct) {
        this.inventoryService.deductStockForOrder(orderId).then(async () => {
          // After deduction, fetch latest inventory and broadcast to Dashboard
          const latestInventory = await this.inventoryService.getInventoryStatus();
          this.eventsGateway.emitInventoryUpdate(latestInventory);
        }).catch(e => console.error(e));
      }
      return {
        success: true,
        processedOrders,
        errors: errors.length > 0 ? errors : undefined,
      };

    } catch (error) {
      // Transaction failed
      throw new BadRequestException(`Push sync failed: ${error.message}`);
    }
  }
}
