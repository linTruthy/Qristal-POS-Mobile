import { Controller, Get, Post, Body, Put, Param, Delete, UseGuards, Request } from '@nestjs/common';
import { SeatingService } from './seating.service';
import { AuthGuard } from '@nestjs/passport';

@Controller('tables') // Endpoints will be /tables
@UseGuards(AuthGuard('jwt'))
export class SeatingController {
  constructor(private readonly seatingService: SeatingService) {}

  @Get()
  findAll(@Request() req) { return this.seatingService.findAll(req.user.branchId); }

  @Post()
  create(@Request() req, @Body() data: any) { return this.seatingService.create(req.user.branchId, data); }

  @Put(':id')
  update(@Request() req, @Param('id') id: string, @Body() data: any) { return this.seatingService.update(id, req.user.branchId, data); }

  @Delete(':id')
  remove(@Request() req, @Param('id') id: string) { return this.seatingService.remove(id, req.user.branchId); }
}