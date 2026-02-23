// src/sync/sync.controller.ts
import { Controller, Get, Post, Body, Query, UseGuards, Request } from '@nestjs/common';
import { AuthGuard } from '@nestjs/passport'; // Built-in guard
import { SyncService } from './sync.service';

@Controller('sync')
@UseGuards(AuthGuard('jwt')) 
export class SyncController {
    constructor(private readonly syncService: SyncService) { }

    @Get('pull')
    // Use @Request() req to get the user from the JWT strategy
    async pull(@Query('lastSyncTimestamp') lastSyncTimestamp: string, @Request() req) {
        const user = req.user;
        // Pass branchId to service
        return this.syncService.pullChanges(lastSyncTimestamp, req.user.branchId);
    }

    @Post('push')
    async push(@Body() payload: any, @Request() req) {
        // Enforce branch ownership on pushed data? 
        // For now we trust the client logic, but ideally validate here.
        return this.syncService.pushChanges(payload, req.user.branchId);
    }
}