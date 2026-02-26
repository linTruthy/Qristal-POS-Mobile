-- DropIndex
DROP INDEX "inventory_items_sku_key";

-- AlterTable
ALTER TABLE "categories" ALTER COLUMN "branch_id" SET DEFAULT 'BRANCH-01';

-- AlterTable
ALTER TABLE "inventory_items" ALTER COLUMN "branch_id" SET DEFAULT 'BRANCH-01';

-- AlterTable
ALTER TABLE "orders" ADD COLUMN     "branch_id" TEXT NOT NULL DEFAULT 'BRANCH-01';

-- AlterTable
ALTER TABLE "products" ALTER COLUMN "branch_id" SET DEFAULT 'BRANCH-01';

-- AlterTable
ALTER TABLE "seating_tables" ALTER COLUMN "branch_id" SET DEFAULT 'BRANCH-01';

-- AlterTable
ALTER TABLE "shifts" ADD COLUMN     "branch_id" TEXT NOT NULL DEFAULT 'BRANCH-01';
