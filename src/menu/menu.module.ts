import { Module } from '@nestjs/common';
import { CategoriesController } from './categories.controller';
import { ProductsController } from './products.controller';
import { MenuService } from './menu.service';
import { ModifierGroupsController } from './modifier-groups.controller';
import { SidesController } from './sides.controller';

@Module({
  controllers: [CategoriesController, ProductsController, ModifierGroupsController, SidesController],
  providers: [MenuService]
})
export class MenuModule {}
