import { Body, Controller, Delete, Get, Param, Patch, Post, Request, UseGuards } from '@nestjs/common';
import { AuthGuard } from '@nestjs/passport';
import { MenuService } from './menu.service';

@Controller('modifier-groups')
@UseGuards(AuthGuard('jwt'))
export class ModifierGroupsController {
  constructor(private readonly menuService: MenuService) {}

  @Get()
  findAll(@Request() req) {
    return this.menuService.getModifierGroups(req.user.branchId);
  }

  @Post()
  create(@Request() req, @Body() data: any) {
    return this.menuService.createModifierGroup(req.user.branchId, data);
  }

  @Patch(':id')
  update(@Request() req, @Param('id') id: string, @Body() data: any) {
    return this.menuService.updateModifierGroup(id, req.user.branchId, data);
  }

  @Delete(':id')
  remove(@Request() req, @Param('id') id: string) {
    return this.menuService.deleteModifierGroup(id, req.user.branchId);
  }

  @Post(':id/modifiers')
  createModifier(@Request() req, @Param('id') modifierGroupId: string, @Body() data: any) {
    return this.menuService.createModifier(modifierGroupId, req.user.branchId, data);
  }

  @Patch(':groupId/modifiers/:modifierId')
  updateModifier(
    @Request() req,
    @Param('groupId') modifierGroupId: string,
    @Param('modifierId') modifierId: string,
    @Body() data: any,
  ) {
    return this.menuService.updateModifier(modifierId, modifierGroupId, req.user.branchId, data);
  }

  @Delete(':groupId/modifiers/:modifierId')
  removeModifier(
    @Request() req,
    @Param('groupId') modifierGroupId: string,
    @Param('modifierId') modifierId: string,
  ) {
    return this.menuService.deleteModifier(modifierId, modifierGroupId, req.user.branchId);
  }
}