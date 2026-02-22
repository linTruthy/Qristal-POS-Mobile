import { Module } from '@nestjs/common';
import { AppController } from './app.controller';
import { AppService } from './app.service';
import { PrismaModule } from './prisma/prisma.module';
import { SyncModule } from './sync/sync.module';
import { AuthModule } from './auth/auth.module';
import { InventoryModule } from './inventory/inventory.module';
import { EventsGateway } from './events/events.gateway';

@Module({
  imports: [PrismaModule, SyncModule, AuthModule, InventoryModule],  // Add PrismaModule here
  controllers: [AppController],
  providers: [AppService, EventsGateway],
})
export class AppModule {}