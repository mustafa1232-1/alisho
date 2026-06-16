import { Injectable } from '@nestjs/common';
import { NotificationType, Prisma, RoleCode } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';
import { NotificationsGateway } from './notifications.gateway';

@Injectable()
export class NotificationsService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly gateway: NotificationsGateway,
  ) {}

  async notifyUser(params: {
    userId: string;
    title: string;
    body: string;
    type: NotificationType;
    data?: Record<string, unknown>;
  }) {
    const notification = await this.prisma.notification.create({
      data: {
        userId: params.userId,
        title: params.title,
        body: params.body,
        type: params.type,
        data: (params.data ?? {}) as Prisma.InputJsonValue,
      },
    });

    this.gateway.emitNotification(params.userId, notification);
    return notification;
  }

  async notifyRole(params: {
    role: RoleCode;
    title: string;
    body: string;
    type: NotificationType;
    data?: Record<string, unknown>;
  }) {
    const users = await this.prisma.user.findMany({
      where: {
        role: {
          code: params.role,
        },
        isActive: true,
        deletedAt: null,
      },
      select: {
        id: true,
      },
    });

    return Promise.all(
      users.map((user: { id: string }) =>
        this.notifyUser({
          userId: user.id,
          title: params.title,
          body: params.body,
          type: params.type,
          data: params.data,
        }),
      ),
    );
  }

  async listForUser(userId: string) {
    return this.prisma.notification.findMany({
      where: { userId },
      orderBy: { createdAt: 'desc' },
    });
  }

  async markRead(userId: string, notificationId: string) {
    await this.prisma.notification.updateMany({
      where: {
        id: notificationId,
        userId,
      },
      data: {
        isRead: true,
        readAt: new Date(),
      },
    });

    return { success: true };
  }
}
