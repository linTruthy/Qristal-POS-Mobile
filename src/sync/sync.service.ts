import { Injectable, BadRequestException, Logger } from '@nestjs/common';
import { Order, Prisma, SyncDirection, SyncStatus } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';
import { EventsGateway } from '../events/events.gateway';
import { InventoryService } from '../inventory/inventory.service';

@Injectable()
export class SyncService {
  private readonly logger = new Logger(SyncService.name);

  constructor(
    private prisma: PrismaService,
    private inventoryService: InventoryService,
    private eventsGateway: EventsGateway,
  ) {}

  private getErrorMessage(error: unknown): string {
    if (error instanceof Error) {
      return error.message;
    }

    if (typeof error === 'string') {
      return error;
    }

    return 'Unknown error';
  }

  private isUniqueConstraintError(error: unknown): boolean {
    if (!error || typeof error !== 'object') {
      return false;
    }

    return 'code' in error && (error as { code?: string }).code === 'P2002';
  }

  private async writeSyncLogSafely(data: Prisma.SyncLogCreateInput): Promise<void> {
    try {
      await this.prisma.syncLog.create({ data });
    } catch (error) {
      this.logger.error(`Failed to persist sync log: ${this.getErrorMessage(error)}`);
    }
  }



  async getSyncLogsOverview(branchId: string, limit?: string) {
    const parsedLimit = Number(limit);
    const normalizedLimit = Number.isFinite(parsedLimit)
      ? Math.min(Math.max(Math.floor(parsedLimit), 1), 200)
      : 50;

    const logs = await this.prisma.syncLog.findMany({
      where: { branchId },
      orderBy: { startedAt: 'desc' },
      take: normalizedLimit,
    });

    const summary = logs.reduce(
      (acc, log) => {
        const key = log.direction === SyncDirection.PUSH ? 'push' : 'pull';
        acc[key].total += 1;

        if (log.status === SyncStatus.SUCCESS) {
          acc[key].success += 1;
        } else {
          acc[key].failed += 1;
        }

        return acc;
      },
      {
        push: { total: 0, success: 0, failed: 0 },
        pull: { total: 0, success: 0, failed: 0 },
      },
    );

    return {
      branchId,
      limit: normalizedLimit,
      summary: {
        push: {
          ...summary.push,
          successRate:
            summary.push.total > 0
              ? Number(((summary.push.success / summary.push.total) * 100).toFixed(2))
              : 0,
        },
        pull: {
          ...summary.pull,
          successRate:
            summary.pull.total > 0
              ? Number(((summary.pull.success / summary.pull.total) * 100).toFixed(2))
              : 0,
        },
      },
      logs,
    };
  }

  async pullChanges(lastSyncTimestamp: string, branchId: string) {
    let lastSyncDate: Date;

    if (!lastSyncTimestamp) {
      lastSyncDate = new Date(0);
    } else {
      lastSyncDate = new Date(lastSyncTimestamp);
      if (isNaN(lastSyncDate.getTime())) {
        throw new BadRequestException('Invalid lastSyncTimestamp format.');
      }
    }

    try {
      const [categories, products, users, seatingTables, orders, shifts] = await Promise.all([
        this.prisma.category.findMany({
          where: {
            updatedAt: { gt: lastSyncDate },
            branchId,
          },
        }),
        this.prisma.product.findMany({
          where: {
            updatedAt: { gt: lastSyncDate },
            branchId,
          },
        }),
        this.prisma.user.findMany({
          where: {
            updatedAt: { gt: lastSyncDate },
            branchId,
          },
          select: {
            id: true,
            fullName: true,
            role: true,
            branchId: true,
            isActive: true,
          },
        }),
        this.prisma.seatingTable.findMany({
          where: {
            updatedAt: { gt: lastSyncDate },
            branchId,
          },
        }),
        this.prisma.order.findMany({
          where: {
            updatedAt: { gt: lastSyncDate },
            branchId,
          },
        }),
        this.prisma.shift.findMany({
          where: {
            updatedAt: { gt: lastSyncDate },
            branchId,
          }
        })
      ]);

      const recordsPulled =
        categories.length +
        products.length +
        users.length +
        seatingTables.length +
        orders.length +
        shifts.length;

      await this.writeSyncLogSafely({
        branchId,
        direction: SyncDirection.PULL,
        status: SyncStatus.SUCCESS,
        recordsPulled,
        finishedAt: new Date(),
      });

      return {
        timestamp: new Date().toISOString(),
        changes: {
          categories,
          products,
          users,
          seatingTables,
          orders,
          shifts,
        },
      };
    } catch (error) {
      await this.writeSyncLogSafely({
        branchId,
        direction: SyncDirection.PULL,
        status: SyncStatus.FAILED,
        errorMessage: this.getErrorMessage(error),
        finishedAt: new Date(),
      });
      throw error;
    }
  }

  async pushChanges(payload: any, userBranchId: string) {
    this.logger.log('Received pushChanges payload');
    const { orders, orderItems, payments, shifts, auditLogs } = payload;
    const errors: { id: any; error: string }[] = [];
    const orderShiftMap = new Map<string, string | null>();

    let processedOrders = 0;
    let processedShifts = 0;
    let processedAuditLogs = 0;

    const newOrderIdsToDeduct: string[] = [];
    const newlyCreatedOrdersForKDS: Order[] = [];

    try {
      await this.prisma.$transaction(async (tx) => {
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
                  branchId: userBranchId,
                },
              });
              processedShifts++;
            } catch (err) {
              errors.push({ id: shift.id, error: `Shift error: ${this.getErrorMessage(err)}` });
            }
          }
        }

        if (orders && Array.isArray(orders)) {
          for (const order of orders) {
            orderShiftMap.set(order.id, order.shiftId ?? null);
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
                  shiftId: order.shiftId,
                  totalAmount: order.totalAmount,
                  status: order.status,
                  createdAt: new Date(order.createdAt),
                  branchId: userBranchId,
                },
              });
              processedOrders++;
              if (!existing) {
                newOrderIdsToDeduct.push(order.id);
                newlyCreatedOrdersForKDS.push(savedOrder);
              }
            } catch (err) {
              errors.push({ id: order.id, error: `Order error: ${this.getErrorMessage(err)}` });
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
              errors.push({ id: item.id, error: `Item error: ${this.getErrorMessage(err)}` });
            }
          }
        }

        if (payments && Array.isArray(payments)) {
          for (const pay of payments) {
            try {
              let resolvedShiftId = pay.shiftId ?? orderShiftMap.get(pay.orderId) ?? null;

              if (!resolvedShiftId) {
                const existingOrder = await tx.order.findUnique({
                  where: { id: pay.orderId },
                  select: { shiftId: true },
                });
                resolvedShiftId = existingOrder?.shiftId ?? null;
              }

              if (!resolvedShiftId) {
                errors.push({
                  id: pay.id,
                  error:
                    'Payment error: shiftId is required. Provide payment.shiftId or sync order with a shiftId first.',
                });
                continue;
              }

              await tx.payment.create({
                data: {
                  id: pay.id,
                  orderId: pay.orderId,
                  method: pay.method,
                  amount: pay.amount,
                  reference: pay.reference,
                  shiftId: resolvedShiftId,
                  createdAt: new Date(pay.createdAt),
                },
              });
            } catch (err) {
              if (!this.isUniqueConstraintError(err)) {
                const errorMessage = this.getErrorMessage(err);
                errors.push({ id: pay.id, error: `Payment error: ${errorMessage}` });
              }
            }
          }
        }

        if (auditLogs && Array.isArray(auditLogs)) {
          for (const log of auditLogs) {
            try {
              await tx.auditLog.create({
                data: {
                  id: log.id,
                  branchId: userBranchId,
                  userId: log.userId,
                  action: log.action,
                  orderId: log.orderId,
                  metadata: (log.metadata ?? undefined) as Prisma.InputJsonValue,
                  createdAt: log.createdAt ? new Date(log.createdAt) : new Date(),
                },
              });
              processedAuditLogs++;
            } catch (err) {
              if (!this.isUniqueConstraintError(err)) {
                const errorMessage = this.getErrorMessage(err);
                errors.push({ id: log.id, error: `Audit log error: ${errorMessage}` });
              }
            }
          }
        }
      });

      for (const orderId of newOrderIdsToDeduct) {
        this.inventoryService.deductStockForOrder(orderId).catch((e: unknown) =>
          this.logger.error(`Inventory deduction failed async: ${this.getErrorMessage(e)}`),
        );
      }

      if (newlyCreatedOrdersForKDS.length > 0) {
        this.eventsGateway.emitNewOrder({ message: 'New orders arrived!' });
      }

      if (newOrderIdsToDeduct.length > 0) {
        setTimeout(async () => {
          try {
            const latestInventory = await this.inventoryService.getInventoryStatus(
              userBranchId,
            );
            this.eventsGateway.emitInventoryUpdate(latestInventory);
          } catch (e) {
            this.logger.error(
              `Failed to emit inventory update: ${this.getErrorMessage(e)}`,
            );
          }
        }, 1000);
      }

      const recordsPushed = processedOrders + processedShifts + processedAuditLogs;
      const wasSuccessful = errors.length === 0;

      await this.writeSyncLogSafely({
        branchId: userBranchId,
        direction: SyncDirection.PUSH,
        status: wasSuccessful ? SyncStatus.SUCCESS : SyncStatus.FAILED,
        recordsPushed,
        errorMessage: wasSuccessful ? null : JSON.stringify(errors),
        finishedAt: new Date(),
      });

      return {
        success: wasSuccessful,
        processedOrders,
        processedShifts,
        processedAuditLogs,
        errors: errors.length > 0 ? errors : undefined,
      };
    } catch (error) {
      await this.writeSyncLogSafely({
        branchId: userBranchId,
        direction: SyncDirection.PUSH,
        status: SyncStatus.FAILED,
        errorMessage: this.getErrorMessage(error),
        finishedAt: new Date(),
      });

      throw new BadRequestException(`Push sync failed: ${this.getErrorMessage(error)}`);
    }
  }
}