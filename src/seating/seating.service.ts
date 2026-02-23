import { Injectable } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';

@Injectable()
export class SeatingService {
  constructor(private prisma: PrismaService) {}

  findAll(branchId: string) {
    return this.prisma.seatingTable.findMany({ where: { branchId }, orderBy: { name: 'asc' } });
  }

  create(branchId: string, data: any) {
    return this.prisma.seatingTable.create({ data: { ...data, branchId } });
  }

  update(id: string, branchId: string, data: any) {
    return this.prisma.seatingTable.update({ where: { id, branchId }, data });
  }

  remove(id: string, branchId: string) {
    return this.prisma.seatingTable.delete({ where: { id, branchId } });
  }
}