import { Controller, Get, Param, Post, Body, UseGuards } from '@nestjs/common';
import { RoleCode } from '@prisma/client';
import { CurrentUser } from '../common/decorators/current-user.decorator';
import { Roles } from '../common/decorators/roles.decorator';
import { JwtAuthGuard } from '../common/guards/jwt-auth.guard';
import { RolesGuard } from '../common/guards/roles.guard';
import type { AuthUser } from '../common/interfaces/auth-user.interface';
import { FailDeliveryDto } from './dto/delivery.dto';
import { DeliveryService } from './delivery.service';

@Controller('delivery')
@UseGuards(JwtAuthGuard, RolesGuard)
@Roles(RoleCode.DELIVERY)
export class DeliveryController {
  constructor(private readonly deliveryService: DeliveryService) {}

  @Get('orders')
  listOrders(@CurrentUser() user: AuthUser) {
    return this.deliveryService.listOrders(user.userId);
  }

  @Get('orders/:id')
  getOrder(@CurrentUser() user: AuthUser, @Param('id') id: string) {
    return this.deliveryService.getOrder(user.userId, id);
  }

  @Post('orders/:id/pickup')
  pickup(@CurrentUser() user: AuthUser, @Param('id') id: string) {
    return this.deliveryService.pickupOrder(user.userId, id);
  }

  @Post('orders/:id/delivered')
  delivered(@CurrentUser() user: AuthUser, @Param('id') id: string) {
    return this.deliveryService.deliverOrder(user.userId, id);
  }

  @Post('orders/:id/failed')
  failed(
    @CurrentUser() user: AuthUser,
    @Param('id') id: string,
    @Body() dto: FailDeliveryDto,
  ) {
    return this.deliveryService.failOrder(user.userId, id, dto);
  }

  @Post('close-day')
  closeDay(@CurrentUser() user: AuthUser) {
    return this.deliveryService.closeDay(user.userId);
  }

  @Get('settlements')
  settlements(@CurrentUser() user: AuthUser) {
    return this.deliveryService.listSettlements(user.userId);
  }
}
