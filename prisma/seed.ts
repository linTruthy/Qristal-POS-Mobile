import { PrismaClient } from '@prisma/client';
import * as bcrypt from 'bcrypt';

const prisma = new PrismaClient();

async function main() {
  console.log('Clearing database...');
  await prisma.orderItem.deleteMany();
  await prisma.order.deleteMany();
  await prisma.product.deleteMany();
  await prisma.category.deleteMany();
  await prisma.user.deleteMany();

  console.log('Seeding data...');

  // 1. Create a User
  const hashedPin = await bcrypt.hash('1234', 10);
  const admin = await prisma.user.create({
    data: {
      fullName: 'Admin User',
      pin: hashedPin,
      role: 'OWNER',
      branchId: 'BRANCH-01',
      isActive: true,
    },
  });

  // 2. Create Categories
  const catDrinks = await prisma.category.create({
    data: { name: 'Drinks', colorHex: '#3498db', sortOrder: 1 },
  });

  const catFood = await prisma.category.create({
    data: { name: 'Food', colorHex: '#e67e22', sortOrder: 2 },
  });

  // 3. Create Products
  await prisma.product.createMany({
    data: [
      {
        categoryId: catDrinks.id,
        name: 'Coffee',
        price: 2.50,
        isAvailable: true,
      },
      {
        categoryId: catDrinks.id,
        name: 'Soda',
        price: 1.50,
        isAvailable: true,
      },
      {
        categoryId: catFood.id,
        name: 'Burger',
        price: 8.50,
        isAvailable: true,
      },
      {
        categoryId: catFood.id,
        name: 'Fries',
        price: 3.00,
        isAvailable: true,
      },
    ],
  });
  
  console.log('Seeding Tables...');
  await prisma.seatingTable.createMany({
    data: [
      { name: 'T-01', status: 'FREE', floor: 'Main', x: 0, y: 0 },
      { name: 'T-02', status: 'FREE', floor: 'Main', x: 1, y: 0 },
      { name: 'T-03', status: 'OCCUPIED', floor: 'Main', x: 2, y: 0 }, // Mocking an active table
      { name: 'VIP-1', status: 'FREE', floor: 'VIP', x: 0, y: 1 },
    ]
  });

  console.log('Seed data created successfully!');
}

main()
  .catch((e) => {
    console.error(e);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });