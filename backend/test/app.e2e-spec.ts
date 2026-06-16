import { execSync } from 'node:child_process';
import { join } from 'node:path';
import { INestApplication } from '@nestjs/common';
import { Test, TestingModule } from '@nestjs/testing';
import request from 'supertest';
import { AppModule } from '../src/app.module';

describe('Alisho Library E2E', () => {
  let app: INestApplication;
  let server: any;
  let customerToken: string;
  let adminToken: string;
  let deliveryToken: string;
  let orderId: string;
  let orderItemId: string;
  let deliveryUserId: string;
  let serviceOrderId: string;

  beforeAll(async () => {
    execSync('npm run seed', {
      cwd: join(__dirname, '..'),
      stdio: 'inherit',
    });

    const moduleFixture: TestingModule = await Test.createTestingModule({
      imports: [AppModule],
    }).compile();

    app = moduleFixture.createNestApplication();
    await app.init();
    server = app.getHttpServer();
  }, 180000);

  afterAll(async () => {
    await app.close();
  });

  it('registers and logs in a new customer', async () => {
    const phone = `07${Date.now().toString().slice(-9)}`;

    const registerResponse = await request(server)
        .post('/auth/register')
        .send({
          fullName: 'E2E Customer',
          age: 22,
          phone,
          streetAddress: 'مجمع A1',
          block: 'A',
          complex: 'A1',
          building: '101',
          apartment: '7',
          customerType: 'STUDENT',
          studentStage: 'الجامعة',
          password: 'Customer@12345',
          confirmPassword: 'Customer@12345',
        })
        .expect(201);

    expect(registerResponse.body.tokens.accessToken).toBeTruthy();
    customerToken = registerResponse.body.tokens.accessToken as string;

    const loginResponse = await request(server)
        .post('/auth/login')
        .send({ phone, password: 'Customer@12345' })
        .expect(201);

    expect(loginResponse.body.user.role).toBe('CUSTOMER');
  });

  it('creates and progresses a product order through admin and delivery', async () => {
    const productsResponse = await request(server)
        .get('/customer/products')
        .set('Authorization', `Bearer ${customerToken}`)
        .expect(200);

    const products = productsResponse.body as Array<Record<string, unknown>>;
    expect(products.length).toBeGreaterThan(0);
    const simpleProducts = products.filter((product) => {
      const optionGroups = (product.optionGroups as Array<Record<string, unknown>> | undefined) ?? [];
      return !optionGroups.some((group) => Boolean(group.isRequired));
    });
    expect(simpleProducts.length).toBeGreaterThanOrEqual(2);

    await request(server)
        .post('/customer/cart/items')
        .set('Authorization', `Bearer ${customerToken}`)
        .send({
          productId: simpleProducts[0]['id'],
          quantity: 1,
          selectedOptionValueIds: [],
        })
        .expect(201);

    await request(server)
        .post('/customer/cart/items')
        .set('Authorization', `Bearer ${customerToken}`)
        .send({
          productId: simpleProducts[1]['id'],
          quantity: 1,
          selectedOptionValueIds: [],
        })
        .expect(201);

    await request(server)
        .post('/customer/cart/apply-promo')
        .set('Authorization', `Bearer ${customerToken}`)
        .send({ code: 'ALISHO10' })
        .expect(201);

    const orderResponse = await request(server)
        .post('/customer/orders')
        .set('Authorization', `Bearer ${customerToken}`)
        .send({ notes: 'Created from e2e test' })
        .expect(201);

    orderId = orderResponse.body.id as string;
    orderItemId = (orderResponse.body.items as Array<Record<string, unknown>>)[0]['id'] as string;

    const adminLogin = await request(server)
        .post('/auth/login')
        .send({ phone: '07700000000', password: 'Admin@12345' })
        .expect(201);
    adminToken = adminLogin.body.tokens.accessToken as string;

    await request(server)
        .post(`/admin/orders/${orderId}/mark-item-unavailable`)
        .set('Authorization', `Bearer ${adminToken}`)
        .send({ orderItemIds: [orderItemId] })
        .expect(201);

    await request(server)
        .post(`/customer/orders/${orderId}/approve-revised`)
        .set('Authorization', `Bearer ${customerToken}`)
        .expect(201);

    await request(server)
        .post(`/admin/orders/${orderId}/confirm`)
        .set('Authorization', `Bearer ${adminToken}`)
        .expect(201);

    const deliveryUsersResponse = await request(server)
        .get('/admin/delivery-users')
        .set('Authorization', `Bearer ${adminToken}`)
        .expect(200);

    deliveryUserId =
        (deliveryUsersResponse.body as Array<Record<string, unknown>>)[0]['id'] as string;

    await request(server)
        .post(`/admin/orders/${orderId}/assign-delivery`)
        .set('Authorization', `Bearer ${adminToken}`)
        .send({ deliveryUserId, etaText: '20 دقيقة' })
        .expect(201);

    await request(server)
        .post(`/admin/orders/${orderId}/ready`)
        .set('Authorization', `Bearer ${adminToken}`)
        .expect(201);

    const deliveryLogin = await request(server)
        .post('/auth/login')
        .send({ phone: '07711111111', password: 'Delivery@12345' })
        .expect(201);
    deliveryToken = deliveryLogin.body.tokens.accessToken as string;

    await request(server)
        .post(`/delivery/orders/${orderId}/pickup`)
        .set('Authorization', `Bearer ${deliveryToken}`)
        .expect(201);

    await request(server)
        .post(`/delivery/orders/${orderId}/delivered`)
        .set('Authorization', `Bearer ${deliveryToken}`)
        .expect(201);
  }, 180000);

  it('creates, prices, and approves a service order and exposes dashboard kpis', async () => {
    const servicesResponse = await request(server)
        .get('/customer/services')
        .set('Authorization', `Bearer ${customerToken}`)
        .expect(200);

    const services = servicesResponse.body as Array<Record<string, unknown>>;
    expect(services.length).toBeGreaterThan(0);

    const serviceOrderResponse = await request(server)
        .post('/customer/service-orders')
        .set('Authorization', `Bearer ${customerToken}`)
        .field('serviceId', services[0]['id'] as string)
        .field('notes', 'Service order from e2e')
        .attach('files', Buffer.from('%PDF-1.4\n%test file'), {
          filename: 'sample.pdf',
          contentType: 'application/pdf',
        })
        .expect(201);

    serviceOrderId = serviceOrderResponse.body.id as string;

    await request(server)
        .post(`/admin/service-orders/${serviceOrderId}/price`)
        .set('Authorization', `Bearer ${adminToken}`)
        .send({ quotedPrice: '2500' })
        .expect(201);

    await request(server)
        .post(`/customer/service-orders/${serviceOrderId}/approve-price`)
        .set('Authorization', `Bearer ${customerToken}`)
        .expect(201);

    await request(server)
        .get('/admin/dashboard/kpis')
        .set('Authorization', `Bearer ${adminToken}`)
        .expect(200);
  }, 180000);
});
