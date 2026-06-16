import {
  Body,
  Controller,
  Delete,
  Get,
  Param,
  Patch,
  Post,
  UploadedFiles,
  UseGuards,
  UseInterceptors,
} from '@nestjs/common';
import { FileFieldsInterceptor } from '@nestjs/platform-express';
import { RoleCode } from '@prisma/client';
import { memoryStorage } from 'multer';
import { CurrentUser } from '../common/decorators/current-user.decorator';
import { Roles } from '../common/decorators/roles.decorator';
import { JwtAuthGuard } from '../common/guards/jwt-auth.guard';
import { RolesGuard } from '../common/guards/roles.guard';
import type { AuthUser } from '../common/interfaces/auth-user.interface';
import {
  AddCartItemDto,
  ApplyPromoDto,
  CancelOrderDto,
  CreateOrderDto,
  CreateServiceOrderDto,
  UpdateCartItemDto,
} from './dto/customer.dto';
import { CustomerService } from './customer.service';

@Controller('customer')
@UseGuards(JwtAuthGuard, RolesGuard)
@Roles(RoleCode.CUSTOMER)
export class CustomerController {
  constructor(private readonly customerService: CustomerService) {}

  @Get('home')
  getHome(@CurrentUser() user: AuthUser) {
    return this.customerService.getHome(user.userId);
  }

  @Get('products')
  getProducts() {
    return this.customerService.listProducts();
  }

  @Get('products/:id')
  getProduct(@Param('id') id: string) {
    return this.customerService.getProduct(id);
  }

  @Post('cart/items')
  addCartItem(@CurrentUser() user: AuthUser, @Body() dto: AddCartItemDto) {
    return this.customerService.addCartItem(user.userId, dto);
  }

  @Patch('cart/items/:id')
  updateCartItem(
    @CurrentUser() user: AuthUser,
    @Param('id') id: string,
    @Body() dto: UpdateCartItemDto,
  ) {
    return this.customerService.updateCartItem(user.userId, id, dto);
  }

  @Delete('cart/items/:id')
  deleteCartItem(@CurrentUser() user: AuthUser, @Param('id') id: string) {
    return this.customerService.deleteCartItem(user.userId, id);
  }

  @Get('cart')
  getCart(@CurrentUser() user: AuthUser) {
    return this.customerService.getCart(user.userId);
  }

  @Post('cart/apply-promo')
  applyPromo(@CurrentUser() user: AuthUser, @Body() dto: ApplyPromoDto) {
    return this.customerService.applyPromo(user.userId, dto);
  }

  @Post('orders')
  createOrder(@CurrentUser() user: AuthUser, @Body() dto: CreateOrderDto) {
    return this.customerService.createOrder(user.userId, dto);
  }

  @Get('orders')
  listOrders(@CurrentUser() user: AuthUser) {
    return this.customerService.listOrders(user.userId);
  }

  @Get('orders/:id')
  getOrder(@CurrentUser() user: AuthUser, @Param('id') id: string) {
    return this.customerService.getOrder(user.userId, id);
  }

  @Post('orders/:id/approve-revised')
  approveRevised(@CurrentUser() user: AuthUser, @Param('id') id: string) {
    return this.customerService.approveRevisedOrder(user.userId, id);
  }

  @Post('orders/:id/cancel')
  cancelOrder(
    @CurrentUser() user: AuthUser,
    @Param('id') id: string,
    @Body() dto: CancelOrderDto,
  ) {
    return this.customerService.cancelOrder(user.userId, id, dto.reason);
  }

  @Get('notifications')
  listNotifications(@CurrentUser() user: AuthUser) {
    return this.customerService.listNotifications(user.userId);
  }

  @Get('services')
  listServices() {
    return this.customerService.listServices();
  }

  @Get('services/:id')
  getService(@Param('id') id: string) {
    return this.customerService.getService(id);
  }

  @Post('service-orders')
  @UseInterceptors(
    FileFieldsInterceptor([{ name: 'files', maxCount: 12 }], {
      storage: memoryStorage(),
      limits: { fileSize: 20 * 1024 * 1024 },
    }),
  )
  createServiceOrder(
    @CurrentUser() user: AuthUser,
    @Body() dto: CreateServiceOrderDto,
    @UploadedFiles()
    files: {
      files?: Express.Multer.File[];
    },
  ) {
    return this.customerService.createServiceOrder(
      user.userId,
      dto,
      files.files ?? [],
    );
  }

  @Get('service-orders')
  listServiceOrders(@CurrentUser() user: AuthUser) {
    return this.customerService.listServiceOrders(user.userId);
  }

  @Get('service-orders/:id')
  getServiceOrder(@CurrentUser() user: AuthUser, @Param('id') id: string) {
    return this.customerService.getServiceOrder(user.userId, id);
  }

  @Post('service-orders/:id/approve-price')
  approveServicePrice(@CurrentUser() user: AuthUser, @Param('id') id: string) {
    return this.customerService.approveServicePrice(user.userId, id);
  }

  @Post('service-orders/:id/cancel')
  cancelServiceOrder(
    @CurrentUser() user: AuthUser,
    @Param('id') id: string,
    @Body() dto: CancelOrderDto,
  ) {
    return this.customerService.cancelServiceOrder(user.userId, id, dto.reason);
  }
}
