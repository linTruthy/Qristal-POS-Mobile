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

  return {
    name: data.name.trim(),
    price: parsedPrice,
    category: { connect: { id: data.categoryId } },
    isAvailable: typeof data.isAvailable === 'boolean' ? data.isAvailable : true,
    productionArea: data.productionArea
      ? (toProductionArea(data.productionArea) as never)
      : ('KITCHEN' as never),
    modifierGroups: toStringArray(data.modifierGroups, 'modifierGroups'),
    sides: toStringArray(data.sides, 'sides'),
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

  if ('modifierGroups' in data) {
    update.modifierGroups = toStringArray(data.modifierGroups, 'modifierGroups');
  }

  if ('sides' in data) {
    update.sides = toStringArray(data.sides, 'sides');
  }

  return update;
};
