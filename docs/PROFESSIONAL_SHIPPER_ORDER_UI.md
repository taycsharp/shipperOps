# Professional Shipper-Order Management UI Upgrade

This version upgrades the project from a simple tracking MVP into a more practical dispatch operations system.

## What changed

### 1. Command Center

`/admin/dashboard` is now a real operations overview:

- Active trips
- Unassigned orders
- Delivery success rate
- Package completion rate
- COD exposure
- Problem/exception orders
- Fleet signal freshness
- Priority orders requiring dispatcher attention

### 2. Dispatch Board

`/admin/orders` is now a practical dispatcher workspace:

- Delivery lanes: New, Assigned, In Transit, Closed
- Search by order code, customer, phone, pickup, or drop-off
- Status filter
- Quick assignment of unassigned orders to available/busy shippers
- Item-level package status update
- COD and delivery-fee visibility
- Realtime WebSocket refresh

### 3. Fleet Management

`/admin/shippers` now shows a more realistic fleet roster:

- Shipper name and phone
- Vehicle type and plate
- Duty status
- GPS coordinate readiness
- Last-seen/signal freshness
- Fleet summary KPIs

### 4. Shipper Console

`/shipper/home` is closer to a real mobile shipper workflow:

- Select actual shipper from API instead of typing ID manually
- Start/stop browser GPS tracking
- Send GPS once
- Change duty status
- View assigned orders
- Update order and item statuses
- COD summary

### 5. Demo Data

The seed file now contains more realistic delivery scenarios:

- Pending orders that need dispatch assignment
- Assigned orders
- Picked-up orders
- In-transit orders
- Delivered orders
- Failed orders
- COD exposure and package details

## After replacing the project

Run:

```bash
docker compose --env-file .env.production -f docker-compose.prod.yml build frontend --no-cache
docker compose --env-file .env.production -f docker-compose.prod.yml up -d --force-recreate frontend backend
docker compose --env-file .env.production -f docker-compose.prod.yml restart cloudflared
```

Run or refresh demo data:

```bash
docker compose --env-file .env.production -f docker-compose.prod.yml exec backend python -m app.seed
```

Then open:

```text
https://dashboard.dolasol.com/admin/dashboard
https://dashboard.dolasol.com/admin/orders
https://dashboard.dolasol.com/admin/shippers
https://dashboard.dolasol.com/admin/map
https://dashboard.dolasol.com/shipper/simulator
```

## Notes

For real production, the next backend upgrade should add strict role-based authorization:

- Admin/dispatcher can create and assign orders.
- Shipper can only update their own GPS and assigned orders.
- Customer can only view their own order tracking link.
