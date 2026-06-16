# Alisho Library ERD

The schema separates product orders and service orders, while allowing shared delivery, settlement, notification, and audit flows.

```mermaid
erDiagram
  Role ||--o{ User : assigns
  User ||--o{ Address : owns
  User ||--|| Cart : has
  Cart ||--o{ CartItem : contains
  Product ||--o{ CartItem : selected
  Product ||--o{ ProductImage : has
  Product ||--o{ ProductOptionGroup : has
  ProductOptionGroup ||--o{ ProductOptionValue : offers

  User ||--o{ Order : places
  Address ||--o{ Order : ships_to
  Order ||--o{ OrderItem : contains
  OrderItem ||--o{ OrderItemSelectedOption : snapshots
  PromoCode ||--o{ Order : applied_to
  PromoCode ||--o{ PromoCodeUsage : tracks

  User ||--o{ ServiceOrder : places
  Service ||--o{ ServiceOrder : requested_for
  Address ||--o{ ServiceOrder : fulfills_to
  ServiceOrder ||--o{ ServiceOrderFile : attaches
  FileAsset ||--o{ ServiceOrderFile : backs

  DeliveryUser ||--o{ DeliveryAssignment : handles
  Order ||--o{ DeliveryAssignment : product_target
  ServiceOrder ||--o{ DeliveryAssignment : service_target
  DeliveryUser ||--o{ DeliverySettlement : closes

  User ||--o{ Notification : receives
  User ||--o{ AuditLog : acts
```

## Core Design Notes

- `Order` and `ServiceOrder` are separate aggregates because their state machines and pricing entry points differ.
- Pricing snapshots are stored directly on orders and service orders:
  `subtotal`, `deliveryFee`, `serviceFee`, `extraFee`, `discount`, `promoCodeCode`, `finalTotal`.
- Product option selections are copied into order item snapshots so history stays stable after catalog edits.
- Shared delivery helpers use `DeliveryAssignment.targetType` with nullable `orderId` and `serviceOrderId`.
- File handling is centralized through `FileAsset`, with guarded downloads through `GET /files/:id`.
