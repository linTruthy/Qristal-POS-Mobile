import { Module } from '@nestjs/common';
import { SeatingController } from './seating.controller';
import { SeatingService } from './seating.service';

@Module({
  controllers: [SeatingController],
  providers: [SeatingService]
})
export class SeatingModule {}
