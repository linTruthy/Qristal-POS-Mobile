import { Injectable } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';

@Injectable()
export class MenuService {
  constructor(private prisma: PrismaService) {}

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

  // --- PRODUCTS ---
  getProducts(branchId: string) {
    return this.prisma.product.findMany({ 
        where: { branchId },
        include: { category: true } // Helpful for the Admin dashboard table
    });
  }
  createProduct(branchId: string, data: any) {
    return this.prisma.product.create({ data: { ...data, branchId } });
  }
  updateProduct(id: string, branchId: string, data: any) {
    return this.prisma.product.update({ where: { id, branchId }, data });
  }
  deleteProduct(id: string, branchId: string) {
    return this.prisma.product.delete({ where: { id, branchId } });
  }
}