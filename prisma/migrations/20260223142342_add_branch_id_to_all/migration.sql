-- AlterTable
ALTER TABLE "categories" ADD COLUMN     "branch_id" TEXT;

-- AlterTable
ALTER TABLE "inventory_items" ADD COLUMN     "branch_id" TEXT;

-- AlterTable
ALTER TABLE "products" ADD COLUMN     "branch_id" TEXT;

-- AlterTable
ALTER TABLE "seating_tables" ADD COLUMN     "branch_id" TEXT;
