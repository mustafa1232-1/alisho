import 'dotenv/config';
import { PrismaClient, RoleCode, CustomerType, FeeMode, ServicePricingMode } from '@prisma/client';
import * as bcrypt from 'bcrypt';

const prisma = new PrismaClient();
const seedAdminPhone = process.env.SEED_ADMIN_PHONE ?? '07700000000';
const seedAdminPassword = process.env.SEED_ADMIN_PASSWORD ?? 'Admin@12345';

async function upsertUser(params: {
  fullName: string;
  phone: string;
  password: string;
  roleCode: RoleCode;
  customerType?: CustomerType;
  studentStage?: string;
  jobTitle?: string;
  address?: {
    block: string;
    complex: string;
    building: string;
    apartment: string;
    streetAddress: string;
  };
}) {
  const role = await prisma.role.findUniqueOrThrow({
    where: { code: params.roleCode },
  });

  const passwordHash = await bcrypt.hash(params.password, 10);
  const user = await prisma.user.upsert({
    where: { phone: params.phone },
    update: {
      fullName: params.fullName,
      passwordHash,
      roleId: role.id,
      customerType: params.customerType,
      studentStage: params.studentStage,
      jobTitle: params.jobTitle,
      deletedAt: null,
      isActive: true,
    },
    create: {
      fullName: params.fullName,
      phone: params.phone,
      passwordHash,
      roleId: role.id,
      customerType: params.customerType,
      studentStage: params.studentStage,
      jobTitle: params.jobTitle,
    },
  });

  if (params.address) {
    const existingAddress = await prisma.address.findFirst({
      where: { userId: user.id, isPrimary: true },
    });

    if (!existingAddress) {
      await prisma.address.create({
        data: {
          userId: user.id,
          ...params.address,
          isPrimary: true,
        },
      });
    }
  }

  return user;
}

async function main() {
  const roles = [
    { code: RoleCode.ADMIN, name: 'Admin' },
    { code: RoleCode.CUSTOMER, name: 'Customer' },
    { code: RoleCode.DELIVERY, name: 'Delivery' },
  ];

  for (const role of roles) {
    await prisma.role.upsert({
      where: { code: role.code },
      update: { name: role.name },
      create: role,
    });
  }

  const admin = await upsertUser({
    fullName: 'Admin User',
    phone: seedAdminPhone,
    password: seedAdminPassword,
    roleCode: RoleCode.ADMIN,
  });

  const delivery = await upsertUser({
    fullName: 'Delivery User',
    phone: '07711111111',
    password: 'Delivery@12345',
    roleCode: RoleCode.DELIVERY,
  });

  await prisma.deliveryUser.upsert({
    where: { userId: delivery.id },
    update: {
      vehicleInfo: 'Bike',
      notes: 'Default seeded delivery user',
      isActive: true,
    },
    create: {
      userId: delivery.id,
      vehicleInfo: 'Bike',
      notes: 'Default seeded delivery user',
      isActive: true,
    },
  });

  await upsertUser({
    fullName: 'Customer User',
    phone: '07722222222',
    password: 'Customer@12345',
    roleCode: RoleCode.CUSTOMER,
    customerType: CustomerType.STUDENT,
    studentStage: 'الجامعة',
    address: {
      block: 'A',
      complex: 'A1',
      building: '101',
      apartment: '1',
      streetAddress: 'مجمع A1 - قرب البوابة الرئيسية',
    },
  });

  const products = [
    { name: 'دفاتر', description: 'دفاتر جامعية ومدرسية متنوعة.', price: 1500, stock: 200 },
    { name: 'أقلام', description: 'أقلام جافة وملونة.', price: 500, stock: 400 },
    { name: 'ملازم', description: 'ملازم دراسية مطبوعة وجاهزة.', price: 2500, stock: 80 },
    { name: 'أوراق A4', description: 'رزم ورق للطباعة.', price: 6000, stock: 50 },
    { name: 'ملفات', description: 'ملفات شفافة ومجلدات.', price: 1000, stock: 120 },
    { name: 'حبر', description: 'حبر طابعات وألوان متنوعة.', price: 7500, stock: 30 },
    { name: 'آلة حاسبة', description: 'آلات حاسبة للطلاب.', price: 12000, stock: 25 },
    { name: 'مواد مدرسية', description: 'مواد متنوعة للطلاب.', price: 2000, stock: 150 },
  ];

  for (const item of products) {
    await prisma.product.upsert({
      where: { id: `seed-${item.name}` },
      update: {},
      create: {
        id: `seed-${item.name}`,
        name: item.name,
        description: item.description,
        price: item.price.toString(),
        stock: item.stock,
        isAvailable: true,
        isActive: true,
      },
    });
  }

  const pen = await prisma.product.findUnique({
    where: { id: 'seed-أقلام' },
  });
  if (pen) {
    const optionGroup = await prisma.productOptionGroup.findFirst({
      where: { productId: pen.id, name: 'اللون' },
    });

    if (!optionGroup) {
      await prisma.productOptionGroup.create({
        data: {
          productId: pen.id,
          name: 'اللون',
          isRequired: true,
          values: {
            create: [
              { value: 'أزرق', priceModifier: '0' },
              { value: 'أسود', priceModifier: '0' },
              { value: 'أحمر', priceModifier: '100' },
            ],
          },
        },
      });
    }
  }

  const services = [
    { name: 'طباعة PDF', pricingMode: ServicePricingMode.PER_PAGE, requiresFiles: true, requiresImages: false },
    { name: 'طباعة صور', pricingMode: ServicePricingMode.PER_PAGE, requiresFiles: false, requiresImages: true },
    { name: 'طباعة ملازم', pricingMode: ServicePricingMode.MANUAL_REVIEW, requiresFiles: true, requiresImages: false },
    { name: 'تصوير مستندات', pricingMode: ServicePricingMode.PER_PAGE, requiresFiles: true, requiresImages: true },
    { name: 'تغليف', pricingMode: ServicePricingMode.PER_FILE, requiresFiles: false, requiresImages: false },
  ];

  for (const service of services) {
    const existingService = await prisma.service.findFirst({
      where: { name: service.name, deletedAt: null },
    });

    if (existingService) {
      await prisma.service.update({
        where: { id: existingService.id },
        data: {
          pricingMode: service.pricingMode,
          requiresFiles: service.requiresFiles,
          requiresImages: service.requiresImages,
          isActive: true,
        },
      });
    } else {
      await prisma.service.create({
        data: {
          name: service.name,
          description: service.name,
          defaultPrice: '250',
          pricingMode: service.pricingMode,
          requiresFiles: service.requiresFiles,
          requiresImages: service.requiresImages,
          isActive: true,
        },
      });
    }
  }

  await prisma.promoCode.upsert({
    where: { code: 'ALISHO10' },
    update: {
      discountType: FeeMode.PERCENTAGE,
      value: '10',
      isActive: true,
      startsAt: new Date('2026-01-01T00:00:00.000Z'),
      endsAt: new Date('2027-01-01T00:00:00.000Z'),
    },
    create: {
      code: 'ALISHO10',
      discountType: FeeMode.PERCENTAGE,
      value: '10',
      startsAt: new Date('2026-01-01T00:00:00.000Z'),
      endsAt: new Date('2027-01-01T00:00:00.000Z'),
      maxUses: 1000,
      maxUsesPerUser: 5,
      isActive: true,
    },
  });

  await prisma.banner.upsert({
    where: { id: 'seed-banner-1' },
    update: {
      title: 'عروض اليوم',
      description: 'خصومات على القرطاسية وخدمات الطباعة.',
      isActive: true,
      sortOrder: 1,
    },
    create: {
      id: 'seed-banner-1',
      title: 'عروض اليوم',
      description: 'خصومات على القرطاسية وخدمات الطباعة.',
      isActive: true,
      sortOrder: 1,
    },
  });

  const deliverySetting = await prisma.deliveryFeeSetting.findFirst();
  if (deliverySetting) {
    await prisma.deliveryFeeSetting.update({
      where: { id: deliverySetting.id },
      data: {
        mode: FeeMode.FIXED,
        amount: '1000',
        isEnabled: true,
      },
    });
  }

  const serviceSetting = await prisma.serviceFeeSetting.findFirst();
  if (serviceSetting) {
    await prisma.serviceFeeSetting.update({
      where: { id: serviceSetting.id },
      data: {
        mode: FeeMode.FIXED,
        amount: '500',
        extraFeeAmount: '0',
        extraFeeEnabled: false,
        isEnabled: true,
      },
    });
  }

  console.log('Seed completed.');
  console.log(`Admin: ${seedAdminPhone} / ${seedAdminPassword}`);
  console.log(`Delivery: 07711111111 / Delivery@12345`);
  console.log(`Customer: 07722222222 / Customer@12345`);
  console.log(`Bootstrapped by: ${admin.fullName}`);
}

main()
  .catch((error) => {
    console.error(error);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
