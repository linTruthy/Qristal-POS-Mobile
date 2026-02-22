import { Injectable, BadRequestException, Logger } from '@nestjs/common'; // Import Logger
import { PrismaService } from '../prisma/prisma.service';
import { EventsGateway } from '../events/events.gateway';
import { InventoryService } from '../inventory/inventory.service';
import { Order } from '@prisma/client';

@Injectable()
export class SyncService {
  private readonly logger = new Logger(SyncService.name); // Instantiate Logger

  constructor(private prisma: PrismaService,
    private inventoryService: InventoryService,
    private eventsGateway: EventsGateway
  ) { }

  async pullChanges(lastSyncTimestamp: string) {
    // ... (omitted for brevity)
    let lastSyncDate: Date;

    if (!lastSyncTimestamp) {
      lastSyncDate = new Date(0);
    } else {
      lastSyncDate = new Date(lastSyncTimestamp);
      if (isNaN(lastSyncDate.getTime())) {
        throw new BadRequestException('Invalid lastSyncTimestamp format.');
      }
    }

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
      timestamp: new Date().toISOString(),
      changes: {
        categories,
        products,
        users,
        seatingTables,
        orders,
      },
    };
  }

  async pushChanges(payload: any) {
    // ---- START OF DIAGNOSTIC LOGGING ----
    this.logger.log('Received pushChanges payload:');
    this.logger.log(JSON.stringify(payload, null, 2));
    // ---- END OF DIAGNOSTIC LOGGING ----

    const { orders, orderItems, payments } = payload;
    const errors: { id: any; error: any }[] = [];
    let processedOrders = 0;

    const newOrderIdsToDeduct: string[] = [];
    const newlyCreatedOrdersForKDS: Order[] = [];

    try {
      await this.prisma.$transaction(async (tx) => {
        if (orders && Array.isArray(orders)) {
          for (const order of orders) {
            try {
              const existing = await tx.order.findUnique({ where: { id: order.id } });
              const savedOrder = await tx.order.upsert({
                where: { id: order.id },
                update: {
                  status: order.status,
                  totalAmount: order.totalAmount,
                  updatedAt: new Date(),
                },
                create: {
                  id: order.id,
                  receiptNumber: order.receiptNumber,
                  userId: order.userId,
                  tableId: order.tableId,
                  totalAmount: order.totalAmount,
                  status: order.status,
                  createdAt: new Date(order.createdAt),
                },
              });
              processedOrders++;
              if (!existing) {
                newOrderIdsToDeduct.push(order.id);
                newlyCreatedOrdersForKDS.push(savedOrder);
              }

            } catch (err) {
              errors.push({ id: order.id, error: err.message });
            }
          }
        }

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

        if (payments && Array.isArray(payments)) {
          for (const pay of payments) {
            try {
              await tx.payment.create({
                data: {
                  id: pay.id,
                  orderId: pay.orderId,
                  method: pay.method,
                  amount: pay.amount,
                  reference: pay.reference,
                  createdAt: new Date(pay.createdAt),
                }
              });
            } catch (err) {
              if (!err.message.includes('Unique constraint')) {
                errors.push({ id: pay.id, error: err.message });
              }
            }
          }
        }
      });

      for (const orderId of newOrderIdsToDeduct) {
        this.inventoryService.deductStockForOrder(orderId).catch(e =>
          console.error(`Inventory deduction failed async: ${e}`)
        );
      }
      if (newlyCreatedOrdersForKDS.length > 0) {
        this.eventsGateway.emitNewOrder({ message: 'New orders arrived!' });
      }

      for (const orderId of newOrderIdsToDeduct) {
        this.inventoryService.deductStockForOrder(orderId).then(async () => {
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
      throw new BadRequestException(`Push sync failed: ${error.message}`);
    }
  }
}
