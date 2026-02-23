import { Module } from '@nestjs/common';
import { AppController } from './app.controller';
import { AppService } from './app.service';
import { PrismaModule } from './prisma/prisma.module';
import { SyncModule } from './sync/sync.module';
import { AuthModule } from './auth/auth.module';
import { InventoryModule } from './inventory/inventory.module';
import { EventsModule } from './events/events.module';
import { ReportsModule } from './reports/reports.module';

@Module({
  imports: [PrismaModule, SyncModule, AuthModule, InventoryModule, EventsModule, ReportsModule],  // Add PrismaModule here
  controllers: [AppController],
  providers: [AppService],
})
export class AppModule { }