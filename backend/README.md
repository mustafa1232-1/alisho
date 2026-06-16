# Alisho Library Backend

NestJS backend for the Alisho Library monorepo.

## Features

- JWT auth with phone/password login and refresh rotation
- Role-protected customer, admin, and delivery APIs
- Prisma schema for products, carts, orders, services, delivery, notifications, files, settings, and audit logs
- Local file storage abstraction for uploads and generated PDFs
- WebSocket gateway for notifications and order status

## Local Setup

```bash
npm install
npm run db:local:start
npm run prisma:generate
npm run prisma:migrate
npm run seed
npm run start:dev
```

## Useful Commands

```bash
npm test
npm run build
npm run test:e2e
npm run db:local:stop
```

## Default Seed Accounts

- Admin: `07700000000 / Admin@12345`
- Delivery: `07711111111 / Delivery@12345`
- Customer: `07722222222 / Customer@12345`
