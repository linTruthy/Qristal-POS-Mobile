import { Test, TestingModule } from '@nestjs/testing';
import { SyncController } from './sync.controller';
import { SyncService } from './sync.service';

describe('SyncController', () => {
  let controller: SyncController;

  const syncServiceMock = {
    pullChanges: jest.fn(),
    pushChanges: jest.fn(),
    getSyncLogsOverview: jest.fn(),
  };

  beforeEach(async () => {
    const module: TestingModule = await Test.createTestingModule({
      controllers: [SyncController],
      providers: [{ provide: SyncService, useValue: syncServiceMock }],
    }).compile();

    controller = module.get<SyncController>(SyncController);
  });

  it('should be defined', () => {
    expect(controller).toBeDefined();
  });

  it('delegates logs overview request to service with branch context', async () => {
    syncServiceMock.getSyncLogsOverview.mockResolvedValueOnce({ summary: {} });

    await controller.getLogs('25', { user: { branchId: 'BRANCH-01' } });

    expect(syncServiceMock.getSyncLogsOverview).toHaveBeenCalledWith(
      'BRANCH-01',
      '25',
    );
  });
});
