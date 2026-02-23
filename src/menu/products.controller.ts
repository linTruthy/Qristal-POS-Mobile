import { Controller, Get, Post, Body, Put, Param, Delete, UseGuards, Request } from '@nestjs/common';
import { MenuService } from './menu.service';
import { AuthGuard } from '@nestjs/passport';

@Controller('products')
@UseGuards(AuthGuard('jwt'))
export class ProductsController {
  constructor(private readonly menuService: MenuService) {}

  @Get()
  findAll(@Request() req) { return this.menuService.getProducts(req.user.branchId); }

  @Post()
  create(@Request() req, @Body() data: any) { return this.menuService.createProduct(req.user.branchId, data); }

  @Put(':id')
  update(@Request() req, @Param('id') id: string, @Body() data: any) { return this.menuService.updateProduct(id, req.user.branchId, data); }

  @Delete(':id')
  remove(@Request() req, @Param('id') id: string) { return this.menuService.deleteProduct(id, req.user.branchId); }
}