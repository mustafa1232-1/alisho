# API Notes

Base URL: `http://127.0.0.1:4000`

## Auth

- `POST /auth/register`
- `POST /auth/login`
- `POST /auth/refresh`
- `POST /auth/logout`
- `GET /auth/me`

Auth is phone/password based with JWT access and refresh tokens, role guards, throttling, and audit entries for admin actions.

## Meta And Files

- `GET /meta/registration`
- `GET /files/:id`
- `PATCH /notifications/:id/read`

`GET /meta/registration` returns the seeded block/complex/building tree plus student metadata so the Flutter client does not hardcode registration options.

## Customer Surface

- `GET /customer/home`
- `GET /customer/products`
- `GET /customer/products/:id`
- `GET /customer/cart`
- `POST /customer/cart/items`
- `PATCH /customer/cart/items/:id`
- `DELETE /customer/cart/items/:id`
- `POST /customer/cart/apply-promo`
- `GET /customer/orders`
- `GET /customer/orders/:id`
- `POST /customer/orders`
- `POST /customer/orders/:id/approve-revised`
- `POST /customer/orders/:id/cancel`
- `GET /customer/services`
- `GET /customer/services/:id`
- `GET /customer/service-orders`
- `GET /customer/service-orders/:id`
- `POST /customer/service-orders`
- `POST /customer/service-orders/:id/approve-price`
- `POST /customer/service-orders/:id/cancel`
- `GET /customer/notifications`

## Admin Surface

- Product catalog CRUD and availability updates
- Banner CRUD
- Promo code CRUD
- Service CRUD
- Product order review, revised-invoice flow, delivery assignment, ready state, and archive
- Service order pricing, print handoff, confirmation, delivery assignment, and ready state
- `GET /admin/dashboard/kpis`
- `GET /admin/dashboard/reports`
- `GET /admin/settings`
- `PATCH /admin/settings`
- `GET /admin/delivery-users`
- `POST /admin/delivery-users`
- `PATCH /admin/delivery-users/:id`

## Delivery Surface

- `GET /delivery/orders`
- `GET /delivery/orders/:id`
- `POST /delivery/orders/:id/pickup`
- `POST /delivery/orders/:id/delivered`
- `POST /delivery/orders/:id/failed`
- `POST /delivery/close-day`
- `GET /delivery/settlements`

## Realtime

WebSocket namespace: `/realtime`

- JWT-authenticated socket connections
- In-app notification events
- Live order and service-order status events
- Provider interface left ready for future FCM integration

## Pricing Contract

Cart, checkout, order, and service-order responses standardize these fields:

- `subtotal`
- `deliveryFee`
- `serviceFee`
- `extraFee`
- `discount`
- `finalTotal`
- `promoCode`
