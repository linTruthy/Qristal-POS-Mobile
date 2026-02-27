import { Module } from '@nestjs/common';
import { CategoriesController } from './categories.controller';
import { ProductsController } from './products.controller';
import { MenuService } from './menu.service';

@Module({
  controllers: [CategoriesController, ProductsController],
  providers: [MenuService]
})
export class MenuModule {}
