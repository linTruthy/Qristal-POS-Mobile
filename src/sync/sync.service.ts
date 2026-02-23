// qristal-api/src/sync/sync.service.ts

import { Injectable, BadRequestException, Logger } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { EventsGateway } from '../events/events.gateway';
import { InventoryService } from '../inventory/inventory.service';
import { Order } from '@prisma/client';

@Injectable()
export class SyncService {
  private readonly logger = new Logger(SyncService.name);

  constructor(
    private prisma: PrismaService,
    private inventoryService: InventoryService,
    private eventsGateway: EventsGateway,
  ) {}

  async pullChanges(lastSyncTimestamp: string) {
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
    this.logger.log('Received pushChanges payload');
    // Extract all entities including shifts
    const { orders, orderItems, payments, shifts } = payload;
    const errors: { id: any; error: any }[] = [];
    let processedOrders = 0;
    let processedShifts = 0;

    const newOrderIdsToDeduct: string[] = [];
    const newlyCreatedOrdersForKDS: Order[] = [];

    try {
      await this.prisma.$transaction(async (tx) => {
        
        // --- 1. Process Shifts ---
        // Shifts must be processed before orders if orders reference new shifts,
        // but since we use UUIDs generated on client, order doesn't matter much 
        // unless we have strict foreign key constraints that Prisma enforces immediately.
        // It's safer to do shifts first.
        if (shifts && Array.isArray(shifts)) {
          for (const shift of shifts) {
            try {
              await tx.shift.upsert({
                where: { id: shift.id },
                update: {
                  closingTime: shift.closingTime ? new Date(shift.closingTime) : null,
                  expectedCash: shift.expectedCash,
                  actualCash: shift.actualCash,
                  notes: shift.notes,
                },
                create: {
                  id: shift.id,
                  userId: shift.userId,
                  openingTime: new Date(shift.openingTime),
                  closingTime: shift.closingTime ? new Date(shift.closingTime) : null,
                  startingCash: shift.startingCash,
                  expectedCash: shift.expectedCash,
                  actualCash: shift.actualCash,
                  notes: shift.notes,
                },
              });
              processedShifts++;
            } catch (err) {
              errors.push({ id: shift.id, error: `Shift error: ${err.message}` });
            }
          }
        }

        // --- 2. Process Orders ---
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
                  shiftId: order.shiftId, // Mapping the shift relation
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
              errors.push({ id: order.id, error: `Order error: ${err.message}` });
            }
          }
        }

        // --- 3. Process Order Items ---
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
              errors.push({ id: item.id, error: `Item error: ${err.message}` });
            }
          }
        }

        // --- 4. Process Payments ---
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
              // Ignore unique constraint violations (idempotency)
              if (!err.message.includes('Unique constraint')) {
                errors.push({ id: pay.id, error: `Payment error: ${err.message}` });
              }
            }
          }
        }
      });

      // --- Post-Transaction Actions (Non-blocking) ---
      
      // 1. Inventory Deduction
      for (const orderId of newOrderIdsToDeduct) {
        this.inventoryService.deductStockForOrder(orderId).catch(e =>
          console.error(`Inventory deduction failed async: ${e}`)
        );
      }

      // 2. KDS Notification
      if (newlyCreatedOrdersForKDS.length > 0) {
        this.eventsGateway.emitNewOrder({ message: 'New orders arrived!' });
      }

      // 3. Dashboard Inventory Update
      if (newOrderIdsToDeduct.length > 0) {
          // Wait briefly for deductions to commit/process before fetching status
          setTimeout(async () => {
            try {
                const latestInventory = await this.inventoryService.getInventoryStatus();
                this.eventsGateway.emitInventoryUpdate(latestInventory);
            } catch (e) {
                this.logger.error('Failed to emit inventory update', e);
            }
          }, 1000);
      }

      return {
        success: true,
        processedOrders,
        processedShifts,
        errors: errors.length > 0 ? errors : undefined,
      };

    } catch (error) {
      throw new BadRequestException(`Push sync failed: ${error.message}`);
    }
  }
}