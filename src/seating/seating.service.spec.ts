import { Test, TestingModule } from '@nestjs/testing';
import { SeatingService } from './seating.service';

describe('SeatingService', () => {
  let service: SeatingService;

  beforeEach(async () => {
    const module: TestingModule = await Test.createTestingModule({
      providers: [SeatingService],
    }).compile();

    service = module.get<SeatingService>(SeatingService);
  });

  it('should be defined', () => {
    expect(service).toBeDefined();
  });
});
