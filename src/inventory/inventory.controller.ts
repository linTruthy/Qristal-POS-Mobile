import { Controller, Get, Post, Body, Put, Patch, Param, Delete, UseGuards, Request } from '@nestjs/common';
import { InventoryService } from './inventory.service';
import { AuthGuard } from '@nestjs/passport';

@Controller('inventory')
@UseGuards(AuthGuard('jwt'))
export class InventoryController {
  constructor(private readonly inventoryService: InventoryService) {}

  @Get()
  async getInventory(@Request() req) {
    return this.inventoryService.getInventoryStatus(req.user.branchId);
  }

  @Post()
  async create(@Request() req, @Body() data: any) {
    return this.inventoryService.createInventoryItem(req.user.branchId, data);
  }

  @Patch(':id/restock')
  async restock(@Request() req, @Param('id') id: string, @Body('amount') amount: number) {
    return this.inventoryService.restockItem(id, req.user.branchId, amount);
  }

  @Put(':id')
  async update(@Request() req, @Param('id') id: string, @Body() data: any) {
    return this.inventoryService.updateInventoryItem(id, req.user.branchId, data);
  }

  @Delete(':id')
  async remove(@Request() req, @Param('id') id: string) {
    return this.inventoryService.deleteInventoryItem(id, req.user.branchId);
  }
}