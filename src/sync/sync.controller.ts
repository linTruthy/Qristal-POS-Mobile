// src/sync/sync.controller.ts
import {
  Controller,
  Get,
  Post,
  Body,
  Query,
  UseGuards,
  Request,
} from '@nestjs/common';
import { AuthGuard } from '@nestjs/passport';
import { SyncService } from './sync.service';

@Controller('sync')
@UseGuards(AuthGuard('jwt'))
export class SyncController {
  constructor(private readonly syncService: SyncService) {}

  @Get('pull')
  async pull(
    @Query('lastSyncTimestamp') lastSyncTimestamp: string,
    @Request() req,
  ) {
    return this.syncService.pullChanges(lastSyncTimestamp, req.user.branchId);
  }

  @Post('push')
  async push(@Body() payload: any, @Request() req) {
    return this.syncService.pushChanges(payload, req.user.branchId);
  }

  @Get('logs')
  async getLogs(@Query('limit') limit: string, @Request() req) {
    return this.syncService.getSyncLogsOverview(req.user.branchId, limit);
  }
}
