import { Injectable } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';

@Injectable()
export class MenuService {
  constructor(private prisma: PrismaService) { }

  // --- CATEGORIES ---
  getCategories(branchId: string) {
    return this.prisma.category.findMany({ where: { branchId }, orderBy: { sortOrder: 'asc' } });
  }
  createCategory(branchId: string, data: any) {
    return this.prisma.category.create({ data: { ...data, branchId } });
  }
  updateCategory(id: string, branchId: string, data: any) {
    return this.prisma.category.update({ where: { id, branchId }, data });
  }
  deleteCategory(id: string, branchId: string) {
    return this.prisma.category.delete({ where: { id, branchId } });
  }

  // --- MODIFIER GROUPS ---
  getModifierGroups(branchId: string) {
    return this.prisma.modifierGroup.findMany({
      where: { branchId, deletedAt: null },
      include: {
        modifiers: {
          where: { deletedAt: null },
          orderBy: { sortOrder: 'asc' },
        },
      },
      orderBy: [{ sortOrder: 'asc' }, { name: 'asc' }],
    });
  }

  createModifierGroup(branchId: string, data: any) {
    return this.prisma.modifierGroup.create({
      data: {
        branchId,
        name: String(data.name || '').trim(),
        minSelect: Number(data.minSelect || 0),
        maxSelect: data.maxSelect == null || data.maxSelect === '' ? null : Number(data.maxSelect),
        isRequired: Boolean(data.isRequired),
        sortOrder: Number(data.sortOrder || 0),
      },
    });
  }

  updateModifierGroup(id: string, _branchId: string, data: any) {
    return this.prisma.modifierGroup.update({
      where: { id },
      data: {
        name: data.name,
        minSelect: data.minSelect == null ? undefined : Number(data.minSelect),
        maxSelect: data.maxSelect == null || data.maxSelect === '' ? null : Number(data.maxSelect),
        isRequired: typeof data.isRequired === 'boolean' ? data.isRequired : undefined,
        sortOrder: data.sortOrder == null ? undefined : Number(data.sortOrder),
      },
    });
  }

  deleteModifierGroup(id: string, _branchId: string) {
    return this.prisma.modifierGroup.update({
      where: { id },
      data: { deletedAt: new Date() },
    });
  }

  createModifier(modifierGroupId: string, _branchId: string, data: any) {
    return this.prisma.modifier.create({
      data: {
        modifierGroup: { connect: { id: modifierGroupId } },
        name: String(data.name || '').trim(),
        priceDelta: Number(data.priceDelta || 0),
        productionArea: data.productionArea || 'KITCHEN',
        isAvailable: data.isAvailable == null ? true : Boolean(data.isAvailable),
        sortOrder: Number(data.sortOrder || 0),
      },
    });
  }

  updateModifier(id: string, modifierGroupId: string, _branchId: string, data: any) {
    return this.prisma.modifier.update({
      where: { id },
      data: {
        name: data.name,
        priceDelta: data.priceDelta == null ? undefined : Number(data.priceDelta),
        productionArea: data.productionArea,
        isAvailable: typeof data.isAvailable === 'boolean' ? data.isAvailable : undefined,
        sortOrder: data.sortOrder == null ? undefined : Number(data.sortOrder),
      },
    });
  }

  deleteModifier(id: string, modifierGroupId: string, _branchId: string) {
    return this.prisma.modifier.update({
      where: { id },
      data: { deletedAt: new Date() },
    });
  }

  // --- SIDES LIBRARY ---
  getSides(branchId: string) {
    return this.prisma.side.findMany({
      where: { branchId, deletedAt: null },
      orderBy: [{ sortOrder: 'asc' }, { name: 'asc' }],
    });
  }

  createSide(branchId: string, data: any) {
    return this.prisma.side.create({
      data: {
        branchId,
        name: String(data.name || '').trim(),
        priceDelta: Number(data.priceDelta || 0),
        productionArea: data.productionArea || 'KITCHEN',
        isAvailable: data.isAvailable == null ? true : Boolean(data.isAvailable),
        sortOrder: Number(data.sortOrder || 0),
      },
    });
  }

  updateSide(id: string, _branchId: string, data: any) {
    return this.prisma.side.update({
      where: { id },
      data: {
        name: data.name,
        priceDelta: data.priceDelta == null ? undefined : Number(data.priceDelta),
        productionArea: data.productionArea,
        isAvailable: typeof data.isAvailable === 'boolean' ? data.isAvailable : undefined,
        sortOrder: data.sortOrder == null ? undefined : Number(data.sortOrder),
      },
    });
  }

  deleteSide(id: string, _branchId: string) {
    return this.prisma.side.update({
      where: { id },
      data: { deletedAt: new Date() },
    });
  }
}
