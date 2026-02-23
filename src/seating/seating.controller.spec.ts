import { Test, TestingModule } from '@nestjs/testing';
import { SeatingController } from './seating.controller';

describe('SeatingController', () => {
  let controller: SeatingController;

  beforeEach(async () => {
    const module: TestingModule = await Test.createTestingModule({
      controllers: [SeatingController],
    }).compile();

    controller = module.get<SeatingController>(SeatingController);
  });

  it('should be defined', () => {
    expect(controller).toBeDefined();
  });
});
