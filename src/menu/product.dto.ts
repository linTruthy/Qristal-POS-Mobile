import { BadRequestException } from '@nestjs/common';
import { Prisma } from '@prisma/client';

export type ProductProductionArea = 'KITCHEN' | 'BARISTA' | 'BAR' | 'RETAIL' | 'OTHER';

const PRODUCTION_AREAS: ProductProductionArea[] = [
  'KITCHEN',
  'BARISTA',
  'BAR',
  'RETAIL',
  'OTHER',
];

const toStringArray = (value: unknown, field: string): string[] => {
  if (value == null) return [];
  if (!Array.isArray(value)) {
    throw new BadRequestException(`${field} must be an array of strings.`);
  }

  return Array.from(
    new Set(
      value
        .map((entry) => (typeof entry === 'string' ? entry.trim() : ''))
        .filter(Boolean),
    ),
  );
};

const toIdArray = (value: unknown, field: string): string[] => {
  const items = toStringArray(value, field);
  for (const id of items) {
    if (id.length < 8) {
      throw new BadRequestException(`${field} must contain valid ids.`);
    }
  }
  return items;
};

const toProductionArea = (value: unknown): ProductProductionArea => {
  if (typeof value !== 'string' || !PRODUCTION_AREAS.includes(value as ProductProductionArea)) {
    throw new BadRequestException(
      `productionArea must be one of: ${PRODUCTION_AREAS.join(', ')}`,
    );
  }

  return value as ProductProductionArea;
};

export const sanitizeCreateProductInput = (payload: unknown): Prisma.ProductCreateInput => {
  if (!payload || typeof payload !== 'object') {
    throw new BadRequestException('Invalid payload.');
  }

  const data = payload as Record<string, unknown>;
  if (typeof data.name !== 'string' || !data.name.trim()) {
    throw new BadRequestException('name is required.');
  }

  const parsedPrice = Number(data.price);
  if (!Number.isFinite(parsedPrice) || parsedPrice <= 0) {
    throw new BadRequestException('price must be a positive number.');
  }

  if (typeof data.categoryId !== 'string' || !data.categoryId.trim()) {
    throw new BadRequestException('categoryId is required.');
  }

  const modifierGroupIds = toIdArray(data.modifierGroupIds, 'modifierGroupIds');
  const sideIds = toIdArray(data.sideIds, 'sideIds');

  return {
    name: data.name.trim(),
    price: parsedPrice,
    category: { connect: { id: data.categoryId } },
    isAvailable: typeof data.isAvailable === 'boolean' ? data.isAvailable : true,
    productionArea: data.productionArea
      ? (toProductionArea(data.productionArea) as never)
      : ('KITCHEN' as never),
    productModifierGroups:
      modifierGroupIds.length > 0
        ? {
            create: modifierGroupIds.map((modifierGroupId) => ({
              modifierGroup: { connect: { id: modifierGroupId } },
            })),
          }
        : undefined,
    productSides:
      sideIds.length > 0
        ? {
            create: sideIds.map((sideId) => ({
              side: { connect: { id: sideId } },
            })),
          }
        : undefined,
  };
};

export const sanitizeUpdateProductInput = (payload: unknown): Prisma.ProductUpdateInput => {
  if (!payload || typeof payload !== 'object') {
    throw new BadRequestException('Invalid payload.');
  }

  const data = payload as Record<string, unknown>;
  const update: Prisma.ProductUpdateInput = {};

  if ('name' in data) {
    if (typeof data.name !== 'string' || !data.name.trim()) {
      throw new BadRequestException('name must be a non-empty string.');
    }
    update.name = data.name.trim();
  }

  if ('price' in data) {
    const parsedPrice = Number(data.price);
    if (!Number.isFinite(parsedPrice) || parsedPrice <= 0) {
      throw new BadRequestException('price must be a positive number.');
    }
    update.price = parsedPrice;
  }

  if ('categoryId' in data) {
    if (typeof data.categoryId !== 'string' || !data.categoryId.trim()) {
      throw new BadRequestException('categoryId must be a valid string.');
    }
    update.category = { connect: { id: data.categoryId } };
  }

  if ('isAvailable' in data) {
    if (typeof data.isAvailable !== 'boolean') {
      throw new BadRequestException('isAvailable must be a boolean.');
    }
    update.isAvailable = data.isAvailable;
  }

  if ('productionArea' in data) {
    update.productionArea = toProductionArea(data.productionArea) as never;
  }

  if ('modifierGroupIds' in data) {
    const modifierGroupIds = toIdArray(data.modifierGroupIds, 'modifierGroupIds');
    update.productModifierGroups = {
      deleteMany: {},
      create: modifierGroupIds.map((modifierGroupId) => ({
        modifierGroup: { connect: { id: modifierGroupId } },
      })),
    };
  }

  if ('sideIds' in data) {
    const sideIds = toIdArray(data.sideIds, 'sideIds');
    update.productSides = {
      deleteMany: {},
      create: sideIds.map((sideId) => ({
        side: { connect: { id: sideId } },
      })),
    };
  }

  return update;
};
