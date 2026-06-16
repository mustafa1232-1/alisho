import {
  BadRequestException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import {
  NotificationType,
  ProductOrderStatus,
  ServiceOrderStatus,
  SettlementStatus,
} from '@prisma/client';
import { buildAddressLabel } from '../common/utils/address.util';
import { roundCurrency, toDecimal, toNumber } from '../common/utils/money.util';
import { normalizeForJson } from '../common/utils/serialize.util';
import { NotificationsService } from '../notifications/notifications.service';
import { PrismaService } from '../prisma/prisma.service';
import { FailDeliveryDto } from './dto/delivery.dto';

@Injectable()
export class DeliveryService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly notificationsService: NotificationsService,
  ) {}

  async listOrders(userId: string) {
    const deliveryUser = await this.getDeliveryProfile(userId);
    const assignments = await this.prisma.deliveryAssignment.findMany({
      where: { deliveryUserId: deliveryUser.id },
      include: {
        order: {
          include: {
            customer: true,
            address: true,
          },
        },
        serviceOrder: {
          include: {
            customer: true,
            address: true,
            service: true,
          },
        },
      },
      orderBy: { assignedAt: 'desc' },
    });

    return normalizeForJson(assignments.map((assignment) => this.serializeAssignment(assignment)));
  }

  async getOrder(userId: string, id: string) {
    const deliveryUser = await this.getDeliveryProfile(userId);
    const assignment = await this.prisma.deliveryAssignment.findFirst({
      where: {
        deliveryUserId: deliveryUser.id,
        OR: [{ orderId: id }, { serviceOrderId: id }],
      },
      include: {
        order: {
          include: {
            customer: true,
            address: true,
            items: { include: { selectedOptions: true } },
          },
        },
        serviceOrder: {
          include: {
            customer: true,
            address: true,
            service: true,
            files: { include: { fileAsset: true } },
            generatedPdfAsset: true,
          },
        },
      },
    });

    if (!assignment) {
      throw new NotFoundException('Assigned order not found.');
    }

    return normalizeForJson(this.serializeAssignment(assignment));
  }

  async pickupOrder(userId: string, id: string) {
    const assignment = await this.findAssignedOrder(userId, id);
    await this.prisma.$transaction(async (tx) => {
      await tx.deliveryAssignment.update({
        where: { id: assignment.id },
        data: { pickedUpAt: new Date() },
      });

      if (assignment.orderId) {
        await tx.order.update({
          where: { id: assignment.orderId },
          data: {
            status: ProductOrderStatus.OUT_FOR_DELIVERY,
            statusHistory: {
              create: {
                status: ProductOrderStatus.OUT_FOR_DELIVERY,
                notes: 'Pickup confirmed by delivery user.',
                actorId: assignment.deliveryUser.userId,
              },
            },
          },
        });
      } else if (assignment.serviceOrderId) {
        await tx.serviceOrder.update({
          where: { id: assignment.serviceOrderId },
          data: {
            status: ServiceOrderStatus.OUT_FOR_DELIVERY,
            statusHistory: {
              create: {
                status: ServiceOrderStatus.OUT_FOR_DELIVERY,
                notes: 'Pickup confirmed by delivery user.',
                actorId: assignment.deliveryUser.userId,
              },
            },
          },
        });
      }
    });

    const customerId = assignment.order?.customerId ?? assignment.serviceOrder?.customerId;
    if (customerId) {
      await this.notificationsService.notifyUser({
        userId: customerId,
        title: 'الدلفري استلم الطلب',
        body: 'الدلفري استلم طلبك وهو في الطريق.',
        type: NotificationType.ORDER_PICKED_UP,
        data: { assignmentId: assignment.id },
      });
    }

    return this.getOrder(userId, id);
  }

  async deliverOrder(userId: string, id: string) {
    const assignment = await this.findAssignedOrder(userId, id);
    await this.prisma.$transaction(async (tx) => {
      await tx.deliveryAssignment.update({
        where: { id: assignment.id },
        data: { deliveredAt: new Date() },
      });

      if (assignment.orderId) {
        await tx.order.update({
          where: { id: assignment.orderId },
          data: {
            status: ProductOrderStatus.DELIVERED,
            statusHistory: {
              create: {
                status: ProductOrderStatus.DELIVERED,
                notes: 'Delivered by delivery user.',
                actorId: assignment.deliveryUser.userId,
              },
            },
          },
        });
      } else if (assignment.serviceOrderId) {
        await tx.serviceOrder.update({
          where: { id: assignment.serviceOrderId },
          data: {
            status: ServiceOrderStatus.DELIVERED,
            statusHistory: {
              create: {
                status: ServiceOrderStatus.DELIVERED,
                notes: 'Delivered by delivery user.',
                actorId: assignment.deliveryUser.userId,
              },
            },
          },
        });
      }
    });

    const customerId = assignment.order?.customerId ?? assignment.serviceOrder?.customerId;
    if (customerId) {
      await this.notificationsService.notifyUser({
        userId: customerId,
        title: 'تم التسليم',
        body: 'تم تسليم طلبك بنجاح.',
        type: NotificationType.ORDER_DELIVERED,
        data: { assignmentId: assignment.id },
      });
    }

    return this.getOrder(userId, id);
  }

  async failOrder(userId: string, id: string, dto: FailDeliveryDto) {
    const assignment = await this.findAssignedOrder(userId, id);
    const reasonText = dto.customReason
      ? `${dto.reason} - ${dto.customReason}`
      : dto.reason;

    await this.prisma.$transaction(async (tx) => {
      await tx.deliveryAssignment.update({
        where: { id: assignment.id },
        data: { failedAt: new Date() },
      });

      if (assignment.orderId) {
        await tx.order.update({
          where: { id: assignment.orderId },
          data: {
            status: ProductOrderStatus.FAILED_DELIVERY,
            failedReasonText: reasonText,
            statusHistory: {
              create: {
                status: ProductOrderStatus.FAILED_DELIVERY,
                notes: reasonText,
                actorId: assignment.deliveryUser.userId,
              },
            },
          },
        });
      } else if (assignment.serviceOrderId) {
        await tx.serviceOrder.update({
          where: { id: assignment.serviceOrderId },
          data: {
            status: ServiceOrderStatus.FAILED_DELIVERY,
            failedReasonText: reasonText,
            statusHistory: {
              create: {
                status: ServiceOrderStatus.FAILED_DELIVERY,
                notes: reasonText,
                actorId: assignment.deliveryUser.userId,
              },
            },
          },
        });
      }
    });

    await this.notificationsService.notifyRole({
      role: 'ADMIN',
      title: 'فشل تسليم طلب',
      body: `فشل تسليم الطلب بسبب: ${reasonText}`,
      type: NotificationType.ORDER_FAILED,
      data: { assignmentId: assignment.id },
    });

    return this.getOrder(userId, id);
  }

  async closeDay(userId: string) {
    const deliveryUser = await this.getDeliveryProfile(userId);
    const assignments = await this.prisma.deliveryAssignment.findMany({
      where: {
        deliveryUserId: deliveryUser.id,
        settlementItems: { none: {} },
        OR: [{ deliveredAt: { not: null } }, { failedAt: { not: null } }],
      },
      include: {
        order: true,
        serviceOrder: true,
      },
    });

    if (!assignments.length) {
      throw new BadRequestException('No completed deliveries are available for settlement.');
    }

    const delivered = assignments.filter((assignment) => assignment.deliveredAt);
    const returned = assignments.filter((assignment) => assignment.failedAt);
    const totalCollected = roundCurrency(
      delivered.reduce((sum, assignment) => {
        if (assignment.order) {
          return sum + assignment.order.finalTotal.toNumber();
        }
        if (assignment.serviceOrder) {
          return sum + assignment.serviceOrder.finalTotal.toNumber();
        }
        return sum;
      }, 0),
    );

    const settlement = await this.prisma.deliverySettlement.create({
      data: {
        deliveryUserId: deliveryUser.id,
        status: SettlementStatus.CLOSED,
        totalDeliveredCount: delivered.length,
        totalReturnedCount: returned.length,
        totalCollected: toDecimal(totalCollected),
        closedAt: new Date(),
        items: {
          create: assignments.map((assignment) => ({
            assignmentId: assignment.id,
            targetType: assignment.targetType,
            orderId: assignment.orderId,
            serviceOrderId: assignment.serviceOrderId,
            orderNumber:
              assignment.order?.orderNumber ?? assignment.serviceOrder?.orderNumber ?? 'N/A',
            amount: toDecimal(
              assignment.order
                ? assignment.order.finalTotal.toNumber()
                : assignment.serviceOrder?.finalTotal.toNumber() ?? 0,
            ),
            deliveredAt: assignment.deliveredAt ?? assignment.failedAt,
          })),
        },
      },
      include: {
        items: true,
      },
    });

    await this.notificationsService.notifyRole({
      role: 'ADMIN',
      title: 'إغلاق يوم دلفري',
      body: `تم إغلاق يوم الدلفري ${deliveryUser.user.fullName}.`,
      type: NotificationType.GENERIC,
      data: { settlementId: settlement.id },
    });

    return normalizeForJson(settlement);
  }

  async listSettlements(userId: string) {
    const deliveryUser = await this.getDeliveryProfile(userId);
    const settlements = await this.prisma.deliverySettlement.findMany({
      where: { deliveryUserId: deliveryUser.id },
      include: { items: true },
      orderBy: { createdAt: 'desc' },
    });
    return normalizeForJson(settlements);
  }

  private async getDeliveryProfile(userId: string) {
    const deliveryUser = await this.prisma.deliveryUser.findFirst({
      where: { userId },
      include: { user: true },
    });
    if (!deliveryUser) {
      throw new NotFoundException('Delivery profile not found.');
    }
    return deliveryUser;
  }

  private async findAssignedOrder(userId: string, id: string) {
    const deliveryUser = await this.getDeliveryProfile(userId);
    const assignment = await this.prisma.deliveryAssignment.findFirst({
      where: {
        deliveryUserId: deliveryUser.id,
        OR: [{ orderId: id }, { serviceOrderId: id }],
      },
      include: {
        deliveryUser: true,
        order: true,
        serviceOrder: true,
      },
    });
    if (!assignment) {
      throw new NotFoundException('Assigned order not found.');
    }
    return assignment;
  }

  private serializeAssignment(assignment: Record<string, any>) {
    const productOrder = assignment.order;
    const serviceOrder = assignment.serviceOrder;
    const address = productOrder?.address ?? serviceOrder?.address;
    const customer = productOrder?.customer ?? serviceOrder?.customer;
    const total =
      productOrder?.finalTotal?.toNumber?.() ?? serviceOrder?.finalTotal?.toNumber?.() ?? 0;

    return {
      assignmentId: assignment.id,
      targetType: assignment.targetType,
      orderId: assignment.orderId ?? assignment.serviceOrderId,
      orderNumber: productOrder?.orderNumber ?? serviceOrder?.orderNumber,
      status: productOrder?.status ?? serviceOrder?.status,
      customer: customer
        ? {
            fullName: customer.fullName,
            phone: customer.phone,
          }
        : null,
      address: address
        ? {
            ...address,
            label: buildAddressLabel(address),
          }
        : null,
      total,
      etaText: assignment.etaText,
      deliveredAt: assignment.deliveredAt,
      failedAt: assignment.failedAt,
      pickedUpAt: assignment.pickedUpAt,
    };
  }
}
