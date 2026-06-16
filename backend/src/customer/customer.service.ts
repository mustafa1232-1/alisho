import {
  BadRequestException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import {
  FileAssetKind,
  NotificationType,
  ProductOrderStatus,
  RoleCode,
  ServiceOrderStatus,
} from '@prisma/client';
import { buildAddressLabel } from '../common/utils/address.util';
import { applyFee, roundCurrency, toDecimal, toNumber } from '../common/utils/money.util';
import { normalizeForJson } from '../common/utils/serialize.util';
import { NotificationsService } from '../notifications/notifications.service';
import { PrismaService } from '../prisma/prisma.service';
import { StorageService } from '../storage/storage.service';
import {
  AddCartItemDto,
  ApplyPromoDto,
  CreateOrderDto,
  CreateServiceOrderDto,
  UpdateCartItemDto,
} from './dto/customer.dto';

@Injectable()
export class CustomerService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly notificationsService: NotificationsService,
    private readonly storageService: StorageService,
  ) {}

  async getHome(userId: string) {
    const [banners, products, services, notifications] = await Promise.all([
      this.prisma.banner.findMany({
        where: { isActive: true, deletedAt: null },
        include: { imageAsset: true },
        orderBy: [{ sortOrder: 'asc' }, { createdAt: 'desc' }],
        take: 5,
      }),
      this.prisma.product.findMany({
        where: { isActive: true, deletedAt: null },
        include: {
          images: {
            include: { fileAsset: true },
            orderBy: { sortOrder: 'asc' },
          },
        },
        orderBy: [{ isAvailable: 'desc' }, { createdAt: 'desc' }],
        take: 8,
      }),
      this.prisma.service.findMany({
        where: { isActive: true, deletedAt: null },
        orderBy: { createdAt: 'desc' },
        take: 6,
      }),
      this.prisma.notification.count({
        where: { userId, isRead: false },
      }),
    ]);

    return normalizeForJson({
      store: {
        nameAr: 'مكتبة عليشو',
        nameEn: 'Alisho Library',
      },
      banners: banners.map((banner) => ({
        ...banner,
        imageUrl: banner.imageAssetId ? `/files/${banner.imageAssetId}` : null,
      })),
      products: products.map((product) => this.serializeProduct(product)),
      services,
      unreadNotifications: notifications,
      quickActions: [
        'طلبات سريعة للطلاب',
        'إعادة طلب آخر طباعة',
        'مواد الأكثر طلبًا',
        'أرشيف ملفات الطباعة السابقة',
      ],
    });
  }

  async listProducts() {
    const products = await this.prisma.product.findMany({
      where: { isActive: true, deletedAt: null },
      include: {
        images: {
          include: { fileAsset: true },
          orderBy: { sortOrder: 'asc' },
        },
        optionGroups: {
          include: {
            values: {
              orderBy: { sortOrder: 'asc' },
            },
          },
          orderBy: { sortOrder: 'asc' },
        },
      },
      orderBy: [{ isAvailable: 'desc' }, { createdAt: 'desc' }],
    });

    return normalizeForJson(products.map((product) => this.serializeProduct(product)));
  }

  async getProduct(productId: string) {
    const product = await this.prisma.product.findFirst({
      where: { id: productId, isActive: true, deletedAt: null },
      include: {
        images: {
          include: { fileAsset: true },
          orderBy: { sortOrder: 'asc' },
        },
        optionGroups: {
          include: {
            values: {
              orderBy: { sortOrder: 'asc' },
            },
          },
          orderBy: { sortOrder: 'asc' },
        },
      },
    });

    if (!product) {
      throw new NotFoundException('Product not found.');
    }

    return normalizeForJson(this.serializeProduct(product));
  }

  async addCartItem(userId: string, dto: AddCartItemDto) {
    const cart = await this.ensureCart(userId);
    const product = await this.prisma.product.findFirst({
      where: {
        id: dto.productId,
        isActive: true,
        deletedAt: null,
      },
      include: {
        optionGroups: {
          include: { values: true },
        },
      },
    });

    if (!product) {
      throw new NotFoundException('Product not found.');
    }

    if (!product.isAvailable) {
      throw new BadRequestException('This product is currently unavailable.');
    }

    const selection = this.resolveProductSelection(
      product.price,
      product.optionGroups,
      dto.selectedOptionValueIds ?? [],
    );

    await this.prisma.cartItem.create({
      data: {
        cartId: cart.id,
        productId: product.id,
        quantity: dto.quantity,
        unitPrice: toDecimal(selection.unitPrice),
        selectedOptionsJson: selection.selectedOptions,
      },
    });

    return this.getCart(userId);
  }

  async updateCartItem(userId: string, cartItemId: string, dto: UpdateCartItemDto) {
    const cartItem = await this.prisma.cartItem.findFirst({
      where: {
        id: cartItemId,
        cart: { userId },
      },
      include: {
        product: {
          include: {
            optionGroups: {
              include: { values: true },
            },
          },
        },
      },
    });

    if (!cartItem) {
      throw new NotFoundException('Cart item not found.');
    }

    const data: Record<string, unknown> = {};
    if (dto.quantity) {
      data.quantity = dto.quantity;
    }

    if (dto.selectedOptionValueIds) {
      const selection = this.resolveProductSelection(
        cartItem.product.price,
        cartItem.product.optionGroups,
        dto.selectedOptionValueIds,
      );
      data.unitPrice = toDecimal(selection.unitPrice);
      data.selectedOptionsJson = selection.selectedOptions;
    }

    await this.prisma.cartItem.update({
      where: { id: cartItemId },
      data,
    });

    return this.getCart(userId);
  }

  async deleteCartItem(userId: string, cartItemId: string) {
    await this.prisma.cartItem.deleteMany({
      where: {
        id: cartItemId,
        cart: { userId },
      },
    });

    return this.getCart(userId);
  }

  async getCart(userId: string) {
    const cart = await this.ensureCart(userId);
    const detailedCart = await this.prisma.cart.findUniqueOrThrow({
      where: { id: cart.id },
      include: {
        promoCode: true,
        items: {
          include: {
            product: {
              include: {
                images: {
                  include: { fileAsset: true },
                  orderBy: { sortOrder: 'asc' },
                  take: 1,
                },
              },
            },
          },
          orderBy: { createdAt: 'asc' },
        },
      },
    });

    return this.serializeCart(detailedCart, userId);
  }

  async applyPromo(userId: string, dto: ApplyPromoDto) {
    const cart = await this.ensureCart(userId);
    await this.assertPromoCode(dto.code.trim().toUpperCase(), userId);

    await this.prisma.cart.update({
      where: { id: cart.id },
      data: {
        promoCode: {
          connect: { code: dto.code.trim().toUpperCase() },
        },
      },
    });

    return this.getCart(userId);
  }

  async createOrder(userId: string, dto: CreateOrderDto) {
    const cart = await this.ensureCart(userId);
    const detailedCart = await this.prisma.cart.findUniqueOrThrow({
      where: { id: cart.id },
      include: {
        promoCode: true,
        items: {
          include: {
            product: true,
          },
        },
      },
    });

    if (!detailedCart.items.length) {
      throw new BadRequestException('Cart is empty.');
    }

    const address = await this.resolveAddress(userId, dto.addressId);
    const pricing = await this.calculateProductPricing(detailedCart, userId);
    const orderNumber = this.generateOrderNumber('ORD');

    const order = await this.prisma.$transaction(async (tx) => {
      const createdOrder = await tx.order.create({
        data: {
          orderNumber,
          customerId: userId,
          addressId: address.id,
          notes: dto.notes,
          status: ProductOrderStatus.PENDING_STORE_CONFIRMATION,
          subtotal: toDecimal(pricing.subtotal),
          deliveryFee: toDecimal(pricing.deliveryFee),
          serviceFee: toDecimal(pricing.serviceFee),
          extraFee: toDecimal(pricing.extraFee),
          discount: toDecimal(pricing.discount),
          finalTotal: toDecimal(pricing.finalTotal),
          promoCodeId: detailedCart.promoCodeId,
          promoCodeCode: detailedCart.promoCode?.code ?? null,
          items: {
            create: detailedCart.items.map((item) => ({
              productId: item.productId,
              productName: item.product.name,
              productDescription: item.product.description,
              quantity: item.quantity,
              unitPrice: item.unitPrice,
              totalPrice: toDecimal(toNumber(item.unitPrice) * item.quantity),
              selectedOptions: {
                create:
                  ((item.selectedOptionsJson as Array<Record<string, unknown>> | null) ??
                    []
                  ).map((selectedOption) => ({
                    groupName: String(selectedOption.groupName),
                    valueName: String(selectedOption.valueName),
                    priceModifier: toDecimal(Number(selectedOption.priceModifier ?? 0)),
                  })),
              },
            })),
          },
          statusHistory: {
            create: {
              status: ProductOrderStatus.PENDING_STORE_CONFIRMATION,
              notes: 'Order created by customer.',
              actorId: userId,
            },
          },
        },
        include: {
          items: { include: { selectedOptions: true } },
          address: true,
          customer: { include: { role: true } },
        },
      });

      if (detailedCart.promoCodeId) {
        await tx.promoCodeUsage.create({
          data: {
            promoCodeId: detailedCart.promoCodeId,
            userId,
            orderId: createdOrder.id,
          },
        });
      }

      await tx.cartItem.deleteMany({
        where: { cartId: cart.id },
      });
      await tx.cart.update({
        where: { id: cart.id },
        data: { promoCodeId: null },
      });

      return createdOrder;
    });

    await this.notificationsService.notifyRole({
      role: RoleCode.ADMIN,
      title: 'طلب جديد',
      body: `تم إنشاء الطلب ${order.orderNumber}.`,
      type: NotificationType.ORDER_CREATED,
      data: { orderId: order.id, orderNumber: order.orderNumber },
    });

    return this.getOrder(userId, order.id);
  }

  async listOrders(userId: string) {
    const orders = await this.prisma.order.findMany({
      where: { customerId: userId, deletedAt: null },
      include: {
        address: true,
        items: { include: { selectedOptions: true } },
        assignments: {
          include: {
            deliveryUser: {
              include: { user: true },
            },
          },
        },
      },
      orderBy: { createdAt: 'desc' },
    });

    return normalizeForJson(
      orders.map((order) => ({
        ...order,
        addressLabel: buildAddressLabel(order.address),
        delivery:
          order.assignments[0]?.deliveryUser?.user
            ? {
                fullName: order.assignments[0].deliveryUser.user.fullName,
                phone: order.assignments[0].deliveryUser.user.phone,
                etaText: order.assignments[0].etaText,
              }
            : null,
      })),
    );
  }

  async getOrder(userId: string, orderId: string) {
    const order = await this.prisma.order.findFirst({
      where: { id: orderId, customerId: userId, deletedAt: null },
      include: {
        address: true,
        items: { include: { selectedOptions: true } },
        statusHistory: { orderBy: { createdAt: 'asc' } },
        assignments: {
          include: {
            deliveryUser: {
              include: { user: true },
            },
          },
        },
      },
    });

    if (!order) {
      throw new NotFoundException('Order not found.');
    }

    return normalizeForJson({
      ...order,
      addressLabel: buildAddressLabel(order.address),
      delivery:
        order.assignments[0]?.deliveryUser?.user
          ? {
              fullName: order.assignments[0].deliveryUser.user.fullName,
              phone: order.assignments[0].deliveryUser.user.phone,
              etaText: order.assignments[0].etaText,
            }
          : null,
    });
  }

  async approveRevisedOrder(userId: string, orderId: string) {
    const order = await this.prisma.order.findFirst({
      where: {
        id: orderId,
        customerId: userId,
        status:
          ProductOrderStatus.WAITING_CUSTOMER_APPROVAL_AFTER_UNAVAILABLE_ITEMS,
      },
      include: {
        items: true,
      },
    });

    if (!order) {
      throw new NotFoundException('Revised order not found.');
    }

    const availableItems = order.items.filter((item) => item.isAvailable);
    if (!availableItems.length) {
      throw new BadRequestException('No available items remain in the order.');
    }

    await this.prisma.order.update({
      where: { id: orderId },
      data: {
        status: ProductOrderStatus.REVISED_PENDING_STORE_CONFIRMATION,
        statusHistory: {
          create: {
            status: ProductOrderStatus.REVISED_PENDING_STORE_CONFIRMATION,
            notes: 'Customer approved revised order.',
            actorId: userId,
          },
        },
      },
    });

    await this.notificationsService.notifyRole({
      role: RoleCode.ADMIN,
      title: 'موافقة على طلب معدل',
      body: `الزبون وافق على الطلب المعدل ${order.orderNumber}.`,
      type: NotificationType.INVOICE_UPDATED,
      data: { orderId: order.id },
    });

    return this.getOrder(userId, orderId);
  }

  async cancelOrder(userId: string, orderId: string, reason?: string) {
    const order = await this.prisma.order.findFirst({
      where: { id: orderId, customerId: userId, deletedAt: null },
    });

    if (!order) {
      throw new NotFoundException('Order not found.');
    }

    await this.prisma.order.update({
      where: { id: orderId },
      data: {
        status: ProductOrderStatus.CANCELLED,
        failedReasonText: reason ?? null,
        statusHistory: {
          create: {
            status: ProductOrderStatus.CANCELLED,
            notes: reason ?? 'Cancelled by customer.',
            actorId: userId,
          },
        },
      },
    });

    return this.getOrder(userId, orderId);
  }

  async listNotifications(userId: string) {
    return this.notificationsService.listForUser(userId);
  }

  async listServices() {
    const services = await this.prisma.service.findMany({
      where: { isActive: true, deletedAt: null },
      orderBy: { createdAt: 'desc' },
    });

    return normalizeForJson(services);
  }

  async getService(serviceId: string) {
    const service = await this.prisma.service.findFirst({
      where: { id: serviceId, isActive: true, deletedAt: null },
    });

    if (!service) {
      throw new NotFoundException('Service not found.');
    }

    return normalizeForJson(service);
  }

  async createServiceOrder(
    userId: string,
    dto: CreateServiceOrderDto,
    files: Express.Multer.File[],
  ) {
    const service = await this.prisma.service.findFirst({
      where: { id: dto.serviceId, isActive: true, deletedAt: null },
    });

    if (!service) {
      throw new NotFoundException('Service not found.');
    }

    if (!files.length) {
      throw new BadRequestException('At least one file is required.');
    }

    const address = await this.resolveAddress(userId, dto.addressId);
    const uploads = await Promise.all(
      files.map((file) => this.validateAndSaveServiceFile(file, userId)),
    );
    const imageAssets = uploads.filter((asset) => asset.mimeType.startsWith('image/'));
    const generatedPdfAsset =
      imageAssets.length > 0
        ? await this.storageService.createPdfFromImages(
            imageAssets,
            userId,
            `${service.name}-images.pdf`,
          )
        : null;

    const serviceOrder = await this.prisma.serviceOrder.create({
      data: {
        orderNumber: this.generateOrderNumber('SVC'),
        customerId: userId,
        serviceId: service.id,
        addressId: address.id,
        notes: dto.notes,
        status: ServiceOrderStatus.UPLOADED_WAITING_ADMIN_REVIEW,
        generatedPdfAssetId: generatedPdfAsset?.id,
        files: {
          create: uploads.map((asset) => ({
            fileAssetId: asset.id,
          })),
        },
        statusHistory: {
          create: {
            status: ServiceOrderStatus.UPLOADED_WAITING_ADMIN_REVIEW,
            notes: 'Customer uploaded service files.',
            actorId: userId,
          },
        },
      },
    });

    await this.notificationsService.notifyRole({
      role: RoleCode.ADMIN,
      title: 'طلب خدمة جديد',
      body: `تم رفع ملفات جديدة للطلب ${serviceOrder.orderNumber}.`,
      type: NotificationType.SERVICE_ORDER_CREATED,
      data: { serviceOrderId: serviceOrder.id },
    });

    return this.getServiceOrder(userId, serviceOrder.id);
  }

  async listServiceOrders(userId: string) {
    const orders = await this.prisma.serviceOrder.findMany({
      where: { customerId: userId, deletedAt: null },
      include: {
        address: true,
        service: true,
        files: {
          include: {
            fileAsset: true,
          },
        },
        generatedPdfAsset: true,
        assignments: {
          include: {
            deliveryUser: {
              include: { user: true },
            },
          },
        },
      },
      orderBy: { createdAt: 'desc' },
    });

    return normalizeForJson(
      orders.map((order) => ({
        ...order,
        addressLabel: buildAddressLabel(order.address),
        generatedPdfUrl: order.generatedPdfAssetId
          ? `/files/${order.generatedPdfAssetId}`
          : null,
        files: order.files.map((file) => ({
          ...file,
          fileUrl: `/files/${file.fileAssetId}`,
        })),
      })),
    );
  }

  async getServiceOrder(userId: string, serviceOrderId: string) {
    const order = await this.prisma.serviceOrder.findFirst({
      where: { id: serviceOrderId, customerId: userId, deletedAt: null },
      include: {
        address: true,
        service: true,
        files: {
          include: { fileAsset: true },
        },
        generatedPdfAsset: true,
        statusHistory: { orderBy: { createdAt: 'asc' } },
        assignments: {
          include: {
            deliveryUser: {
              include: { user: true },
            },
          },
        },
      },
    });

    if (!order) {
      throw new NotFoundException('Service order not found.');
    }

    return normalizeForJson({
      ...order,
      addressLabel: buildAddressLabel(order.address),
      generatedPdfUrl: order.generatedPdfAssetId
        ? `/files/${order.generatedPdfAssetId}`
        : null,
      files: order.files.map((file) => ({
        ...file,
        fileUrl: `/files/${file.fileAssetId}`,
      })),
    });
  }

  async approveServicePrice(userId: string, serviceOrderId: string) {
    const order = await this.prisma.serviceOrder.findFirst({
      where: {
        id: serviceOrderId,
        customerId: userId,
        status: ServiceOrderStatus.PRICED_WAITING_CUSTOMER_APPROVAL,
      },
    });

    if (!order) {
      throw new NotFoundException('Priced service order not found.');
    }

    await this.prisma.serviceOrder.update({
      where: { id: serviceOrderId },
      data: {
        status: ServiceOrderStatus.CUSTOMER_APPROVED_PRICE,
        statusHistory: {
          create: {
            status: ServiceOrderStatus.CUSTOMER_APPROVED_PRICE,
            notes: 'Customer approved service quote.',
            actorId: userId,
          },
        },
      },
    });

    await this.notificationsService.notifyRole({
      role: RoleCode.ADMIN,
      title: 'موافقة على تسعير خدمة',
      body: `الزبون وافق على تسعير الطلب ${order.orderNumber}.`,
      type: NotificationType.SERVICE_PRICE_SET,
      data: { serviceOrderId: order.id },
    });

    return this.getServiceOrder(userId, serviceOrderId);
  }

  async cancelServiceOrder(userId: string, serviceOrderId: string, reason?: string) {
    const order = await this.prisma.serviceOrder.findFirst({
      where: { id: serviceOrderId, customerId: userId, deletedAt: null },
    });

    if (!order) {
      throw new NotFoundException('Service order not found.');
    }

    await this.prisma.serviceOrder.update({
      where: { id: serviceOrderId },
      data: {
        status: ServiceOrderStatus.CANCELLED,
        failedReasonText: reason ?? null,
        statusHistory: {
          create: {
            status: ServiceOrderStatus.CANCELLED,
            notes: reason ?? 'Cancelled by customer.',
            actorId: userId,
          },
        },
      },
    });

    return this.getServiceOrder(userId, serviceOrderId);
  }

  private async ensureCart(userId: string) {
    const existing = await this.prisma.cart.findUnique({
      where: { userId },
    });

    if (existing) {
      return existing;
    }

    return this.prisma.cart.create({
      data: { userId },
    });
  }

  private resolveProductSelection(
    basePrice: { toNumber: () => number },
    groups: Array<{
      id: string;
      name: string;
      isRequired: boolean;
      values: Array<{ id: string; value: string; priceModifier: { toNumber: () => number } }>;
    }>,
    selectedOptionValueIds: string[],
  ) {
    const normalizedIds = [...new Set(selectedOptionValueIds)];
    const selectedValues = groups.flatMap((group) =>
      group.values
        .filter((value) => normalizedIds.includes(value.id))
        .map((value) => ({
          groupId: group.id,
          groupName: group.name,
          valueId: value.id,
          valueName: value.value,
          priceModifier: value.priceModifier.toNumber(),
        })),
    );

    for (const group of groups.filter((group) => group.isRequired)) {
      const hasSelection = selectedValues.some((value) => value.groupId === group.id);
      if (!hasSelection) {
        throw new BadRequestException(
          `A selection is required for option group "${group.name}".`,
        );
      }
    }

    const unitPrice =
      basePrice.toNumber() +
      selectedValues.reduce((sum, entry) => sum + entry.priceModifier, 0);

    return {
      selectedOptions: selectedValues,
      unitPrice: roundCurrency(unitPrice),
    };
  }

  private async serializeCart(
    cart: {
      id: string;
      promoCode: {
        id: string;
        code: string;
        discountType: 'FIXED' | 'PERCENTAGE';
        value: { toNumber: () => number };
        startsAt: Date;
        endsAt: Date;
        isActive: boolean;
        maxUses: number | null;
        maxUsesPerUser: number | null;
      } | null;
      items: Array<{
        id: string;
        quantity: number;
        unitPrice: { toNumber: () => number };
        selectedOptionsJson: unknown;
        product: {
          id: string;
          name: string;
          description: string | null;
          isAvailable: boolean;
          images: Array<{
            fileAssetId: string;
          }>;
        };
      }>;
    },
    userId: string,
  ) {
    const pricing = await this.calculateProductPricing(cart, userId);

    return normalizeForJson({
      id: cart.id,
      promoCode: cart.promoCode?.code ?? null,
      items: cart.items.map((item) => ({
        id: item.id,
        quantity: item.quantity,
        unitPrice: item.unitPrice,
        totalPrice: toDecimal(item.unitPrice.toNumber() * item.quantity),
        selectedOptions: item.selectedOptionsJson ?? [],
        product: {
          id: item.product.id,
          name: item.product.name,
          description: item.product.description,
          isAvailable: item.product.isAvailable,
          imageUrl: item.product.images[0]
            ? `/files/${item.product.images[0].fileAssetId}`
            : null,
        },
      })),
      pricing,
    });
  }

  private async calculateProductPricing(
    cart: {
      promoCode: {
        id: string;
        code: string;
        discountType: 'FIXED' | 'PERCENTAGE';
        value: { toNumber: () => number };
      } | null;
      items: Array<{
        quantity: number;
        unitPrice: { toNumber: () => number };
      }>;
    },
    userId: string,
  ) {
    const [deliverySetting, serviceSetting] = await Promise.all([
      this.prisma.deliveryFeeSetting.findFirstOrThrow(),
      this.prisma.serviceFeeSetting.findFirstOrThrow(),
    ]);

    const subtotal = roundCurrency(
      cart.items.reduce(
        (sum, item) => sum + item.unitPrice.toNumber() * item.quantity,
        0,
      ),
    );

    const deliveryFee = deliverySetting.isEnabled
      ? applyFee(
          subtotal,
          deliverySetting.amount.toNumber(),
          deliverySetting.mode,
        )
      : 0;

    const serviceFee = serviceSetting.isEnabled
      ? applyFee(subtotal, serviceSetting.amount.toNumber(), serviceSetting.mode)
      : 0;

    const extraFee = serviceSetting.extraFeeEnabled
      ? serviceSetting.extraFeeAmount.toNumber()
      : 0;

    let discount = 0;
    let appliedPromoCode: string | null = null;
    if (cart.promoCode) {
      await this.assertPromoCode(cart.promoCode.code, userId);
      discount =
        cart.promoCode.discountType === 'PERCENTAGE'
          ? roundCurrency((subtotal * cart.promoCode.value.toNumber()) / 100)
          : roundCurrency(cart.promoCode.value.toNumber());
      appliedPromoCode = cart.promoCode.code;
    }

    const finalTotal = roundCurrency(
      Math.max(0, subtotal + deliveryFee + serviceFee + extraFee - discount),
    );

    return {
      subtotal,
      deliveryFee,
      serviceFee,
      extraFee,
      discount,
      finalTotal,
      promoCode: appliedPromoCode,
    };
  }

  private async calculateServicePricing(subtotal: number) {
    const [deliverySetting, serviceSetting] = await Promise.all([
      this.prisma.deliveryFeeSetting.findFirstOrThrow(),
      this.prisma.serviceFeeSetting.findFirstOrThrow(),
    ]);

    const deliveryFee = deliverySetting.isEnabled
      ? applyFee(
          subtotal,
          deliverySetting.amount.toNumber(),
          deliverySetting.mode,
        )
      : 0;
    const serviceFee = serviceSetting.isEnabled
      ? applyFee(subtotal, serviceSetting.amount.toNumber(), serviceSetting.mode)
      : 0;
    const extraFee = serviceSetting.extraFeeEnabled
      ? serviceSetting.extraFeeAmount.toNumber()
      : 0;

    return {
      subtotal,
      deliveryFee,
      serviceFee,
      extraFee,
      discount: 0,
      finalTotal: roundCurrency(subtotal + deliveryFee + serviceFee + extraFee),
    };
  }

  private async assertPromoCode(code: string, userId: string) {
    const promoCode = await this.prisma.promoCode.findFirst({
      where: {
        code,
        isActive: true,
        deletedAt: null,
        startsAt: { lte: new Date() },
        endsAt: { gte: new Date() },
      },
    });

    if (!promoCode) {
      throw new BadRequestException('Promo code is invalid or expired.');
    }

    const [totalUsageCount, userUsageCount] = await Promise.all([
      this.prisma.promoCodeUsage.count({ where: { promoCodeId: promoCode.id } }),
      this.prisma.promoCodeUsage.count({
        where: { promoCodeId: promoCode.id, userId },
      }),
    ]);

    if (promoCode.maxUses !== null && totalUsageCount >= promoCode.maxUses) {
      throw new BadRequestException('Promo code usage limit has been reached.');
    }

    if (
      promoCode.maxUsesPerUser !== null &&
      userUsageCount >= promoCode.maxUsesPerUser
    ) {
      throw new BadRequestException('Promo code usage limit per user reached.');
    }

    return promoCode;
  }

  private async resolveAddress(userId: string, addressId?: string) {
    const address = await this.prisma.address.findFirst({
      where: {
        id: addressId,
        userId,
        deletedAt: null,
      },
    });

    if (addressId && address) {
      return address;
    }

    const primary = await this.prisma.address.findFirst({
      where: { userId, deletedAt: null },
      orderBy: [{ isPrimary: 'desc' }, { createdAt: 'asc' }],
    });

    if (!primary) {
      throw new BadRequestException('Address not found for this customer.');
    }

    return primary;
  }

  private async validateAndSaveServiceFile(
    file: Express.Multer.File,
    userId: string,
  ) {
    const isPdf = file.mimetype === 'application/pdf';
    const isImage = file.mimetype === 'image/png' || file.mimetype === 'image/jpeg';
    if (!isPdf && !isImage) {
      throw new BadRequestException(
        'Only PDF, PNG, and JPEG files are supported for service uploads.',
      );
    }

    return this.storageService.saveUploadedFile(
      file,
      FileAssetKind.SERVICE_UPLOAD,
      userId,
    );
  }

  private serializeProduct(product: {
    id: string;
    name: string;
    description: string | null;
    price: { toNumber: () => number };
    stock: number;
    isAvailable: boolean;
    isActive: boolean;
    images: Array<{ fileAssetId: string }>;
    optionGroups?: Array<{
      id: string;
      name: string;
      isRequired: boolean;
      values: Array<{ id: string; value: string; priceModifier: { toNumber: () => number } }>;
    }>;
  }) {
    return {
      id: product.id,
      name: product.name,
      description: product.description,
      price: product.price.toNumber(),
      stock: product.stock,
      isAvailable: product.isAvailable,
      isActive: product.isActive,
      imageUrl: product.images[0] ? `/files/${product.images[0].fileAssetId}` : null,
      images: product.images.map((image) => ({
        fileAssetId: image.fileAssetId,
        url: `/files/${image.fileAssetId}`,
      })),
      optionGroups:
        product.optionGroups?.map((group) => ({
          id: group.id,
          name: group.name,
          isRequired: group.isRequired,
          values: group.values.map((value) => ({
            id: value.id,
            value: value.value,
            priceModifier: value.priceModifier.toNumber(),
          })),
        })) ?? [],
    };
  }

  private generateOrderNumber(prefix: 'ORD' | 'SVC') {
    const datePart = new Date().toISOString().slice(0, 10).replaceAll('-', '');
    const randomPart = Math.floor(1000 + Math.random() * 9000);
    return `${prefix}-${datePart}-${randomPart}`;
  }
}
