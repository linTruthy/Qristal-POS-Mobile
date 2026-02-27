import { Injectable } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';

@Injectable()
export class ReportsService {
  constructor(private prisma: PrismaService) {}

  // 1. Sales Over Time (for charts)
  async getSalesHistory(branchId: string, startDate: Date, endDate: Date) {
    // Group by day using raw SQL for performance and date truncation
    // Note: This SQL syntax is specific to PostgreSQL
    const sales = await this.prisma.$queryRaw`
      SELECT 
        DATE_TRUNC('day', created_at) as date,
        SUM(total_amount) as total
      FROM orders
      WHERE branch_id = ${branchId}
        AND status = 'CLOSED'
        AND created_at BETWEEN ${startDate} AND ${endDate}
      GROUP BY DATE_TRUNC('day', created_at)
      ORDER BY date ASC;
    `;
    
    // Serialize bigints if any, though decimal usually comes as string/number
    return JSON.parse(JSON.stringify(sales, (key, value) =>
        typeof value === 'bigint' ? value.toString() : value
    ));
  }

  // 2. Top Selling Items
  async getTopSellingItems(branchId: string) {
    // Basic aggregation
    const result = await this.prisma.orderItem.groupBy({
      by: ['productId'],
      _sum: { quantity: true },
      where: {
        order: {
          branchId: branchId,
          status: 'CLOSED'
        }
      },
      orderBy: {
        _sum: { quantity: 'desc' }
      },
      take: 5
    });

    // Fetch product names for the IDs
    const enriched = await Promise.all(result.map(async (item) => {
        const product = await this.prisma.product.findUnique({ where: { id: item.productId }});
        return {
            name: product?.name || 'Unknown',
            quantity: item._sum.quantity
        };
    }));

    return enriched;
  }

  // 3. Payment Methods Breakdown
  async getPaymentSummary(branchId: string) {
    return this.prisma.payment.groupBy({
        by: ['method'],
        _sum: { amount: true },
        where: {
            order: { branchId: branchId }
        }
    });
  }
}