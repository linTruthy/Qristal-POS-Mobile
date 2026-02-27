import { BadRequestException } from '@nestjs/common';
import {
  sanitizeCreateProductInput,
  sanitizeUpdateProductInput,
} from './product.dto';

describe('product dto sanitizers', () => {
  it('sanitizes create payload including modifier metadata', () => {
    const data = sanitizeCreateProductInput({
      name: 'Latte',
      price: '12000',
      categoryId: 'cat-1',
      productionArea: 'BARISTA',
      modifierGroups: ['Shots', 'Strength', 'Shots'],
      sides: ['Cookie'],
    });

    expect(data.name).toBe('Latte');
    expect(data.price).toBe(12000);
    expect(data.productionArea).toBe('BARISTA');
    expect(data.modifierGroups).toEqual(['Shots', 'Strength']);
    expect(data.sides).toEqual(['Cookie']);
  });

  it('rejects invalid production area on update payload', () => {
    expect(() =>
      sanitizeUpdateProductInput({ productionArea: 'INVALID' }),
    ).toThrow(BadRequestException);
  });
});
