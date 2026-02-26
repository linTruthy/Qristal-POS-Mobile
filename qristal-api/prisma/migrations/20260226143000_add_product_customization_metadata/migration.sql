-- CreateEnum
CREATE TYPE "ProductionArea" AS ENUM ('KITCHEN', 'BARISTA', 'BAR', 'RETAIL', 'OTHER');

-- AlterTable
ALTER TABLE "products"
ADD COLUMN "production_area" "ProductionArea" NOT NULL DEFAULT 'KITCHEN',
ADD COLUMN "modifier_groups" TEXT[] DEFAULT ARRAY[]::TEXT[],
ADD COLUMN "sides" TEXT[] DEFAULT ARRAY[]::TEXT[];
