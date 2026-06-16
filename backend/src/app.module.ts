import { Module } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';
import { ThrottlerModule } from '@nestjs/throttler';
import { AdminModule } from './admin/admin.module';
import { AuthModule } from './auth/auth.module';
import { CatalogModule } from './catalog/catalog.module';
import { appConfig } from './config/env';
import { CustomerModule } from './customer/customer.module';
import { DeliveryModule } from './delivery/delivery.module';
import { FilesModule } from './files/files.module';
import { HealthModule } from './health/health.module';
import { MetaModule } from './meta/meta.module';
import { NotificationsModule } from './notifications/notifications.module';
import { PrismaModule } from './prisma/prisma.module';
import { StorageModule } from './storage/storage.module';

@Module({
  imports: [
    ConfigModule.forRoot({
      isGlobal: true,
      load: [appConfig],
    }),
    ThrottlerModule.forRoot({
      throttlers: [
        {
          ttl: 60_000,
          limit: 12,
        },
      ],
    }),
    PrismaModule,
    StorageModule,
    NotificationsModule,
    HealthModule,
    MetaModule,
    AuthModule,
    CatalogModule,
    CustomerModule,
    AdminModule,
    DeliveryModule,
    FilesModule,
  ],
})
export class AppModule {}
