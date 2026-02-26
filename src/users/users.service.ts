import { Injectable } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import * as bcrypt from 'bcrypt';
import { Role } from '@prisma/client';

@Injectable()
export class UsersService {
  constructor(private prisma: PrismaService) {}

  async findAll(branchId: string) {
    return this.prisma.user.findMany({
      where: { branchId },
      select: { id: true, fullName: true, role: true, isActive: true, createdAt: true }, // Exclude PIN
    });
  }

  async create(branchId: string, data: { fullName: string; pin: string; role: Role }) {
    const hashedPin = await bcrypt.hash(data.pin, 10);
    return this.prisma.user.create({
      data: {
        ...data,
        pin: hashedPin,
        branchId,
      },
      select: { id: true, fullName: true, role: true }, // Return safe info
    });
  }

  async update(
    id: string,
    branchId: string,
    data: { fullName?: string; pin?: string; role?: Role; isActive?: boolean },
  ) {
    const { pin, ...rest } = data;
    const updateData: any = rest;

    if (pin) {
      updateData.pin = await bcrypt.hash(pin, 10);
    }

    return this.prisma.user.update({
      where: { id, branchId },
      data: updateData,
      select: { id: true, fullName: true, role: true, isActive: true },
    });
  }

  async remove(id: string, branchId: string) {
    return this.prisma.user.delete({ where: { id, branchId } });
  }
}