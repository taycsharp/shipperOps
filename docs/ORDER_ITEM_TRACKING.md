# Order Item Delivery Tracking

This version adds item-level delivery tracking on top of order-level tracking.

## Backend

New table:

- `delivery_order_items`

New item statuses:

- `PENDING`
- `PICKED_UP`
- `IN_TRANSIT`
- `DELIVERED`
- `FAILED`
- `RETURNED`

New APIs:

```txt
GET  /orders/{order_id}/items
POST /orders/{order_id}/items
POST /orders/{order_id}/items/{item_id}/status
```

Realtime WebSocket events:

```txt
order_item_created
order_item_status
order_status
shipper_status
```

## Frontend

Admin:

```txt
/admin/orders
```

Shipper:

```txt
/shipper/home
```

Shipper can now update every item inside an order:

- Pick item
- In transit
- Delivered
- Failed

Admin can see item delivery progress and receive realtime updates.

## Test flow

1. Seed demo data:

```bash
docker compose exec backend python -m app.seed
```

2. Open admin order tracking:

```txt
http://localhost:3000/admin/orders
```

3. Open shipper mobile:

```txt
http://localhost:3000/shipper/home
```

4. Use shipper ID `1`, update item status, and watch admin page update in realtime.
