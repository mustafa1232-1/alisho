import {
  BadRequestException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import {
  FeeMode,
  FileAssetKind,
  NotificationType,
  ProductOrderStatus,
  RoleCode,
  ServiceOrderStatus,
  ServicePricingMode,
} from '@prisma/client';
import * as bcrypt from 'bcrypt';
import { buildAddressLabel } from '../common/utils/address.util';
import { applyFee, roundCurrency, toDecimal, toNumber } from '../common/utils/money.util';
import { normalizeForJson } from '../common/utils/serialize.util';
import { NotificationsService } from '../notifications/notifications.service';
import { PrismaService } from '../prisma/prisma.service';
import { StorageService } from '../storage/storage.service';
import {
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

@Injectable()
export class AdminService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly storageService: StorageService,
    private readonly notificationsService: NotificationsService,
  ) {}

  async listProducts() {
    const products = await this.prisma.product.findMany({
      where: { deletedAt: null },
      include: {
        images: { include: { fileAsset: true }, orderBy: { sortOrder: 'asc' } },
        optionGroups: { include: { values: true }, orderBy: { sortOrder: 'asc' } },
      },
      orderBy: { createdAt: 'desc' },
    });

    return normalizeForJson(
      products.map((product) => ({
        ...product,
        imageUrl: product.images[0] ? `/files/${product.images[0].fileAssetId}` : null,
      })),
    );
  }

  async createProduct(actorId: string, dto: CreateProductDto, image?: Express.Multer.File) {
    const product = await this.prisma.product.create({
      data: {
        name: dto.name,
        description: dto.description,
        price: toDecimal(Number(dto.price)),
        stock: Number(dto.stock),
        isAvailable: this.toBoolean(dto.isAvailable, true),
        isActive: this.toBoolean(dto.isActive, true),
        optionGroups: {
          create: this.parseOptionGroups(dto.optionGroupsJson).map((group, index) => ({
            name: group.name,
            isRequired: group.isRequired ?? false,
            sortOrder: group.sortOrder ?? index,
            values: {
              create: group.values.map((value, valueIndex) => ({
                value: value.value,
                priceModifier: toDecimal(Number(value.priceModifier ?? 0)),
                sortOrder: value.sortOrder ?? valueIndex,
              })),
            },
          })),
        },
      },
      include: {
        optionGroups: { include: { values: true } },
        images: { include: { fileAsset: true } },
      },
    });

    if (image) {
      const asset = await this.storageService.saveUploadedFile(
        image,
        FileAssetKind.PRODUCT_IMAGE,
        actorId,
      );
      await this.prisma.productImage.create({
        data: {
          productId: product.id,
          fileAssetId: asset.id,
          sortOrder: 0,
        },
      });
    }

    await this.createAudit(actorId, 'product.created', 'Product', product.id, {
      name: product.name,
    });

    return this.getProductEntity(product.id);
  }

  async updateProduct(
    actorId: string,
    productId: string,
    dto: UpdateProductDto,
    image?: Express.Multer.File,
  ) {
    const product = await this.prisma.product.findUnique({
      where: { id: productId },
    });
    if (!product || product.deletedAt) {
      throw new NotFoundException('Product not found.');
    }

    const data: Record<string, unknown> = {};
    if (dto.name !== undefined) data.name = dto.name;
    if (dto.description !== undefined) data.description = dto.description;
    if (dto.price !== undefined) data.price = toDecimal(Number(dto.price));
    if (dto.stock !== undefined) data.stock = Number(dto.stock);
    if (dto.isAvailable !== undefined) data.isAvailable = this.toBoolean(dto.isAvailable, true);
    if (dto.isActive !== undefined) data.isActive = this.toBoolean(dto.isActive, true);

    if (dto.optionGroupsJson) {
      data.optionGroups = {
        deleteMany: {},
        create: this.parseOptionGroups(dto.optionGroupsJson).map((group, index) => ({
          name: group.name,
          isRequired: group.isRequired ?? false,
          sortOrder: group.sortOrder ?? index,
          values: {
            create: group.values.map((value, valueIndex) => ({
              value: value.value,
              priceModifier: toDecimal(Number(value.priceModifier ?? 0)),
              sortOrder: value.sortOrder ?? valueIndex,
            })),
          },
        })),
      };
    }

    if (image) {
      const asset = await this.storageService.saveUploadedFile(
        image,
        FileAssetKind.PRODUCT_IMAGE,
        actorId,
      );
      data.images = {
        deleteMany: {},
        create: {
          fileAssetId: asset.id,
          sortOrder: 0,
        },
      };
    }

    await this.prisma.product.update({
      where: { id: productId },
      data,
    });

    await this.createAudit(actorId, 'product.updated', 'Product', productId, dto);
    return this.getProductEntity(productId);
  }

  async deleteProduct(actorId: string, productId: string) {
    await this.prisma.product.update({
      where: { id: productId },
      data: { deletedAt: new Date(), isActive: false },
    });
    await this.createAudit(actorId, 'product.deleted', 'Product', productId);
    return { success: true };
  }

  async updateProductAvailability(
    actorId: string,
    productId: string,
    dto: UpdateAvailabilityDto,
  ) {
    const product = await this.prisma.product.update({
      where: { id: productId },
      data: { isAvailable: this.toBoolean(dto.isAvailable, true) },
    });
    await this.createAudit(
      actorId,
      'product.availability.updated',
      'Product',
      productId,
      { isAvailable: product.isAvailable },
    );
    return product;
  }

  async replaceProductOptions(actorId: string, productId: string, optionGroupsJson: string) {
    await this.prisma.product.update({
      where: { id: productId },
      data: {
        optionGroups: {
          deleteMany: {},
          create: this.parseOptionGroups(optionGroupsJson).map((group, index) => ({
            name: group.name,
            isRequired: group.isRequired ?? false,
            sortOrder: group.sortOrder ?? index,
            values: {
              create: group.values.map((value, valueIndex) => ({
                value: value.value,
                priceModifier: toDecimal(Number(value.priceModifier ?? 0)),
                sortOrder: value.sortOrder ?? valueIndex,
              })),
            },
          })),
        },
      },
    });

    await this.createAudit(actorId, 'product.options.replaced', 'Product', productId);
    return this.getProductEntity(productId);
  }

  async listOrders() {
    const orders = await this.prisma.order.findMany({
      where: { deletedAt: null },
      include: this.orderInclude(),
      orderBy: { createdAt: 'desc' },
    });
    return normalizeForJson(orders.map((order) => this.serializeOrder(order)));
  }

  async getOrder(orderId: string) {
    const order = await this.prisma.order.findUnique({
      where: { id: orderId },
      include: this.orderInclude(),
    });
    if (!order) {
      throw new NotFoundException('Order not found.');
    }
    return normalizeForJson(this.serializeOrder(order));
  }

  async confirmOrder(actorId: string, orderId: string) {
    const order = await this.prisma.order.findUnique({
      where: { id: orderId },
    });
    if (!order) {
      throw new NotFoundException('Order not found.');
    }

    if (
      !(
        [
          ProductOrderStatus.PENDING_STORE_CONFIRMATION,
          ProductOrderStatus.REVISED_PENDING_STORE_CONFIRMATION,
        ] as ProductOrderStatus[]
      ).includes(order.status)
    ) {
      throw new BadRequestException('Order is not ready for confirmation.');
    }

    await this.prisma.order.update({
      where: { id: orderId },
      data: {
        status: ProductOrderStatus.CONFIRMED,
        statusHistory: {
          create: {
            status: ProductOrderStatus.CONFIRMED,
            notes: 'Confirmed by admin.',
            actorId,
          },
        },
      },
    });

    await this.notificationsService.notifyUser({
      userId: order.customerId,
      title: 'تم تأكيد الطلب',
      body: `تم تأكيد الطلب ${order.orderNumber}.`,
      type: NotificationType.ORDER_CONFIRMED,
      data: { orderId },
    });

    await this.createAudit(actorId, 'order.confirmed', 'Order', orderId);
    return this.getOrder(orderId);
  }

  async markOrderItemsUnavailable(actorId: string, orderId: string, dto: MarkUnavailableDto) {
    const order = await this.prisma.order.findUnique({
      where: { id: orderId },
      include: {
        items: {
          include: { product: true },
        },
      },
    });
    if (!order) {
      throw new NotFoundException('Order not found.');
    }

    const itemIds = new Set(dto.orderItemIds);
    const impactedItems = order.items.filter((item) => itemIds.has(item.id));
    if (!impactedItems.length) {
      throw new BadRequestException('No matching order items were found.');
    }

    const updatedSubtotal = roundCurrency(
      order.items
        .filter((item) => !itemIds.has(item.id))
        .reduce((sum, item) => sum + item.totalPrice.toNumber(), 0),
    );
    const finalTotal = roundCurrency(
      Math.max(
        0,
        updatedSubtotal +
          order.deliveryFee.toNumber() +
          order.serviceFee.toNumber() +
          order.extraFee.toNumber() -
          order.discount.toNumber(),
      ),
    );

    await this.prisma.$transaction(async (tx) => {
      await tx.orderItem.updateMany({
        where: { id: { in: dto.orderItemIds } },
        data: { isAvailable: false },
      });

      await tx.product.updateMany({
        where: { id: { in: impactedItems.flatMap((item) => item.productId ?? []) } },
        data: { isAvailable: false },
      });

      await tx.order.update({
        where: { id: orderId },
        data: {
          status:
            ProductOrderStatus.WAITING_CUSTOMER_APPROVAL_AFTER_UNAVAILABLE_ITEMS,
          unavailableItems: impactedItems.map((item) => ({
            orderItemId: item.id,
            productId: item.productId,
            productName: item.productName,
          })),
          subtotal: toDecimal(updatedSubtotal),
          finalTotal: toDecimal(finalTotal),
          statusHistory: {
            create: {
              status:
                ProductOrderStatus.WAITING_CUSTOMER_APPROVAL_AFTER_UNAVAILABLE_ITEMS,
              notes: dto.note ?? 'Admin marked one or more items unavailable.',
              actorId,
            },
          },
        },
      });
    });

    await this.notificationsService.notifyUser({
      userId: order.customerId,
      title: 'مادة غير متوفرة',
      body: 'تم تحديث الطلب بسبب نفاد بعض المواد. هل تريد المتابعة؟',
      type: NotificationType.ITEM_UNAVAILABLE,
      data: { orderId },
    });

    await this.createAudit(actorId, 'order.items.unavailable', 'Order', orderId, dto);
    return this.getOrder(orderId);
  }

  async assignDeliveryToOrder(actorId: string, orderId: string, dto: AssignDeliveryDto) {
    const order = await this.prisma.order.findUnique({ where: { id: orderId } });
    if (!order) {
      throw new NotFoundException('Order not found.');
    }

    const deliveryUser = await this.prisma.deliveryUser.findUnique({
      where: { id: dto.deliveryUserId },
      include: { user: true },
    });
    if (!deliveryUser || !deliveryUser.isActive || !deliveryUser.user.isActive) {
      throw new NotFoundException('Delivery user not found.');
    }

    await this.prisma.order.update({
      where: { id: orderId },
      data: {
        status: ProductOrderStatus.DELIVERY_ASSIGNED,
        assignments: {
          create: {
            targetType: 'PRODUCT',
            deliveryUserId: deliveryUser.id,
            etaText: dto.etaText,
          },
        },
        statusHistory: {
          create: {
            status: ProductOrderStatus.DELIVERY_ASSIGNED,
            notes: 'Delivery assigned by admin.',
            actorId,
          },
        },
      },
    });

    await Promise.all([
      this.notificationsService.notifyUser({
        userId: order.customerId,
        title: 'تم تعيين دلفري',
        body: 'تم تعيين دلفري لطلبك.',
        type: NotificationType.DELIVERY_ASSIGNED,
        data: { orderId, deliveryUserId: deliveryUser.id },
      }),
      this.notificationsService.notifyUser({
        userId: deliveryUser.userId,
        title: 'تم تعيين طلب جديد',
        body: `لديك طلب جديد رقم ${order.orderNumber}.`,
        type: NotificationType.DELIVERY_ASSIGNED,
        data: { orderId },
      }),
    ]);

    await this.createAudit(actorId, 'order.delivery.assigned', 'Order', orderId, dto);
    return this.getOrder(orderId);
  }

  async readyOrder(actorId: string, orderId: string) {
    const order = await this.prisma.order.findUnique({ where: { id: orderId } });
    if (!order) {
      throw new NotFoundException('Order not found.');
    }

    await this.prisma.order.update({
      where: { id: orderId },
      data: {
        status: ProductOrderStatus.READY_FOR_PICKUP,
        statusHistory: {
          create: {
            status: ProductOrderStatus.READY_FOR_PICKUP,
            notes: 'Order is ready for pickup.',
            actorId,
          },
        },
      },
    });

    await this.notificationsService.notifyUser({
      userId: order.customerId,
      title: 'تم تجهيز الطلب',
      body: 'تم تجهيز طلبك وأصبح جاهزاً للاستلام من الدلفري.',
      type: NotificationType.ORDER_READY,
      data: { orderId },
    });

    return this.getOrder(orderId);
  }

  async archiveOrder(actorId: string, orderId: string) {
    await this.prisma.order.update({
      where: { id: orderId },
      data: {
        status: ProductOrderStatus.ARCHIVED,
        statusHistory: {
          create: {
            status: ProductOrderStatus.ARCHIVED,
            notes: 'Archived by admin.',
            actorId,
          },
        },
      },
    });
    await this.createAudit(actorId, 'order.archived', 'Order', orderId);
    return { success: true };
  }

  async getKpis() {
    const todayStart = new Date();
    todayStart.setHours(0, 0, 0, 0);
    const monthStart = new Date(todayStart.getFullYear(), todayStart.getMonth(), 1);

    const [productOrders, serviceOrders, deliveryUsers, orderItems] = await Promise.all([
      this.prisma.order.findMany({ where: { deletedAt: null } }),
      this.prisma.serviceOrder.findMany({ where: { deletedAt: null } }),
      this.prisma.deliveryUser.findMany({
        include: { user: true, assignments: true },
      }),
      this.prisma.orderItem.findMany({
        include: { product: true },
        where: { productId: { not: null } },
      }),
    ]);

    const isActiveSaleStatus = (status: ProductOrderStatus | ServiceOrderStatus) =>
      !(
        [
          ProductOrderStatus.CANCELLED,
          ProductOrderStatus.FAILED_DELIVERY,
          ProductOrderStatus.RETURNED,
        ] as ProductOrderStatus[]
      ).includes(status as ProductOrderStatus) &&
      !(
        [
          ServiceOrderStatus.CANCELLED,
          ServiceOrderStatus.FAILED_DELIVERY,
          ServiceOrderStatus.RETURNED,
        ] as ServiceOrderStatus[]
      ).includes(status as ServiceOrderStatus);

    const salesToday = [
      ...productOrders.filter((order) => order.createdAt >= todayStart && isActiveSaleStatus(order.status)),
      ...serviceOrders.filter((order) => order.createdAt >= todayStart && isActiveSaleStatus(order.status)),
    ].reduce((sum, order) => sum + toNumber(order.finalTotal), 0);

    const salesMonth = [
      ...productOrders.filter((order) => order.createdAt >= monthStart && isActiveSaleStatus(order.status)),
      ...serviceOrders.filter((order) => order.createdAt >= monthStart && isActiveSaleStatus(order.status)),
    ].reduce((sum, order) => sum + toNumber(order.finalTotal), 0);

    const bestDelivery = deliveryUsers
      .map((deliveryUser) => ({
        id: deliveryUser.id,
        fullName: deliveryUser.user.fullName,
        deliveredCount: deliveryUser.assignments.filter((assignment) => assignment.deliveredAt).length,
        returnedCount: deliveryUser.assignments.filter((assignment) => assignment.failedAt).length,
      }))
      .sort((left, right) => right.deliveredCount - left.deliveredCount)[0] ?? null;

    const productPerformance = new Map<string, { name: string; quantity: number }>();
    for (const item of orderItems) {
      if (!item.productId || !item.product) {
        continue;
      }
      const current = productPerformance.get(item.productId) ?? {
        name: item.product.name,
        quantity: 0,
      };
      current.quantity += item.quantity;
      productPerformance.set(item.productId, current);
    }
    const sortedProducts = [...productPerformance.values()].sort(
      (left, right) => right.quantity - left.quantity,
    );

    return normalizeForJson({
      salesToday: roundCurrency(salesToday),
      salesMonth: roundCurrency(salesMonth),
      ordersToday:
        productOrders.filter((order) => order.createdAt >= todayStart).length +
        serviceOrders.filter((order) => order.createdAt >= todayStart).length,
      ordersMonth:
        productOrders.filter((order) => order.createdAt >= monthStart).length +
        serviceOrders.filter((order) => order.createdAt >= monthStart).length,
      pendingOrders: productOrders.filter(
        (order) =>
          order.status === ProductOrderStatus.PENDING_STORE_CONFIRMATION ||
          order.status === ProductOrderStatus.REVISED_PENDING_STORE_CONFIRMATION,
      ).length,
      confirmedOrders: productOrders.filter(
        (order) => order.status === ProductOrderStatus.CONFIRMED,
      ).length,
      ordersInDelivery:
        productOrders.filter(
          (order) =>
            order.status === ProductOrderStatus.DELIVERY_ASSIGNED ||
            order.status === ProductOrderStatus.OUT_FOR_DELIVERY,
        ).length +
        serviceOrders.filter(
          (order) =>
            order.status === ServiceOrderStatus.DELIVERY_ASSIGNED ||
            order.status === ServiceOrderStatus.OUT_FOR_DELIVERY,
        ).length,
      deliveredOrders:
        productOrders.filter((order) => order.status === ProductOrderStatus.DELIVERED).length +
        serviceOrders.filter((order) => order.status === ServiceOrderStatus.DELIVERED).length,
      returnedOrders:
        productOrders.filter(
          (order) =>
            order.status === ProductOrderStatus.FAILED_DELIVERY ||
            order.status === ProductOrderStatus.RETURNED,
        ).length +
        serviceOrders.filter(
          (order) =>
            order.status === ServiceOrderStatus.FAILED_DELIVERY ||
            order.status === ServiceOrderStatus.RETURNED,
        ).length,
      totalDiscounts: roundCurrency(
        productOrders.reduce((sum, order) => sum + toNumber(order.discount), 0),
      ),
      netSales: roundCurrency(
        [...productOrders, ...serviceOrders].reduce(
          (sum, order) => sum + toNumber(order.finalTotal),
          0,
        ),
      ),
      totalDeliveryFees: roundCurrency(
        [...productOrders, ...serviceOrders].reduce(
          (sum, order) => sum + toNumber(order.deliveryFee),
          0,
        ),
      ),
      totalServiceFees: roundCurrency(
        [...productOrders, ...serviceOrders].reduce(
          (sum, order) => sum + toNumber(order.serviceFee),
          0,
        ),
      ),
      bestSellingProduct: sortedProducts[0] ?? null,
      leastSellingProduct: sortedProducts.at(-1) ?? null,
      bestDelivery,
    });
  }

  async getSalesReport(query: Record<string, string | undefined>) {
    const { createdAt } = this.buildDateFilter(query);
    const [orders, serviceOrders] = await Promise.all([
      this.prisma.order.findMany({
        where: { deletedAt: null, ...(createdAt ? { createdAt } : {}) },
        orderBy: { createdAt: 'desc' },
      }),
      this.prisma.serviceOrder.findMany({
        where: { deletedAt: null, ...(createdAt ? { createdAt } : {}) },
        orderBy: { createdAt: 'desc' },
      }),
    ]);

    return normalizeForJson({
      productOrders: orders,
      serviceOrders,
      totalSales: roundCurrency(
        [...orders, ...serviceOrders].reduce(
          (sum, entry) => sum + toNumber(entry.finalTotal),
          0,
        ),
      ),
    });
  }

  async getOrdersReport(query: Record<string, string | undefined>) {
    const where = this.buildProductOrderWhere(query);
    const orders = await this.prisma.order.findMany({
      where,
      include: this.orderInclude(),
      orderBy: { createdAt: 'desc' },
    });
    return normalizeForJson({
      count: orders.length,
      orders: orders.map((order) => this.serializeOrder(order)),
    });
  }

  async getDiscountsReport(query: Record<string, string | undefined>) {
    const where = this.buildProductOrderWhere(query);
    const orders = await this.prisma.order.findMany({
      where: {
        ...where,
        discount: { gt: 0 },
      },
      orderBy: { createdAt: 'desc' },
    });
    return normalizeForJson({
      count: orders.length,
      totalDiscount: roundCurrency(
        orders.reduce((sum, order) => sum + order.discount.toNumber(), 0),
      ),
      orders,
    });
  }

  async getDeliveryReport(query: Record<string, string | undefined>) {
    const assignments = await this.prisma.deliveryAssignment.findMany({
      where: {
        ...(query.deliveryUserId ? { deliveryUserId: query.deliveryUserId } : {}),
      },
      include: {
        deliveryUser: { include: { user: true } },
        order: true,
        serviceOrder: true,
      },
      orderBy: { assignedAt: 'desc' },
    });

    return normalizeForJson({
      count: assignments.length,
      assignments,
    });
  }

  async getReturnsReport(query: Record<string, string | undefined>) {
    const productOrders = await this.prisma.order.findMany({
      where: {
        ...this.buildProductOrderWhere(query),
        status: {
          in: [ProductOrderStatus.FAILED_DELIVERY, ProductOrderStatus.RETURNED],
        },
      },
      include: this.orderInclude(),
      orderBy: { createdAt: 'desc' },
    });
    const serviceOrders = await this.prisma.serviceOrder.findMany({
      where: {
        ...this.buildServiceOrderWhere(query),
        status: {
          in: [ServiceOrderStatus.FAILED_DELIVERY, ServiceOrderStatus.RETURNED],
        },
      },
      include: this.serviceOrderInclude(),
      orderBy: { createdAt: 'desc' },
    });

    return normalizeForJson({
      productOrders: productOrders.map((order) => this.serializeOrder(order)),
      serviceOrders: serviceOrders.map((order) => this.serializeServiceOrder(order)),
    });
  }

  async getProductsReport(_query: Record<string, string | undefined>) {
    const items = await this.prisma.orderItem.findMany({
      where: {
        productId: { not: null },
        order: {
          status: {
            notIn: [ProductOrderStatus.CANCELLED, ProductOrderStatus.ARCHIVED],
          },
        },
      },
      include: { product: true, order: true },
    });

    const aggregates = new Map<string, { productId: string; productName: string; quantity: number; revenue: number }>();
    for (const item of items) {
      if (!item.productId) continue;
      const current = aggregates.get(item.productId) ?? {
        productId: item.productId,
        productName: item.productName,
        quantity: 0,
        revenue: 0,
      };
      current.quantity += item.quantity;
      current.revenue += item.totalPrice.toNumber();
      aggregates.set(item.productId, current);
    }

    return normalizeForJson(
      [...aggregates.values()].sort((left, right) => right.quantity - left.quantity),
    );
  }

  async listBanners() {
    const banners = await this.prisma.banner.findMany({
      where: { deletedAt: null },
      include: { imageAsset: true },
      orderBy: [{ sortOrder: 'asc' }, { createdAt: 'desc' }],
    });
    return normalizeForJson(
      banners.map((banner) => ({
        ...banner,
        imageUrl: banner.imageAssetId ? `/files/${banner.imageAssetId}` : null,
      })),
    );
  }

  async createBanner(actorId: string, dto: CreateBannerDto, image?: Express.Multer.File) {
    const asset = image
      ? await this.storageService.saveUploadedFile(image, FileAssetKind.BANNER_IMAGE, actorId)
      : null;
    const banner = await this.prisma.banner.create({
      data: {
        title: dto.title,
        description: dto.description,
        link: dto.link,
        sortOrder: this.toNumberValue(dto.sortOrder, 0),
        isActive: this.toBoolean(dto.isActive, true),
        imageAssetId: asset?.id,
      },
    });
    await this.createAudit(actorId, 'banner.created', 'Banner', banner.id);
    return banner;
  }

  async updateBanner(
    actorId: string,
    bannerId: string,
    dto: CreateBannerDto,
    image?: Express.Multer.File,
  ) {
    const data: Record<string, unknown> = {
      title: dto.title,
      description: dto.description,
      link: dto.link,
      sortOrder: this.toNumberValue(dto.sortOrder, 0),
      isActive: this.toBoolean(dto.isActive, true),
    };
    if (image) {
      const asset = await this.storageService.saveUploadedFile(
        image,
        FileAssetKind.BANNER_IMAGE,
        actorId,
      );
      data.imageAssetId = asset.id;
    }

    const banner = await this.prisma.banner.update({
      where: { id: bannerId },
      data,
    });
    await this.createAudit(actorId, 'banner.updated', 'Banner', banner.id);
    return banner;
  }

  async deleteBanner(actorId: string, bannerId: string) {
    await this.prisma.banner.update({
      where: { id: bannerId },
      data: { deletedAt: new Date(), isActive: false },
    });
    await this.createAudit(actorId, 'banner.deleted', 'Banner', bannerId);
    return { success: true };
  }

  async listPromoCodes() {
    return this.prisma.promoCode.findMany({
      where: { deletedAt: null },
      orderBy: { createdAt: 'desc' },
    });
  }

  async createPromoCode(actorId: string, dto: CreatePromoCodeDto) {
    const promoCode = await this.prisma.promoCode.create({
      data: {
        code: dto.code.trim().toUpperCase(),
        discountType: dto.discountType as FeeMode,
        value: toDecimal(Number(dto.value)),
        startsAt: new Date(dto.startsAt),
        endsAt: new Date(dto.endsAt),
        maxUses: dto.maxUses ? Number(dto.maxUses) : null,
        maxUsesPerUser: dto.maxUsesPerUser ? Number(dto.maxUsesPerUser) : null,
        isActive: this.toBoolean(dto.isActive, true),
      },
    });
    await this.createAudit(actorId, 'promo.created', 'PromoCode', promoCode.id);
    return promoCode;
  }

  async updatePromoCode(actorId: string, promoCodeId: string, dto: UpdatePromoCodeDto) {
    const promoCode = await this.prisma.promoCode.update({
      where: { id: promoCodeId },
      data: {
        code: dto.code?.trim().toUpperCase(),
        discountType: dto.discountType as FeeMode,
        value: toDecimal(Number(dto.value)),
        startsAt: new Date(dto.startsAt),
        endsAt: new Date(dto.endsAt),
        maxUses: dto.maxUses ? Number(dto.maxUses) : null,
        maxUsesPerUser: dto.maxUsesPerUser ? Number(dto.maxUsesPerUser) : null,
        isActive: this.toBoolean(dto.isActive, true),
      },
    });
    await this.createAudit(actorId, 'promo.updated', 'PromoCode', promoCode.id);
    return promoCode;
  }

  async deletePromoCode(actorId: string, promoCodeId: string) {
    await this.prisma.promoCode.update({
      where: { id: promoCodeId },
      data: { deletedAt: new Date(), isActive: false },
    });
    await this.createAudit(actorId, 'promo.deleted', 'PromoCode', promoCodeId);
    return { success: true };
  }

  async listServices() {
    return this.prisma.service.findMany({
      where: { deletedAt: null },
      orderBy: { createdAt: 'desc' },
    });
  }

  async createService(actorId: string, dto: CreateServiceDto) {
    const service = await this.prisma.service.create({
      data: {
        name: dto.name,
        description: dto.description,
        defaultPrice: dto.defaultPrice ? toDecimal(Number(dto.defaultPrice)) : null,
        pricingMode: dto.pricingMode as ServicePricingMode,
        requiresFiles: this.toBoolean(dto.requiresFiles, false),
        requiresImages: this.toBoolean(dto.requiresImages, false),
        isActive: this.toBoolean(dto.isActive, true),
      },
    });
    await this.createAudit(actorId, 'service.created', 'Service', service.id);
    return service;
  }

  async updateService(actorId: string, serviceId: string, dto: UpdateServiceDto) {
    const service = await this.prisma.service.update({
      where: { id: serviceId },
      data: {
        name: dto.name,
        description: dto.description,
        defaultPrice: dto.defaultPrice ? toDecimal(Number(dto.defaultPrice)) : null,
        pricingMode: dto.pricingMode as ServicePricingMode,
        requiresFiles: this.toBoolean(dto.requiresFiles, false),
        requiresImages: this.toBoolean(dto.requiresImages, false),
        isActive: this.toBoolean(dto.isActive, true),
      },
    });
    await this.createAudit(actorId, 'service.updated', 'Service', service.id);
    return service;
  }

  async deleteService(actorId: string, serviceId: string) {
    await this.prisma.service.update({
      where: { id: serviceId },
      data: { deletedAt: new Date(), isActive: false },
    });
    await this.createAudit(actorId, 'service.deleted', 'Service', serviceId);
    return { success: true };
  }

  async listServiceOrders() {
    const serviceOrders = await this.prisma.serviceOrder.findMany({
      where: { deletedAt: null },
      include: this.serviceOrderInclude(),
      orderBy: { createdAt: 'desc' },
    });
    return normalizeForJson(
      serviceOrders.map((order) => this.serializeServiceOrder(order)),
    );
  }

  async getServiceOrder(serviceOrderId: string) {
    const serviceOrder = await this.prisma.serviceOrder.findUnique({
      where: { id: serviceOrderId },
      include: this.serviceOrderInclude(),
    });
    if (!serviceOrder) {
      throw new NotFoundException('Service order not found.');
    }
    return normalizeForJson(this.serializeServiceOrder(serviceOrder));
  }

  async priceServiceOrder(
    actorId: string,
    serviceOrderId: string,
    dto: PriceServiceOrderDto,
  ) {
    const serviceOrder = await this.prisma.serviceOrder.findUnique({
      where: { id: serviceOrderId },
    });
    if (!serviceOrder) {
      throw new NotFoundException('Service order not found.');
    }

    const pricing = await this.calculateServicePricing(Number(dto.quotedPrice));
    await this.prisma.serviceOrder.update({
      where: { id: serviceOrderId },
      data: {
        quotedPrice: toDecimal(Number(dto.quotedPrice)),
        subtotal: toDecimal(pricing.subtotal),
        deliveryFee: toDecimal(pricing.deliveryFee),
        serviceFee: toDecimal(pricing.serviceFee),
        extraFee: toDecimal(pricing.extraFee),
        discount: toDecimal(0),
        finalTotal: toDecimal(pricing.finalTotal),
        status: ServiceOrderStatus.PRICED_WAITING_CUSTOMER_APPROVAL,
        statusHistory: {
          create: {
            status: ServiceOrderStatus.PRICED_WAITING_CUSTOMER_APPROVAL,
            notes: 'Admin priced the service order.',
            actorId,
          },
        },
      },
    });

    await this.notificationsService.notifyUser({
      userId: serviceOrder.customerId,
      title: 'تم تسعير خدمة الطباعة',
      body: `تم تحديد سعر جديد للطلب ${serviceOrder.orderNumber}.`,
      type: NotificationType.SERVICE_PRICE_SET,
      data: { serviceOrderId },
    });

    await this.createAudit(actorId, 'service-order.priced', 'ServiceOrder', serviceOrderId, dto);
    return this.getServiceOrder(serviceOrderId);
  }

  async printServiceOrder(actorId: string, serviceOrderId: string) {
    const serviceOrder = await this.prisma.serviceOrder.findUnique({
      where: { id: serviceOrderId },
      include: {
        files: { include: { fileAsset: true } },
        generatedPdfAsset: true,
      },
    });
    if (!serviceOrder) {
      throw new NotFoundException('Service order not found.');
    }

    const printableAssetId =
      serviceOrder.generatedPdfAssetId ??
      serviceOrder.files.find((file) => file.fileAsset.mimeType === 'application/pdf')
        ?.fileAssetId;

    await this.notificationsService.notifyUser({
      userId: serviceOrder.customerId,
      title: 'تم طباعة طلبك',
      body: `تمت معالجة الطباعة للطلب ${serviceOrder.orderNumber}.`,
      type: NotificationType.SERVICE_PRINTED,
      data: { serviceOrderId },
    });

    await this.createAudit(actorId, 'service-order.printed', 'ServiceOrder', serviceOrderId, {
      printableAssetId,
    });

    return {
      success: true,
      printableFileUrl: printableAssetId ? `/files/${printableAssetId}` : null,
    };
  }

  async confirmServiceOrder(actorId: string, serviceOrderId: string) {
    const serviceOrder = await this.prisma.serviceOrder.findUnique({
      where: { id: serviceOrderId },
    });
    if (!serviceOrder) {
      throw new NotFoundException('Service order not found.');
    }

    if (
      !(
        [
          ServiceOrderStatus.CUSTOMER_APPROVED_PRICE,
          ServiceOrderStatus.PRICED_WAITING_CUSTOMER_APPROVAL,
        ] as ServiceOrderStatus[]
      ).includes(serviceOrder.status)
    ) {
      throw new BadRequestException('Service order is not ready for confirmation.');
    }

    await this.prisma.serviceOrder.update({
      where: { id: serviceOrderId },
      data: {
        status: ServiceOrderStatus.CONFIRMED,
        statusHistory: {
          create: {
            status: ServiceOrderStatus.CONFIRMED,
            notes: 'Confirmed by admin.',
            actorId,
          },
        },
      },
    });

    await this.notificationsService.notifyUser({
      userId: serviceOrder.customerId,
      title: 'تم تأكيد الطلب',
      body: `تم تأكيد طلب الخدمة ${serviceOrder.orderNumber}.`,
      type: NotificationType.ORDER_CONFIRMED,
      data: { serviceOrderId },
    });

    return this.getServiceOrder(serviceOrderId);
  }

  async assignDeliveryToServiceOrder(
    actorId: string,
    serviceOrderId: string,
    dto: AssignDeliveryDto,
  ) {
    const serviceOrder = await this.prisma.serviceOrder.findUnique({
      where: { id: serviceOrderId },
    });
    if (!serviceOrder) {
      throw new NotFoundException('Service order not found.');
    }

    const deliveryUser = await this.prisma.deliveryUser.findUnique({
      where: { id: dto.deliveryUserId },
      include: { user: true },
    });
    if (!deliveryUser || !deliveryUser.user.isActive) {
      throw new NotFoundException('Delivery user not found.');
    }

    await this.prisma.serviceOrder.update({
      where: { id: serviceOrderId },
      data: {
        status: ServiceOrderStatus.DELIVERY_ASSIGNED,
        assignments: {
          create: {
            targetType: 'SERVICE',
            deliveryUserId: deliveryUser.id,
            etaText: dto.etaText,
          },
        },
        statusHistory: {
          create: {
            status: ServiceOrderStatus.DELIVERY_ASSIGNED,
            notes: 'Delivery assigned by admin.',
            actorId,
          },
        },
      },
    });

    await Promise.all([
      this.notificationsService.notifyUser({
        userId: serviceOrder.customerId,
        title: 'تم تعيين دلفري',
        body: 'تم تعيين دلفري لطلب الخدمة.',
        type: NotificationType.DELIVERY_ASSIGNED,
        data: { serviceOrderId },
      }),
      this.notificationsService.notifyUser({
        userId: deliveryUser.userId,
        title: 'تم تعيين طلب جديد',
        body: `تم تعيين طلب خدمة جديد رقم ${serviceOrder.orderNumber}.`,
        type: NotificationType.DELIVERY_ASSIGNED,
        data: { serviceOrderId },
      }),
    ]);

    return this.getServiceOrder(serviceOrderId);
  }

  async readyServiceOrder(actorId: string, serviceOrderId: string) {
    const serviceOrder = await this.prisma.serviceOrder.findUnique({
      where: { id: serviceOrderId },
    });
    if (!serviceOrder) {
      throw new NotFoundException('Service order not found.');
    }

    await this.prisma.serviceOrder.update({
      where: { id: serviceOrderId },
      data: {
        status: ServiceOrderStatus.READY_FOR_PICKUP,
        statusHistory: {
          create: {
            status: ServiceOrderStatus.READY_FOR_PICKUP,
            notes: 'Service order is ready for pickup.',
            actorId,
          },
        },
      },
    });

    await this.notificationsService.notifyUser({
      userId: serviceOrder.customerId,
      title: 'تم تجهيز الطلب',
      body: 'تم تجهيز طلب الخدمة.',
      type: NotificationType.ORDER_READY,
      data: { serviceOrderId },
    });

    return this.getServiceOrder(serviceOrderId);
  }

  async getSettings() {
    const [deliveryFee, serviceFee, appPreferences] = await Promise.all([
      this.prisma.deliveryFeeSetting.findFirstOrThrow(),
      this.prisma.serviceFeeSetting.findFirstOrThrow(),
      this.prisma.adminSetting.findUnique({ where: { key: 'app_preferences' } }),
    ]);

    return normalizeForJson({
      deliveryFee,
      serviceFee,
      appPreferences: appPreferences?.value ?? {},
    });
  }

  async updateSettings(actorId: string, dto: UpdateSettingsDto) {
    const deliveryFee = await this.prisma.deliveryFeeSetting.findFirstOrThrow();
    const serviceFee = await this.prisma.serviceFeeSetting.findFirstOrThrow();

    await Promise.all([
      this.prisma.deliveryFeeSetting.update({
        where: { id: deliveryFee.id },
        data: {
          mode: (dto.deliveryMode as FeeMode | undefined) ?? deliveryFee.mode,
          amount:
            dto.deliveryAmount !== undefined
              ? toDecimal(Number(dto.deliveryAmount))
              : deliveryFee.amount,
          isEnabled:
            dto.deliveryEnabled !== undefined
              ? this.toBoolean(dto.deliveryEnabled, deliveryFee.isEnabled)
              : deliveryFee.isEnabled,
        },
      }),
      this.prisma.serviceFeeSetting.update({
        where: { id: serviceFee.id },
        data: {
          mode: (dto.serviceMode as FeeMode | undefined) ?? serviceFee.mode,
          amount:
            dto.serviceAmount !== undefined
              ? toDecimal(Number(dto.serviceAmount))
              : serviceFee.amount,
          extraFeeAmount:
            dto.extraFeeAmount !== undefined
              ? toDecimal(Number(dto.extraFeeAmount))
              : serviceFee.extraFeeAmount,
          extraFeeEnabled:
            dto.extraFeeEnabled !== undefined
              ? this.toBoolean(dto.extraFeeEnabled, serviceFee.extraFeeEnabled)
              : serviceFee.extraFeeEnabled,
          isEnabled:
            dto.serviceEnabled !== undefined
              ? this.toBoolean(dto.serviceEnabled, serviceFee.isEnabled)
              : serviceFee.isEnabled,
        },
      }),
      this.prisma.adminSetting.upsert({
        where: { key: 'app_preferences' },
        update: {
          value: dto.appPreferencesJson ? JSON.parse(dto.appPreferencesJson) : {},
        },
        create: {
          key: 'app_preferences',
          value: dto.appPreferencesJson ? JSON.parse(dto.appPreferencesJson) : {},
        },
      }),
    ]);

    await this.createAudit(actorId, 'settings.updated', 'AdminSetting', 'app_preferences', dto);
    return this.getSettings();
  }

  async listDeliveryUsers() {
    const deliveryUsers = await this.prisma.deliveryUser.findMany({
      include: {
        user: true,
        _count: {
          select: {
            assignments: true,
            settlements: true,
          },
        },
      },
      orderBy: { createdAt: 'desc' },
    });

    return normalizeForJson(deliveryUsers);
  }

  async createDeliveryUser(actorId: string, dto: CreateDeliveryUserDto) {
    const existing = await this.prisma.user.findUnique({
      where: { phone: dto.phone },
    });
    if (existing) {
      throw new BadRequestException('Phone number already exists.');
    }

    const role = await this.prisma.role.findUnique({
      where: { code: RoleCode.DELIVERY },
    });
    if (!role) {
      throw new NotFoundException('Delivery role not found.');
    }

    const passwordHash = await bcrypt.hash(dto.password, 10);
    const isActive = this.toBoolean(dto.isActive, true);
    const user = await this.prisma.user.create({
      data: {
        fullName: dto.fullName.trim(),
        phone: dto.phone.trim(),
        passwordHash,
        roleId: role.id,
        isActive,
        deliveryProfile: {
          create: {
            vehicleInfo: dto.vehicleInfo?.trim() || null,
            notes: dto.notes?.trim() || null,
            isActive,
          },
        },
      },
      include: {
        deliveryProfile: true,
      },
    });

    await this.createAudit(actorId, 'delivery-user.created', 'User', user.id);
    return user;
  }

  async updateDeliveryUser(
    actorId: string,
    deliveryUserId: string,
    dto: UpdateDeliveryUserDto,
  ) {
    const deliveryUser = await this.prisma.deliveryUser.findUnique({
      where: { id: deliveryUserId },
    });
    if (!deliveryUser) {
      throw new NotFoundException('Delivery user not found.');
    }

    const userUpdate: Record<string, unknown> = {};
    if (dto.fullName !== undefined) userUpdate.fullName = dto.fullName;
    if (dto.phone !== undefined) userUpdate.phone = dto.phone;
    if (dto.password !== undefined) {
      userUpdate.passwordHash = await bcrypt.hash(dto.password, 10);
    }
    if (dto.isActive !== undefined) {
      userUpdate.isActive = this.toBoolean(dto.isActive, true);
    }

    await this.prisma.$transaction(async (tx) => {
      if (Object.keys(userUpdate).length) {
        await tx.user.update({
          where: { id: deliveryUser.userId },
          data: userUpdate,
        });
      }

      await tx.deliveryUser.update({
        where: { id: deliveryUserId },
        data: {
          vehicleInfo: dto.vehicleInfo,
          notes: dto.notes,
          isActive:
            dto.isActive !== undefined
              ? this.toBoolean(dto.isActive, true)
              : deliveryUser.isActive,
        },
      });
    });

    await this.createAudit(actorId, 'delivery-user.updated', 'DeliveryUser', deliveryUserId, dto);
    return this.prisma.deliveryUser.findUnique({
      where: { id: deliveryUserId },
      include: { user: true },
    });
  }

  private async getProductEntity(productId: string) {
    const product = await this.prisma.product.findUnique({
      where: { id: productId },
      include: {
        images: { include: { fileAsset: true }, orderBy: { sortOrder: 'asc' } },
        optionGroups: { include: { values: true }, orderBy: { sortOrder: 'asc' } },
      },
    });

    return normalizeForJson(product);
  }

  private async createAudit(
    actorId: string,
    action: string,
    entityType: string,
    entityId: string,
    payload?: unknown,
  ) {
    await this.prisma.auditLog.create({
      data: {
        actorId,
        action,
        entityType,
        entityId,
        payload: payload ? (payload as object) : undefined,
      },
    });
  }

  private parseOptionGroups(optionGroupsJson?: string) {
    if (!optionGroupsJson) {
      return [] as Array<{
        name: string;
        isRequired?: boolean;
        sortOrder?: number;
        values: Array<{ value: string; priceModifier?: number; sortOrder?: number }>;
      }>;
    }

    return JSON.parse(optionGroupsJson) as Array<{
      name: string;
      isRequired?: boolean;
      sortOrder?: number;
      values: Array<{ value: string; priceModifier?: number; sortOrder?: number }>;
    }>;
  }

  private toBoolean(value: string | undefined, fallback: boolean) {
    if (value === undefined) {
      return fallback;
    }
    return value === 'true' || value === '1';
  }

  private toNumberValue(value: string | undefined, fallback: number) {
    if (value === undefined || value === '') {
      return fallback;
    }
    return Number(value);
  }

  private async calculateServicePricing(subtotal: number) {
    const [deliveryFee, serviceFee] = await Promise.all([
      this.prisma.deliveryFeeSetting.findFirstOrThrow(),
      this.prisma.serviceFeeSetting.findFirstOrThrow(),
    ]);

    const calculatedDelivery = deliveryFee.isEnabled
      ? applyFee(subtotal, deliveryFee.amount.toNumber(), deliveryFee.mode)
      : 0;
    const calculatedService = serviceFee.isEnabled
      ? applyFee(subtotal, serviceFee.amount.toNumber(), serviceFee.mode)
      : 0;
    const extraFee = serviceFee.extraFeeEnabled
      ? serviceFee.extraFeeAmount.toNumber()
      : 0;

    return {
      subtotal,
      deliveryFee: calculatedDelivery,
      serviceFee: calculatedService,
      extraFee,
      finalTotal: roundCurrency(subtotal + calculatedDelivery + calculatedService + extraFee),
    };
  }

  private buildDateFilter(query: Record<string, string | undefined>) {
    const createdAt: { gte?: Date; lte?: Date } = {};
    if (query.dateFrom) createdAt.gte = new Date(query.dateFrom);
    if (query.dateTo) createdAt.lte = new Date(query.dateTo);
    return {
      createdAt: Object.keys(createdAt).length ? createdAt : undefined,
    };
  }

  private buildProductOrderWhere(query: Record<string, string | undefined>) {
    const { createdAt } = this.buildDateFilter(query);
    return {
      deletedAt: null,
      ...(createdAt ? { createdAt } : {}),
      ...(query.status ? { status: query.status as ProductOrderStatus } : {}),
    };
  }

  private buildServiceOrderWhere(query: Record<string, string | undefined>) {
    const { createdAt } = this.buildDateFilter(query);
    return {
      deletedAt: null,
      ...(createdAt ? { createdAt } : {}),
      ...(query.status ? { status: query.status as ServiceOrderStatus } : {}),
    };
  }

  private orderInclude() {
    return {
      address: true,
      customer: true,
      items: { include: { selectedOptions: true } },
      statusHistory: { orderBy: { createdAt: 'asc' } },
      assignments: {
        include: {
          deliveryUser: {
            include: { user: true },
          },
        },
      },
    } as const;
  }

  private serviceOrderInclude() {
    return {
      address: true,
      customer: true,
      service: true,
      files: { include: { fileAsset: true } },
      generatedPdfAsset: true,
      statusHistory: { orderBy: { createdAt: 'asc' } },
      assignments: {
        include: {
          deliveryUser: {
            include: { user: true },
          },
        },
      },
    } as const;
  }

  private serializeOrder(order: {
    address: {
      block: string;
      complex: string;
      building: string;
      apartment: string;
      streetAddress: string;
    };
    assignments: Array<{
      etaText: string | null;
      deliveryUser: { user: { fullName: string; phone: string } };
    }>;
  } & Record<string, unknown>) {
    return {
      ...order,
      addressLabel: buildAddressLabel(order.address),
      delivery:
        order.assignments[0]
          ? {
              fullName: order.assignments[0].deliveryUser.user.fullName,
              phone: order.assignments[0].deliveryUser.user.phone,
              etaText: order.assignments[0].etaText,
            }
          : null,
    };
  }

  private serializeServiceOrder(order: {
    address: {
      block: string;
      complex: string;
      building: string;
      apartment: string;
      streetAddress: string;
    };
    assignments: Array<{
      etaText: string | null;
      deliveryUser: { user: { fullName: string; phone: string } };
    }>;
    generatedPdfAssetId?: string | null;
    files?: Array<{ fileAssetId: string }>;
  } & Record<string, unknown>) {
    return {
      ...order,
      addressLabel: buildAddressLabel(order.address),
      generatedPdfUrl: order.generatedPdfAssetId
        ? `/files/${order.generatedPdfAssetId}`
        : null,
      files:
        order.files?.map((file) => ({
          ...file,
          fileUrl: `/files/${file.fileAssetId}`,
        })) ?? [],
      delivery:
        order.assignments[0]
          ? {
              fullName: order.assignments[0].deliveryUser.user.fullName,
              phone: order.assignments[0].deliveryUser.user.phone,
              etaText: order.assignments[0].etaText,
            }
          : null,
    };
  }
}
