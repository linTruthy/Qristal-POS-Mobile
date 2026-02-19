// src/sync/sync.controller.ts
import { Controller, Get, Post, Body, Query, UseGuards } from '@nestjs/common';
import { AuthGuard } from '@nestjs/passport'; // Built-in guard
import { SyncService } from './sync.service';

@Controller('sync')
@UseGuards(AuthGuard('jwt')) // This protects all routes in this controller
export class SyncController {
    constructor(private readonly syncService: SyncService) { }

    @Get('pull')
    async pull(@Query('lastSyncTimestamp') lastSyncTimestamp: string) {
        return this.syncService.pullChanges(lastSyncTimestamp);
    }

    @Post('push')
    async push(@Body() payload: any) {
        return this.syncService.pushChanges(payload);
    }
}