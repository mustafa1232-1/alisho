import { Injectable, Logger, OnModuleDestroy, OnModuleInit } from '@nestjs/common';
import {
  FeeMode,
  PrismaClient,
  RoleCode,
  ServicePricingMode,
  SettlementStatus,
} from '@prisma/client';
import * as bcrypt from 'bcrypt';

@Injectable()
export class PrismaService
  extends PrismaClient
  implements OnModuleInit, OnModuleDestroy
{
  private readonly logger = new Logger(PrismaService.name);

  async onModuleInit(): Promise<void> {
    await this.$connect();
    await this.bootstrapDefaults();
  }

  async onModuleDestroy(): Promise<void> {
    await this.$disconnect();
  }

  private async bootstrapDefaults(): Promise<void> {
    const roles = [
      { code: RoleCode.ADMIN, name: 'Admin' },
      { code: RoleCode.CUSTOMER, name: 'Customer' },
      { code: RoleCode.DELIVERY, name: 'Delivery' },
    ];

    await Promise.all(
      roles.map((role) =>
        this.role.upsert({
          where: { code: role.code },
          update: { name: role.name },
          create: role,
        }),
      ),
    );

    await this.ensureBootstrapAdmin();

    const deliverySetting = await this.deliveryFeeSetting.findFirst();
    if (!deliverySetting) {
      await this.deliveryFeeSetting.create({
        data: {
          mode: FeeMode.FIXED,
          amount: '1000',
          isEnabled: true,
        },
      });
    }

    const serviceSetting = await this.serviceFeeSetting.findFirst();
    if (!serviceSetting) {
      await this.serviceFeeSetting.create({
        data: {
          mode: FeeMode.FIXED,
          amount: '500',
          extraFeeAmount: '0',
          extraFeeEnabled: false,
          isEnabled: true,
        },
      });
    }

    const appPreferences = await this.adminSetting.findUnique({
      where: { key: 'app_preferences' },
    });

    if (!appPreferences) {
      await this.adminSetting.create({
        data: {
          key: 'app_preferences',
          value: {
            storeNameAr: 'مكتبة عليشو',
            storeNameEn: 'Alisho Library',
            primaryTheme: {
              background: '#F6F1E7',
              olive: '#6A7B4F',
              paper: '#9D7B5A',
              ink: '#24384A',
              accent: '#D58E4B',
            },
          },
        },
      });
    }

    const returnReasons = [
      'الزبون لا يرد',
      'الزبون لا يفتح الباب',
      'الزبون غير موجود',
      'العنوان غير واضح',
      'الزبون رفض الاستلام',
      'سبب آخر',
    ];

    await Promise.all(
      returnReasons.map((title) =>
        this.returnReason.upsert({
          where: { title },
          update: {},
          create: { title },
        }),
      ),
    );

    const settlementTemplate = await this.adminSetting.findUnique({
      where: { key: 'delivery_settlement_defaults' },
    });
    if (!settlementTemplate) {
      await this.adminSetting.create({
        data: {
          key: 'delivery_settlement_defaults',
          value: {
            status: SettlementStatus.CLOSED,
          },
        },
      });
    }

    const serviceCount = await this.service.count();
    if (!serviceCount) {
      await this.service.createMany({
        data: [
          {
            name: 'طباعة PDF',
            description: 'رفع ملفات PDF وطباعة مرتبة مع التوصيل.',
            defaultPrice: '250',
            pricingMode: ServicePricingMode.PER_PAGE,
            requiresFiles: true,
            requiresImages: false,
            isActive: true,
          },
          {
            name: 'طباعة صور',
            description: 'رفع صور متعددة وتحويلها إلى PDF مرتب قبل الطباعة.',
            defaultPrice: '250',
            pricingMode: ServicePricingMode.PER_PAGE,
            requiresFiles: false,
            requiresImages: true,
            isActive: true,
          },
        ],
      });
      this.logger.log('Bootstrapped default services.');
    }
  }

  private async ensureBootstrapAdmin(): Promise<void> {
    const phone = process.env.SEED_ADMIN_PHONE?.trim();
    const password = process.env.SEED_ADMIN_PASSWORD?.trim();

    if (!phone || !password) {
      return;
    }

    const adminRole = await this.role.findUnique({
      where: { code: RoleCode.ADMIN },
    });

    if (!adminRole) {
      return;
    }

    const passwordHash = await bcrypt.hash(password, 10);
    await this.user.upsert({
      where: { phone },
      update: {
        fullName: process.env.SEED_ADMIN_NAME?.trim() || 'Admin User',
        passwordHash,
        roleId: adminRole.id,
        isActive: true,
        deletedAt: null,
      },
      create: {
        fullName: process.env.SEED_ADMIN_NAME?.trim() || 'Admin User',
        phone,
        passwordHash,
        roleId: adminRole.id,
        isActive: true,
      },
    });
  }
}
