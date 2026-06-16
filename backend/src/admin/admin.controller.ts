import {
  Body,
  Controller,
  Delete,
  Get,
  Param,
  Patch,
  Post,
  Query,
  UploadedFile,
  UseGuards,
  UseInterceptors,
} from '@nestjs/common';
import { FileInterceptor } from '@nestjs/platform-express';
import { RoleCode } from '@prisma/client';
import { memoryStorage } from 'multer';
import { CurrentUser } from '../common/decorators/current-user.decorator';
import { Roles } from '../common/decorators/roles.decorator';
import { JwtAuthGuard } from '../common/guards/jwt-auth.guard';
import { RolesGuard } from '../common/guards/roles.guard';
import type { AuthUser } from '../common/interfaces/auth-user.interface';
import {
  AddProductOptionsDto,
  AssignDeliveryDto,
  CreateBannerDto,
  CreateDeliveryUserDto,
  CreateProductDto,
  CreatePromoCodeDto,
  CreateServiceDto,
  MarkUnavailableDto,
  PriceServiceOrderDto,
  UpdateAvailabilityDto,
  UpdateDeliveryUserDto,
  UpdateProductDto,
  UpdatePromoCodeDto,
  UpdateServiceDto,
  UpdateSettingsDto,
} from './dto/admin.dto';
import { AdminService } from './admin.service';

@Controller('admin')
@UseGuards(JwtAuthGuard, RolesGuard)
@Roles(RoleCode.ADMIN)
export class AdminController {
  constructor(private readonly adminService: AdminService) {}

  @Get('products')
  listProducts() {
    return this.adminService.listProducts();
  }

  @Post('products')
  @UseInterceptors(FileInterceptor('image', { storage: memoryStorage() }))
  createProduct(
    @CurrentUser() user: AuthUser,
    @Body() dto: CreateProductDto,
    @UploadedFile() image?: Express.Multer.File,
  ) {
    return this.adminService.createProduct(user.userId, dto, image);
  }

  @Patch('products/:id')
  @UseInterceptors(FileInterceptor('image', { storage: memoryStorage() }))
  updateProduct(
    @CurrentUser() user: AuthUser,
    @Param('id') id: string,
    @Body() dto: UpdateProductDto,
    @UploadedFile() image?: Express.Multer.File,
  ) {
    return this.adminService.updateProduct(user.userId, id, dto, image);
  }

  @Delete('products/:id')
  deleteProduct(@CurrentUser() user: AuthUser, @Param('id') id: string) {
    return this.adminService.deleteProduct(user.userId, id);
  }

  @Patch('products/:id/availability')
  updateAvailability(
    @CurrentUser() user: AuthUser,
    @Param('id') id: string,
    @Body() dto: UpdateAvailabilityDto,
  ) {
    return this.adminService.updateProductAvailability(user.userId, id, dto);
  }

  @Post('products/:id/options')
  addProductOptions(
    @CurrentUser() user: AuthUser,
    @Param('id') id: string,
    @Body() dto: AddProductOptionsDto,
  ) {
    return this.adminService.replaceProductOptions(user.userId, id, dto.optionGroupsJson);
  }

  @Get('orders')
  listOrders() {
    return this.adminService.listOrders();
  }

  @Get('orders/:id')
  getOrder(@Param('id') id: string) {
    return this.adminService.getOrder(id);
  }

  @Post('orders/:id/confirm')
  confirmOrder(@CurrentUser() user: AuthUser, @Param('id') id: string) {
    return this.adminService.confirmOrder(user.userId, id);
  }

  @Post('orders/:id/mark-item-unavailable')
  markItemUnavailable(
    @CurrentUser() user: AuthUser,
    @Param('id') id: string,
    @Body() dto: MarkUnavailableDto,
  ) {
    return this.adminService.markOrderItemsUnavailable(user.userId, id, dto);
  }

  @Post('orders/:id/assign-delivery')
  assignDelivery(
    @CurrentUser() user: AuthUser,
    @Param('id') id: string,
    @Body() dto: AssignDeliveryDto,
  ) {
    return this.adminService.assignDeliveryToOrder(user.userId, id, dto);
  }

  @Post('orders/:id/ready')
  readyOrder(@CurrentUser() user: AuthUser, @Param('id') id: string) {
    return this.adminService.readyOrder(user.userId, id);
  }

  @Post('orders/:id/archive')
  archiveOrder(@CurrentUser() user: AuthUser, @Param('id') id: string) {
    return this.adminService.archiveOrder(user.userId, id);
  }

  @Get('dashboard/kpis')
  getKpis() {
    return this.adminService.getKpis();
  }

  @Get('reports/sales')
  getSalesReport(@Query() query: Record<string, string | undefined>) {
    return this.adminService.getSalesReport(query);
  }

  @Get('reports/orders')
  getOrdersReport(@Query() query: Record<string, string | undefined>) {
    return this.adminService.getOrdersReport(query);
  }

  @Get('reports/discounts')
  getDiscountsReport(@Query() query: Record<string, string | undefined>) {
    return this.adminService.getDiscountsReport(query);
  }

  @Get('reports/delivery')
  getDeliveryReport(@Query() query: Record<string, string | undefined>) {
    return this.adminService.getDeliveryReport(query);
  }

  @Get('reports/returns')
  getReturnsReport(@Query() query: Record<string, string | undefined>) {
    return this.adminService.getReturnsReport(query);
  }

  @Get('reports/products')
  getProductsReport(@Query() query: Record<string, string | undefined>) {
    return this.adminService.getProductsReport(query);
  }

  @Get('banners')
  listBanners() {
    return this.adminService.listBanners();
  }

  @Post('banners')
  @UseInterceptors(FileInterceptor('image', { storage: memoryStorage() }))
  createBanner(
    @CurrentUser() user: AuthUser,
    @Body() dto: CreateBannerDto,
    @UploadedFile() image?: Express.Multer.File,
  ) {
    return this.adminService.createBanner(user.userId, dto, image);
  }

  @Patch('banners/:id')
  @UseInterceptors(FileInterceptor('image', { storage: memoryStorage() }))
  updateBanner(
    @CurrentUser() user: AuthUser,
    @Param('id') id: string,
    @Body() dto: CreateBannerDto,
    @UploadedFile() image?: Express.Multer.File,
  ) {
    return this.adminService.updateBanner(user.userId, id, dto, image);
  }

  @Delete('banners/:id')
  deleteBanner(@CurrentUser() user: AuthUser, @Param('id') id: string) {
    return this.adminService.deleteBanner(user.userId, id);
  }

  @Get('promo-codes')
  listPromoCodes() {
    return this.adminService.listPromoCodes();
  }

  @Post('promo-codes')
  createPromoCode(@CurrentUser() user: AuthUser, @Body() dto: CreatePromoCodeDto) {
    return this.adminService.createPromoCode(user.userId, dto);
  }

  @Patch('promo-codes/:id')
  updatePromoCode(
    @CurrentUser() user: AuthUser,
    @Param('id') id: string,
    @Body() dto: UpdatePromoCodeDto,
  ) {
    return this.adminService.updatePromoCode(user.userId, id, dto);
  }

  @Delete('promo-codes/:id')
  deletePromoCode(@CurrentUser() user: AuthUser, @Param('id') id: string) {
    return this.adminService.deletePromoCode(user.userId, id);
  }

  @Get('services')
  listServices() {
    return this.adminService.listServices();
  }

  @Post('services')
  createService(@CurrentUser() user: AuthUser, @Body() dto: CreateServiceDto) {
    return this.adminService.createService(user.userId, dto);
  }

  @Patch('services/:id')
  updateService(
    @CurrentUser() user: AuthUser,
    @Param('id') id: string,
    @Body() dto: UpdateServiceDto,
  ) {
    return this.adminService.updateService(user.userId, id, dto);
  }

  @Delete('services/:id')
  deleteService(@CurrentUser() user: AuthUser, @Param('id') id: string) {
    return this.adminService.deleteService(user.userId, id);
  }

  @Get('service-orders')
  listServiceOrders() {
    return this.adminService.listServiceOrders();
  }

  @Get('service-orders/:id')
  getServiceOrder(@Param('id') id: string) {
    return this.adminService.getServiceOrder(id);
  }

  @Post('service-orders/:id/price')
  priceServiceOrder(
    @CurrentUser() user: AuthUser,
    @Param('id') id: string,
    @Body() dto: PriceServiceOrderDto,
  ) {
    return this.adminService.priceServiceOrder(user.userId, id, dto);
  }

  @Post('service-orders/:id/print')
  printServiceOrder(@CurrentUser() user: AuthUser, @Param('id') id: string) {
    return this.adminService.printServiceOrder(user.userId, id);
  }

  @Post('service-orders/:id/confirm')
  confirmServiceOrder(@CurrentUser() user: AuthUser, @Param('id') id: string) {
    return this.adminService.confirmServiceOrder(user.userId, id);
  }

  @Post('service-orders/:id/assign-delivery')
  assignServiceDelivery(
    @CurrentUser() user: AuthUser,
    @Param('id') id: string,
    @Body() dto: AssignDeliveryDto,
  ) {
    return this.adminService.assignDeliveryToServiceOrder(user.userId, id, dto);
  }

  @Post('service-orders/:id/ready')
  readyServiceOrder(@CurrentUser() user: AuthUser, @Param('id') id: string) {
    return this.adminService.readyServiceOrder(user.userId, id);
  }

  @Get('settings')
  getSettings() {
    return this.adminService.getSettings();
  }

  @Patch('settings')
  updateSettings(@CurrentUser() user: AuthUser, @Body() dto: UpdateSettingsDto) {
    return this.adminService.updateSettings(user.userId, dto);
  }

  @Get('delivery-users')
  listDeliveryUsers() {
    return this.adminService.listDeliveryUsers();
  }

  @Post('delivery-users')
  createDeliveryUser(
    @CurrentUser() user: AuthUser,
    @Body() dto: CreateDeliveryUserDto,
  ) {
    return this.adminService.createDeliveryUser(user.userId, dto);
  }

  @Patch('delivery-users/:id')
  updateDeliveryUser(
    @CurrentUser() user: AuthUser,
    @Param('id') id: string,
    @Body() dto: UpdateDeliveryUserDto,
  ) {
    return this.adminService.updateDeliveryUser(user.userId, id, dto);
  }
}
