/*
  Warnings:

  - Made the column `branch_id` on table `categories` required. This step will fail if there are existing NULL values in that column.
  - Made the column `branch_id` on table `inventory_items` required. This step will fail if there are existing NULL values in that column.
  - Made the column `branch_id` on table `products` required. This step will fail if there are existing NULL values in that column.
  - Made the column `branch_id` on table `seating_tables` required. This step will fail if there are existing NULL values in that column.

*/
-- AlterTable
ALTER TABLE "categories" ALTER COLUMN "branch_id" SET NOT NULL;

-- AlterTable
ALTER TABLE "inventory_items" ALTER COLUMN "branch_id" SET NOT NULL;

-- AlterTable
ALTER TABLE "products" ALTER COLUMN "branch_id" SET NOT NULL;

-- AlterTable
ALTER TABLE "seating_tables" ALTER COLUMN "branch_id" SET NOT NULL;
