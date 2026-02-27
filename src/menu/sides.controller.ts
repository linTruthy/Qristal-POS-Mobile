import { Body, Controller, Delete, Get, Param, Patch, Post, Request, UseGuards } from '@nestjs/common';
import { AuthGuard } from '@nestjs/passport';
import { MenuService } from './menu.service';

@Controller('sides')
@UseGuards(AuthGuard('jwt'))
export class SidesController {
  constructor(private readonly menuService: MenuService) {}

  @Get()
  findAll(@Request() req) {
    return this.menuService.getSides(req.user.branchId);
  }

  @Post()
  create(@Request() req, @Body() data: any) {
    return this.menuService.createSide(req.user.branchId, data);
  }

  @Patch(':id')
  update(@Request() req, @Param('id') id: string, @Body() data: any) {
    return this.menuService.updateSide(id, req.user.branchId, data);
  }

  @Delete(':id')
  remove(@Request() req, @Param('id') id: string) {
    return this.menuService.deleteSide(id, req.user.branchId);
  }
}