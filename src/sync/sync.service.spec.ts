import { Test, TestingModule } from '@nestjs/testing';
import { SyncService } from './sync.service';
import { PrismaService } from '../prisma/prisma.service';
import { InventoryService } from '../inventory/inventory.service';
import { EventsGateway } from '../events/events.gateway';

describe('SyncService', () => {
  let service: SyncService;

  beforeEach(async () => {
    const module: TestingModule = await Test.createTestingModule({
      providers: [
        SyncService,
        {
          provide: PrismaService,
          useValue: {
            $transaction: jest.fn(),
            syncLog: { create: jest.fn() },
            category: { findMany: jest.fn() },
            product: { findMany: jest.fn() },
            user: { findMany: jest.fn() },
            seatingTable: { findMany: jest.fn() },
            order: { findMany: jest.fn() },
          },
        },
        {
          provide: InventoryService,
          useValue: {
            deductStockForOrder: jest.fn(),
            getInventoryStatus: jest.fn(),
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
});
