import { BadRequestException } from '@nestjs/common';
import { Test, TestingModule } from '@nestjs/testing';
import { SyncDirection, SyncStatus } from '@prisma/client';
import { EventsGateway } from '../events/events.gateway';
import { InventoryService } from '../inventory/inventory.service';
import { PrismaService } from '../prisma/prisma.service';
import { SyncService } from './sync.service';

describe('SyncService', () => {
  let service: SyncService;
  let prisma: {
    $transaction: jest.Mock;
    syncLog: { create: jest.Mock };
    category: { findMany: jest.Mock };
    product: { findMany: jest.Mock };
    user: { findMany: jest.Mock };
    seatingTable: { findMany: jest.Mock };
    order: { findMany: jest.Mock };
  };

  beforeEach(async () => {
    prisma = {
      $transaction: jest.fn(),
      syncLog: { create: jest.fn() },
      category: { findMany: jest.fn() },
      product: { findMany: jest.fn() },
      user: { findMany: jest.fn() },
      seatingTable: { findMany: jest.fn() },
      order: { findMany: jest.fn() },
    };

    const module: TestingModule = await Test.createTestingModule({
      providers: [
        SyncService,
        { provide: PrismaService, useValue: prisma },
        {
          provide: InventoryService,
          useValue: {
            deductStockForOrder: jest.fn().mockResolvedValue(undefined),
            getInventoryStatus: jest.fn().mockResolvedValue([]),
          },
        },
        {
          provide: EventsGateway,
          useValue: {
            emitNewOrder: jest.fn(),
            emitInventoryUpdate: jest.fn(),
          },
        },
      ],
    }).compile();

    service = module.get<SyncService>(SyncService);
  });

  it('should be defined', () => {
    expect(service).toBeDefined();
  });

  it('throws on invalid timestamp', async () => {
    await expect(service.pullChanges('not-a-date', 'BRANCH-01')).rejects.toThrow(
      BadRequestException,
    );
  });

  it('logs successful pull syncs', async () => {
    prisma.category.findMany.mockResolvedValueOnce([{ id: 'c1' }]);
    prisma.product.findMany.mockResolvedValueOnce([{ id: 'p1' }]);
    prisma.user.findMany.mockResolvedValueOnce([{ id: 'u1' }]);
    prisma.seatingTable.findMany.mockResolvedValueOnce([{ id: 't1' }]);
    prisma.order.findMany.mockResolvedValueOnce([{ id: 'o1' }]);

    await service.pullChanges('', 'BRANCH-01');

    expect(prisma.syncLog.create).toHaveBeenCalledWith(
      expect.objectContaining({
        data: expect.objectContaining({
          direction: SyncDirection.PULL,
          status: SyncStatus.SUCCESS,
          branchId: 'BRANCH-01',
          recordsPulled: 5,
        }),
      }),
    );
  });

  it('returns unsuccessful push response when item processing has errors', async () => {
    prisma.$transaction.mockImplementationOnce(async (handler: any) => {
      const tx = {
        shift: { upsert: jest.fn() },
        order: {
          findUnique: jest.fn().mockResolvedValue(null),
          upsert: jest.fn().mockResolvedValue({ id: 'order-1' }),
        },
        orderItem: {
          upsert: jest.fn().mockRejectedValue(new Error('item failed')),
        },
        payment: { create: jest.fn() },
        auditLog: { create: jest.fn() },
      };

      await handler(tx);
    });

    const result = await service.pushChanges(
      {
        orders: [
          {
            id: 'order-1',
            receiptNumber: 'ORD-1',
            userId: 'user-1',
            tableId: null,
            shiftId: null,
            totalAmount: 40,
            status: 'OPEN',
            createdAt: new Date().toISOString(),
          },
        ],
        orderItems: [
          {
            id: 'item-1',
            orderId: 'order-1',
            productId: 'product-1',
            quantity: 1,
            priceAtTimeOfOrder: 40,
          },
        ],
      },
      'BRANCH-01',
    );

    expect(result.success).toBe(false);
    expect(result.processedOrders).toBe(1);
    expect(result.errors).toBeDefined();
    expect(prisma.syncLog.create).toHaveBeenCalledWith(
      expect.objectContaining({
        data: expect.objectContaining({
          direction: SyncDirection.PUSH,
          status: SyncStatus.FAILED,
          branchId: 'BRANCH-01',
          recordsPushed: 1,
        }),
      }),
    );
  });
});
