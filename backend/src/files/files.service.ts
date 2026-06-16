import {
  ForbiddenException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { createReadStream } from 'node:fs';
import { FileAssetKind, RoleCode } from '@prisma/client';
import type { AuthUser } from '../common/interfaces/auth-user.interface';
import { PrismaService } from '../prisma/prisma.service';

@Injectable()
export class FilesService {
  constructor(private readonly prisma: PrismaService) {}

  async getAuthorizedAsset(assetId: string, user: AuthUser) {
    const asset = await this.prisma.fileAsset.findUnique({
      where: { id: assetId },
      include: {
        banner: true,
        productImage: {
          include: {
            product: true,
          },
        },
        serviceFile: {
          include: {
            serviceOrder: {
              include: {
                assignments: {
                  include: {
                    deliveryUser: true,
                  },
                },
              },
            },
          },
        },
        generatedOrder: {
          include: {
            assignments: {
              include: {
                deliveryUser: true,
              },
            },
          },
        },
      },
    });

    if (!asset) {
      throw new NotFoundException('File not found.');
    }

    if (user.role === RoleCode.ADMIN) {
      return {
        ...asset,
        stream: createReadStream(asset.diskPath),
      };
    }

    if (
      asset.kind === FileAssetKind.PRODUCT_IMAGE ||
      asset.kind === FileAssetKind.BANNER_IMAGE
    ) {
      return {
        ...asset,
        stream: createReadStream(asset.diskPath),
      };
    }

    const serviceOrder = asset.serviceFile?.serviceOrder ?? asset.generatedOrder;
    if (!serviceOrder) {
      throw new ForbiddenException('You are not allowed to access this file.');
    }

    if (user.role === RoleCode.CUSTOMER && serviceOrder.customerId === user.userId) {
      return {
        ...asset,
        stream: createReadStream(asset.diskPath),
      };
    }

    if (
      user.role === RoleCode.DELIVERY &&
      serviceOrder.assignments.some(
        (assignment) => assignment.deliveryUser.userId === user.userId,
      )
    ) {
      return {
        ...asset,
        stream: createReadStream(asset.diskPath),
      };
    }

    throw new ForbiddenException('You are not allowed to access this file.');
  }
}
