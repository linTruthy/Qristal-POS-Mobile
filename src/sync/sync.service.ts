import { Injectable, BadRequestException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service'; // Assuming you generated a Prisma module

@Injectable()
export class SyncService {
  constructor(private prisma: PrismaService) { }

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
    const [categories, products, users] = await Promise.all([
      this.prisma.category.findMany({
        where: { updatedAt: { gt: lastSyncDate } },
      }),
      this.prisma.product.findMany({
        where: { updatedAt: { gt: lastSyncDate } },
      }),
      this.prisma.user.findMany({
        where: { updatedAt: { gt: lastSyncDate } },
      }),
    ]);

    return {
      timestamp: new Date().toISOString(), // The client will save this for the next sync
      changes: {
        categories,
        products,
        users,
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

    // We use a transaction to ensure data integrity
    try {
      await this.prisma.$transaction(async (tx) => {

        // 1. Process Orders
        if (orders && Array.isArray(orders)) {
          for (const order of orders) {
            try {
              await tx.order.upsert({
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