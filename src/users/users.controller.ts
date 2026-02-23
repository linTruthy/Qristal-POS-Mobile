import { Controller, Get, Post, Body, Put, Param, Delete, UseGuards, Request } from '@nestjs/common';
import { UsersService } from './users.service';
import { AuthGuard } from '@nestjs/passport';

@Controller('users')
@UseGuards(AuthGuard('jwt'))
export class UsersController {
  constructor(private readonly usersService: UsersService) {}

  @Get()
  findAll(@Request() req) {
    return this.usersService.findAll(req.user.branchId);
  }

  @Post()
  create(@Request() req, @Body() data: any) {
    return this.usersService.create(req.user.branchId, data);
  }

  @Put(':id')
  update(@Request() req, @Param('id') id: string, @Body() data: any) {
    return this.usersService.update(id, req.user.branchId, data);
  }

  @Delete(':id')
  remove(@Request() req, @Param('id') id: string) {
    return this.usersService.remove(id, req.user.branchId);
  }
}