import {
  Body,
  Controller,
  Delete,
  Get,
  Param,
  Patch,
  Put,
  Post,
  Request,
  UseGuards,
} from '@nestjs/common';
import { AuthGuard } from '@nestjs/passport';
import { MenuService } from './menu.service';
import {
  sanitizeCreateProductInput,
  sanitizeUpdateProductInput,
} from './product.dto';

@Controller('products')
@UseGuards(AuthGuard('jwt'))
export class ProductsController {
  constructor(private readonly menuService: MenuService) {}

  @Get()
  findAll(@Request() req) {
    return this.menuService.getProducts(req.user.branchId);
  }

  @Post()
  create(@Request() req, @Body() payload: unknown) {
    const data = sanitizeCreateProductInput(payload);
    return this.menuService.createProduct(req.user.branchId, data);
  }

  @Patch(':id')
  update(@Request() req, @Param('id') id: string, @Body() payload: unknown) {
    const data = sanitizeUpdateProductInput(payload);
    return this.menuService.updateProduct(id, req.user.branchId, data);
  }


  @Put(':id')
  replace(@Request() req, @Param('id') id: string, @Body() payload: unknown) {
    const data = sanitizeUpdateProductInput(payload);
    return this.menuService.updateProduct(id, req.user.branchId, data);
  }

  @Delete(':id')
  remove(@Request() req, @Param('id') id: string) {
    return this.menuService.deleteProduct(id, req.user.branchId);
  }
}
