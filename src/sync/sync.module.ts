import { Module } from '@nestjs/common';
import { SyncService } from './sync.service';
import { SyncController } from './sync.controller';
import { EventsModule } from '../events/events.module'; // Import the module
import { InventoryModule } from '../inventory/inventory.module'; // Also need this for deductStockForOrder

@Module({
  imports: [
    EventsModule,    // <-- Import EventsModule here
    InventoryModule  // <-- Import InventoryModule here
  ],
  controllers: [SyncController],
  providers: [SyncService],
})
export class SyncModule {}