import { Injectable, OnModuleInit } from '@nestjs/common';
import { PrismaClient, Prisma } from '@prisma/client';

@Injectable()
export class PrismaService extends PrismaClient implements OnModuleInit {
  async onModuleInit() {
    await this.$connect();
    
    // Add Middleware to enforce Soft Delete logic globally
    this.$use(async (params, next) => {
      if (params.model == 'User' || params.model == 'Product' || params.model == 'Category') {
        if (params.action == 'delete') {
          // Change delete to update
          params.action = 'update';
          params.args['data'] = { deletedAt: new Date() };
        }
        if (params.action == 'deleteMany') {
          // Change deleteMany to updateMany
          params.action = 'updateMany';
          if (params.args.data != undefined) {
            params.args.data['deletedAt'] = new Date();
          } else {
            params.args['data'] = { deletedAt: new Date() };
          }
        }
        
        // Filter out deleted items on find
        if (params.action === 'findUnique' || params.action === 'findFirst') {
          // Change to findFirst - you cannot filter by deletedAt on findUnique
          params.action = 'findFirst';
          params.args.where['deletedAt'] = null;
        }
        if (params.action === 'findMany') {
          if (params.args.where) {
            if (params.args.where.deletedAt == undefined) {
              params.args.where['deletedAt'] = null;
            }
          } else {
            params.args['where'] = { deletedAt: null };
          }
        }
      }
      return next(params);
    });
  }
}