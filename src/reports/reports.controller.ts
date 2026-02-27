import { Controller, Get, Query, Request, UseGuards } from '@nestjs/common';
import { AuthGuard } from '@nestjs/passport';
import { ReportsService } from './reports.service';

@Controller('reports')
@UseGuards(AuthGuard('jwt'))
export class ReportsController {
  constructor(private readonly reportsService: ReportsService) {}

  @Get('sales')
  async getSales(@Request() req, @Query('start') start: string, @Query('end') end: string) {
    const startDate = start ? new Date(start) : new Date(new Date().setDate(new Date().getDate() - 30)); // Default 30 days
    const endDate = end ? new Date(end) : new Date();
    
    return this.reportsService.getSalesHistory(req.user.branchId, startDate, endDate);
  }

  @Get('top-items')
  async getTopItems(@Request() req) {
    return this.reportsService.getTopSellingItems(req.user.branchId);
  }
  
  @Get('payments')
  async getPayments(@Request() req) {
    return this.reportsService.getPaymentSummary(req.user.branchId);
  }
}