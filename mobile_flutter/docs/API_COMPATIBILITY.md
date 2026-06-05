# API Compatibility Notes

This Flutter app has been adjusted for the upgraded production backend.

## Security change

The upgraded backend protects most routes with JWT. The app now logs in with:

```txt
POST /auth/login
GET  /auth/me
```

The token is sent in every protected request:

```txt
Authorization: Bearer <token>
```

## Endpoint changes

Old item endpoint:

```txt
POST /order-items/{item_id}/status
```

Upgraded endpoint used by this app:

```txt
POST /orders/{order_id}/items/{item_id}/status
```

## Proof of delivery

The app now uploads images using multipart form data:

```txt
POST /orders/{order_id}/proof
field: file
optional fields: receiver_name, delivery_note
```

## Location update

The location endpoint is authenticated now:

```txt
POST /locations/update
```

A shipper token can only update its own shipper profile. The mobile app now also enforces this at the UI/client layer by binding the logged-in SHIPPER user to the shipper profile whose `user_id` matches `GET /auth/me`. Admin/dispatcher tokens can access broader data in the backend, but production admin/dispatcher testing must remain in the web dashboard or a separate simulator rather than this shipper app.

## Mobile workflow alignment

The app exposes only backend-valid order transitions for shippers:

- `ASSIGNED` shows **Mark picked up** (`PICKED_UP`)
- `PICKED_UP` shows **Start delivery** (`IN_TRANSIT`)
- `IN_TRANSIT` shows **Delivered**, **Failed**, and **Returned**

Before `DELIVERED`, the app collects receiver name, delivery note, proof upload, and COD confirmation/payment data when COD is due. Before `FAILED` or `RETURNED`, it collects a practical predefined reason and optional explanatory note.
