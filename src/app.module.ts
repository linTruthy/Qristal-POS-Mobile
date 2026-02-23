import { Module } from '@nestjs/common';
import { PrismaModule } from './prisma/prisma.module';
import { AuthModule } from './auth/auth.module';
import { SyncModule } from './sync/sync.module';
import { InventoryModule } from './inventory/inventory.module';
import { EventsModule } from './events/events.module';
import { ReportsModule } from './reports/reports.module';
import { UsersModule } from './users/users.module';     // <--- New
import { MenuModule } from './menu/menu.module';        // <--- New
import { SeatingModule } from './seating/seating.module'; // <--- New

@Module({
  imports: [
    PrismaModule, 
    SyncModule, 
    AuthModule, 
    InventoryModule, 
    EventsModule, 
    ReportsModule,
    UsersModule, 
    MenuModule, 
    SeatingModule
  ],
})
export class AppModule { }